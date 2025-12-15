import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { preferences, relationalStore, dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';
import dataPreferences from '@ohos.data.preferences'

interface SnapshotRow {
  albumUri: string;
  assetUri: string;
  mtime: number;
  size: number;
}

interface SnapshotDiff {
  changed: SnapshotRow[];
  deleted: string[];
}

const SNAPSHOT_DB = 'media_snapshot.db';
const SNAPSHOT_TABLE = 'media';
const SNAPSHOT_SQL = `
  CREATE TABLE IF NOT EXISTS ${SNAPSHOT_TABLE}(
    uri TEXT PRIMARY KEY,
    mtime INTEGER,
    size INTEGER
  )`;

export class MediaObserverScheduler extends WorkSchedulerExtensionAbility {
  private ctx: common.ApplicationContext = this.context.getApplicationContext();
  private store?: relationalStore.RdbStore;

  private async ensureStore() {
    if (this.store) {
      return;
    }
    this.store = await new Promise((resolve, reject) => {
      relationalStore.getRdbStore(
        this.ctx,
        { name: SNAPSHOT_DB, securityLevel: relationalStore.SecurityLevel.S3 },
        async (err, s) => {
          if (err) return reject(err);
          try {
            await s.execute(SNAPSHOT_SQL);
          } catch (e) {
            return reject(e);
          }
          resolve(s);
        });
    });
  }

  private async loadSnapshot(): Promise<Map<string, SnapshotRow>> {
    await this.ensureStore();
    const map = new Map<string, SnapshotRow>();
    const rs = await this.store!.querySql(`SELECT uri, mtime, size FROM ${SNAPSHOT_TABLE}`);
    while (rs.goToNextRow()) {
      const uri = rs.getString(0);
      map.set(uri, {
        albumUri: '',
        assetUri: uri,
        mtime: rs.getLong(1),
        size: rs.getLong(2),
      });
    }
    rs.close();
    return map;
  }

  private async replaceSnapshot(rows: SnapshotRow[]) {
    await this.ensureStore();
    await this.store!.execute(`DELETE FROM ${SNAPSHOT_TABLE}`);
    for (const row of rows) {
      const values: relationalStore.ValuesBucket = {
        uri: row.assetUri,
        mtime: row.mtime,
        size: row.size,
      };
      await this.store!.insert(SNAPSHOT_TABLE, values);
    }
  }

  private diffSnapshot(current: SnapshotRow[], previous: Map<string, SnapshotRow>): SnapshotDiff {
    const changed: SnapshotRow[] = [];
    for (const row of current) {
      const prev = previous.get(row.assetUri);
      if (!prev || prev.mtime !== row.mtime || prev.size !== row.size) {
        changed.push(row);
      }
      previous.delete(row.assetUri);
    }
    const deleted: string[] = Array.from(previous.keys());
    return { changed, deleted };
  }

  private async scanAllMedia(): Promise<SnapshotRow[]> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);
    const albums: Array<photoAccessHelper.Album> = [];

    try {
      const systemAlbums = await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.SYSTEM, photoAccessHelper.AlbumSubtype.ANY);
      while (!systemAlbums.isAfterLast()) {
        const album = await systemAlbums.getNextObject();
        albums.push(album);
      }

      const userAlbums = await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.ANY);
      while (!userAlbums.isAfterLast()) {
        const album = await userAlbums.getNextObject();
        albums.push(album);
      }
    } catch (e) {
      console.error(`MediaObserverScheduler scanAllMedia getAlbums failed`, e);
      return [];
    }

    const results: SnapshotRow[] = [];
    const assetCols: string[] = [
      photoAccessHelper.PhotoKeys.URI,
      photoAccessHelper.PhotoKeys.DATE_MODIFIED,
      photoAccessHelper.PhotoKeys.SIZE,
      photoAccessHelper.PhotoKeys.POSITION,
    ];
    const fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetCols,
      predicates: new dataSharePredicates.DataSharePredicates(),
    };

    for (const album of albums) {
      try {
        const assets = await album.getAssets(fetchOptions);
        while (!assets.isAfterLast()) {
          const asset = await assets.getNextObject();
          const position = asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
          if (position === photoAccessHelper.PositionType.CLOUD) {
            continue;
          }
          const uri = asset.get(photoAccessHelper.PhotoKeys.URI).valueOf() as string;
          const mtime = asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED).valueOf() as number;
          const size = asset.get(photoAccessHelper.PhotoKeys.SIZE).valueOf() as number;
          results.push({
            albumUri: album.albumUri,
            assetUri: uri,
            mtime: mtime ?? 0,
            size: size ?? 0,
          });
        }
      } catch (e) {
        console.error(`MediaObserverScheduler scanAllMedia album failed`, e);
      }
    }

    return results;
  }

  private async processMediaChanges() {
    const current = await this.scanAllMedia();
    const previous = await this.loadSnapshot();
    const diff = this.diffSnapshot(current, previous);
    if (diff.changed.length > 0 || diff.deleted.length > 0) {
      await this.replaceSnapshot(current);
      MediaObserverScheduler.enqueueBackgroundWorker();
    }
  }

  public static enqueueBackgroundWorker() {
    const constraints: workScheduler.WorkInfo = BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO;
    BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO = constraints;
    workScheduler.startWork(constraints);
    console.info("MediaObserverScheduler", "Enqueued background worker");
  }

  async onWorkStart(workInfo: workScheduler.WorkInfo) {
    // 条件满足（充电+Wi-Fi+闲时）时扫描媒体差异，如有变更触发后台任务，然后重新排程监听
    try {
      await this.processMediaChanges();
    } catch (e) {
      console.error("MediaObserverScheduler.processMediaChanges error", e);
    }
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx);
  }
}
