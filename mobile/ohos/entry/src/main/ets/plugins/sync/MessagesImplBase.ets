import { common } from '@kit.AbilityKit'
import { photoAccessHelper, sendablePhotoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { fileUri, hash } from '@kit.CoreFileKit';
import { fileUriService } from '@kit.ScenarioFusionKit';
import abilityAccessCtrl from '@ohos.abilityAccessCtrl';

import { NativeSyncApiOhos, SyncDelta, PlatformAsset, PlatformAlbum, Result, HashResult, CloudIdResult,
  FlutterError } from './Messages_ohos.g'
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { uri } from '@kit.ArkTS';
import taskpool from '@ohos.taskpool';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { deviceInfo } from '@kit.BasicServicesKit';

import { relationalStore } from '@kit.ArkData';
import util from '@ohos.util';
import { vibrator } from '@kit.SensorServiceKit';

interface MediaRecord {
  uri: string;
  mtime: number;
  size: number;
}

interface HashAssetParams {
  uri: string;
  isCloud: boolean;
  cacheDir: string;
}

const DB_NAME = 'media_snapshot.db';
const TABLE = 'media';
const CREATE_SQL = `
  CREATE TABLE IF NOT EXISTS ${TABLE}(
    uri TEXT PRIMARY KEY,
    mtime INTEGER,
    size INTEGER
  )`;

@Concurrent
async function hashAssetTask(uri: string,
isCloud: boolean,
cacheDir: string): Promise<string> {
  let tmpPath: string | undefined;
  try {
    let path = new fileUri.FileUri(uri).path;
    // if (isCloud) {
    //   const cacheRoot = `${cacheDir}/originalPhoto`;
    //   if (!fs.accessSync(cacheRoot)) {
    //     fs.mkdirSync(cacheRoot);
    //   }
    //   const uuid = util.generateRandomUUID();
    //   const targetDirectoryPath = `${cacheRoot}/${uuid}`;
    //   fs.mkdirSync(targetDirectoryPath);
    //
    //   const inputFilePath = uri.substring(uri.lastIndexOf('/') + 1);
    //   const inputSplits = inputFilePath.split('.');
    //   const outputFileName = inputSplits[0];
    //   const extension = inputSplits.length == 2 ? `.${inputSplits[1]}` : '.jpg';
    //   tmpPath = `${targetDirectoryPath}/${outputFileName}${extension}`;
    //
    //   const dstDirUriLocal = fileUri.getUriFromPath(tmpPath);
    //   const copied = await new Promise<boolean>((resolve) => {
    //     fs.copy(uri, dstDirUriLocal, {}, (err: BusinessError | undefined) => {
    //       if (err) {
    //         console.error(`copy ${uri} failed`, err);
    //         resolve(false);
    //         return;
    //       }
    //       resolve(true);
    //     });
    //   });
    //   if (!copied) {
    //     return '';
    //   }
    //   path = tmpPath;
    // }



    return await new Promise<string>((resolve) => {
      try {
        if (isCloud) {
          resolve('');
        } else {
          hash.hash(path, "sha1", (err: BusinessError, digest: string) => {
            if (err) {
              resolve('');
              return;
            }
            const clean = digest.trim();
            const bytes = new Uint8Array(clean.length / 2);
            for (let i = 0; i < bytes.length; i++) {
              bytes[i] = parseInt(clean.substr(i * 2, 2), 16);
            }
            const helper = new util.Base64Helper();
            resolve(helper.encodeToString(bytes));
          });
        }

      } catch (_) {
        resolve('');
      }
    });
  } catch (e) {
    console.error(`hashAssetTask failed for ${uri}`, e);
    return '';
  } finally {
    if (tmpPath) {
      try {
        if (fs.accessSync(tmpPath)) {
          fs.unlinkSync(tmpPath);
        }
        const dir = tmpPath.substring(0, tmpPath.lastIndexOf('/'));
        if (fs.accessSync(dir)) {
          fs.rmdirSync(dir);
        }
      } catch (_) {
        // best-effort cleanup
      }
    }
  }
}

export class MessagesImplBase extends NativeSyncApiOhos {
  private cancelRequested = false;
  private currentTasks: Array<taskpool.Task> = [];

  private isUiContext(ctx: common.Context | undefined): boolean {
    return !!ctx && (ctx as common.UIAbilityContext).abilityInfo !== undefined;
  }

  /**
   * Query a single PhotoAsset by uri and include position to know whether it's cloud/local.
   */
  private async getAssetByUri(uri: string): Promise<photoAccessHelper.PhotoAsset | null> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);
    const predicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo(photoAccessHelper.PhotoKeys.URI, uri);

    const fetchOption: photoAccessHelper.FetchOptions = {
      fetchColumns: [
        photoAccessHelper.PhotoKeys.URI,
        photoAccessHelper.PhotoKeys.POSITION,
      ],
      predicates: predicates,
    };

    try {
      const fetchResult = await phAccessHelper.getAssets(fetchOption);
      return await fetchResult.getFirstObject();
    } catch (e) {
      console.error(`getAssetByUri failed for ${uri}`, e);
      return null;
    }
  }

  override getTrashedAssets(): Map<string, Array<PlatformAsset>> {
    throw new FlutterError(
      'UNSUPPORTED_OS',
      'This feature is not supported on HarmonyOS.',
      'This feature is not supported on HarmonyOS.'
    );
  };

  override cancelHashing(): void {
    this.cancelRequested = true;
    for (const t of this.currentTasks) {
      try {
        taskpool.cancel(t);
      } catch (_) {
        // ignore cancel errors
      }
    }
    this.currentTasks = [];
  }

  override async hashAssets(assetIds: string[], allowNetworkAccess: boolean, result: Result<Array<HashResult>>) {
    this.cancelRequested = false;
    this.currentTasks = [];
    const group = new taskpool.TaskGroup();
    //vibrator.HapticFeedback.EFFECT_HARD

    // await vibrator.startVibration({ type: 'preset', effectId: vibrator.HapticFeedback.EFFECT_HARD },
    //   { id: 0, usage: 'touch' });

    for (const id of assetIds) {
      console.error(`hashAssets ${id}`);
      const asset = await this.getAssetByUri(id);
      console.error(`hashAssets asset ${id}`);
      const position = asset?.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType | undefined;
      let isCloud = position === photoAccessHelper.PositionType.CLOUD;
      // const param: HashAssetParams = {
      //   uri: id,
      //   isCloud: position === photoAccessHelper.PositionType.CLOUD,
      //   cacheDir: this.ctx!.cacheDir,
      // };
      const task = new taskpool.Task(hashAssetTask, id,isCloud,this.ctx!.cacheDir);
      group.addTask(task);
      this.currentTasks.push(task);
    }

    const results: HashResult[] = [];
    try {
      const res = await taskpool.execute(group, taskpool.Priority.HIGH) as Array<string | undefined>;
      const hashes = (res ?? []).map((digest) => digest ?? '');
      for (let i = 0; i < assetIds.length; i++) {
        if (this.cancelRequested) {
          break;
        }
        const b64 = hashes[i] ?? '';
        const hr = new HashResult();
        hr.setAssetId(assetIds[i]);
        hr.setHash(b64.length === 0 ? '' : b64);
        // Always set error field so the list has a fixed length [assetId, error, hash].
        hr.setError(b64.length === 0 ? 'hash_failed' : '');
        results.push(hr);
      }
    } catch (e) {
      console.error(`hashAssets taskpool execute error: ${e}`);
      // for (const id of assetIds) {
      //   const hr = new HashResult();
      //   hr.setAssetId(id);
      //   hr.setError('hash_failed');
      //   results.push(hr);
      // }
    }

    result.success(results);
    this.currentTasks = [];
  }

  // public async hashPaths(paths: string[], result: Result<Uint8Array[]>) {
  //   const group = new taskpool.TaskGroup();
  //   this.currentTasks = [];

  //   for (const p of paths) {
  //     let path = new fileUri.FileUri(p).path;
  //     const task = new taskpool.Task(hashFileTask, path);
  //     group.addTask(task);
  //     this.currentTasks.push(task);
  //   }

  //   let hashes: Uint8Array[] = [];
  //   try {
  //     const res = await taskpool.execute(group, taskpool.Priority.HIGH) as Array<Uint8Array | undefined>;
  //     hashes = (res ?? []).map((digest) => digest ?? new Uint8Array());
  //     if (this.cancelRequested) {
  //       result.success([]);
  //       return;
  //     }
  //   } catch (e) {
  //     console.error(`hashPaths taskpool execute error: ${e}`);
  //     hashes = paths.map(() => new Uint8Array());
  //   }

  //   result.success(hashes);
  //   this.currentTasks = [];
  // }

  hexStringToBytes(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
      bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
    }
    return bytes;
  }

  override shouldFullSync(): boolean {
    return true
  }

  // No-op for Android 10 and below
  override checkpointSync() {
    // Cannot throw exception as this is called from the Dart side
    // during the full sync process as well
    return;
  }

  override clearSyncCheckpoint() {
    // No-op for Android 10 and below
    return;
  }

  override getMediaChanges(): SyncDelta {
    throw new Error();
  }

  private ctx?: common.Context;
  private readonly TAG = "NativeSyncApiBase";
  private liveNotificationId: number = -1;
  private continuousTaskId: number = 0;

  constructor(context: common.Context) {
    super();
    this.ctx = context;
  }

  protected async getCursor(
    volume: string,
    albumId?: string,
    fetchColumns: string[] = [
      photoAccessHelper.PhotoKeys.URI,
      photoAccessHelper.PhotoKeys.DISPLAY_NAME,
      photoAccessHelper.PhotoKeys.DATE_TAKEN,
      photoAccessHelper.PhotoKeys.DATE_ADDED,
      photoAccessHelper.PhotoKeys.DATE_MODIFIED,
      photoAccessHelper.PhotoKeys.PHOTO_TYPE,
      //photoAccessHelper.PhotoKeys.,
      photoAccessHelper.PhotoKeys.WIDTH,
      photoAccessHelper.PhotoKeys.HEIGHT,
      photoAccessHelper.PhotoKeys.DURATION,
      photoAccessHelper.PhotoKeys.ORIENTATION,
      photoAccessHelper.PhotoKeys.FAVORITE
    ],
    extraPredicates?: dataSharePredicates.DataSharePredicates
  ): Promise<photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | null> {
    console.error("MessagesImplBase 2 ")
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);
    const preds = extraPredicates ?? new dataSharePredicates.DataSharePredicates();


    const fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: fetchColumns,
      predicates: preds
      // 视 SDK 可加分页/排序参数
    };

    try {
      const fetchResult = await phAccessHelper.getAssets(fetchOptions);
      return fetchResult;
    } catch (err) {
      console.error(this.TAG + ' getCursor failed:', err);
      return null;
    }
  }

  public override async getAlbums(result: Result<Array<PlatformAlbum>>) {
    console.error("MessagesImplBase 4 ")
    if (this.isUiContext(this.ctx)) {
      let atManager = abilityAccessCtrl.createAtManager();
      atManager.requestPermissionsFromUser(this.ctx, ["ohos.permission.MEDIA_LOCATION","ohos.permission.READ_MEDIA","ohos.permission.WRITE_MEDIA"]).then((data) => {
        //console.info("data permissions:" + data.permissions);

      }).catch((err: BusinessError) => {
        console.error(`code: ${err.code}, message: ${err.message}`);
      })
    } else {
      console.info("No UI context, skip permission request");
    }
    let albums: PlatformAlbum[] = [];
    //let albumsCount: Map<string, number>;

    let fetchColumns: string[] = [
      photoAccessHelper.AlbumKeys.URI,
      photoAccessHelper.AlbumKeys.ALBUM_NAME,
    ];

    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    //predicates.orderByAsc(photoAccessHelper.AlbumKeys.URI);
    let fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: predicates
    };
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    //let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.Album>;

    let assets_user: Array<photoAccessHelper.Album> = [];
    let assets_system: Array<photoAccessHelper.Album> = [];
    let assets_count_map: Map<number, number> = new Map();

    try {
      let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.Album> =
        await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.ANY);
      let fetchResult_sysytem: photoAccessHelper.FetchResult<photoAccessHelper.Album> =
        await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.SYSTEM, photoAccessHelper.AlbumSubtype.ANY);
      //let album: photoAccessHelper.Album = await fetchResult.getFirstObject();
      let iter: number = 0;
      // await fetchResult.getFirstObject();
      // await fetchResult_sysytem.getFirstObject();

      while (!fetchResult.isAfterLast()) {
        let asset = await fetchResult.getNextObject()
        assets_user.push(asset);
        assets_count_map.set(iter, asset.count)
        console.info('getAlbums' + asset.albumName);
        iter++;
      }

      while (!fetchResult_sysytem.isAfterLast()) {
        let asset = await fetchResult_sysytem.getNextObject()
        assets_system.push(asset);
        assets_count_map.set(iter, asset.count)
        console.info('getAlbums' + asset.albumName);
        iter++;
      }
    } catch (e) {
      console.error('getAlbums', e);
    }
    let iter: number = 0;
    //let sortedMap = this.sortMapByValue(assets_count_map);
    for (let entry of assets_system) {
      //for (let entry of sortedMap) {
      //let currrent_asset = assets[entry[0]];



      const path = entry.albumUri;
      let name = entry.albumName ?? '';
      const hasName = name.trim().length > 0;
      if (!hasName) {
        const subtype = entry.albumSubtype;
        switch (subtype) {
          case photoAccessHelper.AlbumSubtype.FAVORITE:
            name = 'Favorites';
            break;
          case photoAccessHelper.AlbumSubtype.VIDEO:
            name = 'Videos';
            break;
          case photoAccessHelper.AlbumSubtype.IMAGE:
            name = 'Images';
            break;
          default:
            name = '';
            break;
        }
      }
      const updatedAt = -1;
      const isCloud: boolean = false;
      const assetCount = entry.count;

      let album = new PlatformAlbum(path, name, -1, isCloud, assetCount)
      albums.push(album);
    }

    for (let entry of assets_user) {
      //for (let entry of sortedMap) {
      //let currrent_asset = assets[entry[0]];



      //let uri_input: string[] = [currrent_asset.albumUri];




      const path = entry.albumUri;
      let name = entry.albumName;
      const updatedAt = -1;
      const isCloud: boolean = false;
      const assetCount = entry.count;

      let album = new PlatformAlbum(path, name, -1, isCloud, assetCount)
      albums.push(album);
    }

    // Sort albums by id to align with Android ordering expectations.
    albums.sort((a, b) => {
      const aid = a.getId() ?? '';
      const bid = b.getId() ?? '';
      return aid.localeCompare(bid);
    });
    result.success(albums);

    return;
  }

  private sortMapByValue<K, V>(map: Map<K, V>, compareFn?: (a: V, b: V) => number): Map<K, V> {
    console.error("MessagesImplBase 5 ")
    // 转数组并排序，默认升序
    const entries = Array.from(map.entries());
    entries.sort((a, b) => {
      if (compareFn) {
        return compareFn(a[1], b[1]);
      }
      // 默认 V 类型是 number 或可比较类型
      if (a[1] < b[1]) {
        return -1;
      }
      if (a[1] > b[1]) {
        return 1;
      }
      return 0;
    });

    return new Map(entries);
  }

  public override async getAssetIdsForAlbum(albumPath: string, result: Result<Array<string>>) {
    console.error("MessagesImplBase 6 ")
    let atManager = abilityAccessCtrl.createAtManager();
    await atManager.requestPermissionsFromUser(this.ctx, ["ohos.permission.MEDIA_LOCATION","ohos.permission.READ_MEDIA","ohos.permission.WRITE_MEDIA"]).then((data) => {
      //console.info("data permissions:" + data.permissions);

    }).catch((err: BusinessError) => {
      console.error(`code: ${err.code}, message: ${err.message}`);
    })

    //let albumUri = fileUri.getUriFromPath(albumPath);

    let fetchColumns: string[] = [
      photoAccessHelper.AlbumKeys.URI,
    ];

    let predicates = new dataSharePredicates.DataSharePredicates();
    let albumId: photoAccessHelper.AlbumKeys = photoAccessHelper.AlbumKeys.URI;
    predicates.equalTo(albumId, albumPath);

    let fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: fetchColumns,
      predicates: predicates
    };
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    let assetForAlbumfetchColumns: string[] = [
      photoAccessHelper.PhotoKeys.URI,
      photoAccessHelper.PhotoKeys.POSITION,
    ];
    let photoPredicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    let photoFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetForAlbumfetchColumns,
      predicates: photoPredicates
    };

    let fetch_result_album =
      await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.ANY,
        fetchOptions)
    let album:photoAccessHelper.Album;
    if(fetch_result_album.getCount()!=0) {
      album = await fetch_result_album.getFirstObject();
    } else {
      let fetch_result_album =
        await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.SYSTEM, photoAccessHelper.AlbumSubtype.ANY,
          fetchOptions)
      album = await fetch_result_album.getFirstObject();
    }

    let photoFetchResult = await album.getAssets(photoFetchOptions);
    let assetsUri:string[] = [];

    let i: number = 0;

    //await photoFetchResult!.getFirstObject();
    while (!photoFetchResult!.isAfterLast()) {

      let current_asset = await photoFetchResult!.getNextObject();
      console.error('7:5 success' + current_asset.uri);

      let position = current_asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
      if (position == photoAccessHelper.PositionType.CLOUD) {
        continue;
      }
      assetsUri.push(current_asset.uri);
    }

    return result.success(assetsUri);
  }

  public override async getAssetsCountSince(albumPath: string, timestamp: number, result: Result<number>) {
    console.error("MessagesImplBase 7 ")
    let atManager = abilityAccessCtrl.createAtManager();
    await atManager.requestPermissionsFromUser(this.ctx, ["ohos.permission.MEDIA_LOCATION","ohos.permission.READ_MEDIA","ohos.permission.WRITE_MEDIA"]).then((data) => {
      //console.info("data permissions:" + data.permissions);

    }).catch((err: BusinessError) => {
      console.error(`code: ${err.code}, message: ${err.message}`);
    })
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    let albumId: photoAccessHelper.AlbumKeys = photoAccessHelper.AlbumKeys.URI;
    let predicates_album = new dataSharePredicates.DataSharePredicates();
    predicates_album.equalTo(albumId, albumPath);

    let fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: predicates_album
    };

    let albumFetchResult =
      await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.USER_GENERIC,
        fetchOptions);

    if (albumFetchResult.getCount() == 0 || albumFetchResult == undefined) {
      albumFetchResult =
        await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.SYSTEM, photoAccessHelper.AlbumSubtype.ANY,
          fetchOptions);
    }

    let album_result = await albumFetchResult.getFirstObject();
    console.error('7:albumFetchResult.getFirstObject() success')

    let assetsCountfetchColumns: string[] = [
      photoAccessHelper.PhotoKeys.URI,
      photoAccessHelper.PhotoKeys.DATE_ADDED,
      photoAccessHelper.PhotoKeys.POSITION,
      photoAccessHelper.PhotoKeys.DATE_MODIFIED,
    ];

    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();

    let getAssetsCountetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetsCountfetchColumns,
      predicates: predicates
    };

    let count: number = 0;
    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset>
    try {
      fetchResult = await album_result.getAssets(getAssetsCountetchOptions);
    } catch (err) {
      console.error(err);
      console.error('getAssetsCountSince undefined')
      return;
    }

    if (fetchResult!.getCount() == 0) {
      console.error('getAssetsCountSince count:0')
      return result.success(0);
    }

    //await fetchResult!.getFirstObject();
    while (!fetchResult!.isAfterLast()) {

      let current_asset = await fetchResult!.getNextObject();
      let position = current_asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
      if(position==photoAccessHelper.PositionType.CLOUD) {
        continue;
      }

      if (timestamp != undefined) {
        let time_modified = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED).valueOf() as number;

        if (time_modified < timestamp) {
          continue;
        }
      }

      let id = current_asset.get(photoAccessHelper.PhotoKeys.URI).valueOf() as string;
      let res: boolean = false;
      try {
        res = fs.accessSync(id);

      } catch (err) {
        console.error("accessSync failed with error message: " + err.message + ", error code: " + err.code);
      }

      if (!res) {
        continue;
      }
      count++;
    }

    return result.success(count);

  }

  /**
   * 启动长时任务（上传/下载），返回通知 id，供进度更新使用
   */
  public override async startBackgroundTransfer(result: Result<number>) {
    if (!this.ctx) {
      console.error(`${this.TAG} context is null, cannot start background running`);
      result.success(0);
      return;
    }

    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: 'com.dgh18.immich',
          abilityName: 'EntryAbility',
        },
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };

    try {
      wantAgent.getWantAgent(wantAgentInfo).then((wantAgentObj: WantAgent) => {
        let list: Array<string> = ["dataTransfer"];
        if(deviceInfo.sdkApiVersion>=21) {
          backgroundTaskManager.startBackgroundRunning(
            this.ctx!,
            list,
            wantAgentObj,
          ).then((res: backgroundTaskManager.ContinuousTaskNotification) => {
            console.info("Operation startBackgroundRunning succeeded");
            // 对于上传下载类的长时任务，应用可以使用res中返回的notificationId来更新通知，比如发送带进度条的模板通知
            this.liveNotificationId = res.notificationId;
            result.success(this.liveNotificationId);
          }).catch((error: BusinessError) => {
            result.success(0);
            console.error(`Operation startBackgroundRunning failed. code is ${error.code} message is ${error.message}`);
          });;
        } else {
          backgroundTaskManager.startBackgroundRunning(
            this.ctx!,
            backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
            wantAgentObj,
            (err: BusinessError | undefined) => {
              if (err) {
                console.error(`Failed to startBackgroundRunning. Code=${err.code} msg=${err.message}`);
                result.success(0);
                return;
              }
              this.liveNotificationId = 100;
              console.info("Succeeded in startBackgroundRunning.");
              result.success(this.liveNotificationId);
            }
          );
        };
      }).catch((err: BusinessError) => {
        console.error(`getWantAgent failed code=${err.code} msg=${err.message}`);
        result.success(0);
      });
    } catch (e) {
      const err = e as BusinessError;
      result.success(0);
      this.ctx.getApplicationContext().cacheDir
      console.error(`startBackgroundRunning failed code=${err.code} msg=${err.message}`);
    }
  }

  /**
   * 更新长时任务进度
   */
  public override async updateBackgroundTransferProgress(progress: number , title: string , fileName: string , result: Result<void>) {
    const targetId = this.liveNotificationId;

    let request: notificationManager.NotificationRequest = {
      id: targetId,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: fileName,
          additionalText: progress.toString(),
        }
      },
      // 构造进度条模板，name字段当前需要固定配置为downloadTemplate
      template: {
        name: 'downloadTemplate',
        data: { title: title, fileName: fileName, progressValue: progress }
      },
      notificationSlotType:notificationManager.SlotType.OTHER_TYPES
    }

    try {
      await notificationManager.publish(request);
      result.success();
    } catch (e) {
      const err = e as BusinessError;
      console.error(`publish live view fail code=${err.code} msg=${err.message}`);
      result.success();
    }
  }

  /**
   * 停止长时任务
   */
  public override async stopBackgroundTransfer(result: Result<void>) {
    if (!this.ctx) {
      result.success();
      return;
    }

    try {
      if (this.liveNotificationId >= 0) {
        await notificationManager.cancel(this.liveNotificationId);
      }
    } catch (cancelErr) {
      const err = cancelErr as BusinessError;
      console.error(`cancel notification fail code=${err.code} msg=${err.message}`);
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(this.ctx);
      this.liveNotificationId = -1;
      this.continuousTaskId = 0;
      result.success();
    } catch (e) {
      const err = e as BusinessError;
      result.success();
      console.error(`stopBackgroundRunning fail code=${err.code} msg=${err.message}`);
    }
  }

  public override async getAssetsForAlbum(albumId: string, updatedTimeCond?: number, result?: Result<Array<PlatformAsset>>) {
    console.error("MessagesImplBase 8 ")
    if (this.isUiContext(this.ctx)) {
      let atManager = abilityAccessCtrl.createAtManager();
      await atManager.requestPermissionsFromUser(this.ctx, ["ohos.permission.MEDIA_LOCATION","ohos.permission.READ_MEDIA","ohos.permission.WRITE_MEDIA"]).then((data) => {
        // console.info("data permissions:" + data.permissions);
        // console.info("data permissions:" + data.authResults);

      }).catch((err: BusinessError) => {
        console.error(`code: ${err.code}, message: ${err.message}`);
      })
    } else {
      console.info("No UI context, skip permission request in getAssetsForAlbum");
    }
    let predicates_album: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();

    let albumName: photoAccessHelper.AlbumKeys = photoAccessHelper.AlbumKeys.URI;
    let albumUri = albumId;
    predicates_album.equalTo(albumName, albumUri);

    let albumFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: predicates_album
    };
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    let albumFetchResult =
      await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.ANY,
        albumFetchOptions);
    if (albumFetchResult.getCount() == 0 || albumFetchResult == undefined) {
      albumFetchResult =
        await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.SYSTEM, photoAccessHelper.AlbumSubtype.ANY,
          albumFetchOptions);
    }
    let assetResult: Array<PlatformAsset> = [];
    let album = await albumFetchResult.getFirstObject();
    let predicates_photo: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    // predicates_photo.equalTo(photoAccessHelper.PhotoKeys.POSITION, photoAccessHelper.PositionType.LOCAL_AND_CLOUD)
    // predicates_photo.equalTo(photoAccessHelper.PhotoKeys.POSITION, photoAccessHelper.PositionType.LOCAL)
    let assetForAlbumfetchColumns: string[] = [
      photoAccessHelper.PhotoKeys.URI,
      photoAccessHelper.PhotoKeys.DISPLAY_NAME,
      photoAccessHelper.PhotoKeys.DATE_TAKEN,
      photoAccessHelper.PhotoKeys.DATE_ADDED,
      photoAccessHelper.PhotoKeys.DATE_MODIFIED,
      photoAccessHelper.PhotoKeys.PHOTO_TYPE,
      photoAccessHelper.PhotoKeys.SIZE,
      photoAccessHelper.PhotoKeys.WIDTH,
      photoAccessHelper.PhotoKeys.HEIGHT,
      photoAccessHelper.PhotoKeys.DURATION,
      photoAccessHelper.PhotoKeys.ORIENTATION,
      photoAccessHelper.PhotoKeys.FAVORITE,
      photoAccessHelper.PhotoKeys.POSITION

    ];

    let photoFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetForAlbumfetchColumns,
      predicates: predicates_photo
    };
    let photoFetchResult = await album.getAssets(photoFetchOptions);
    //await photoFetchResult.getFirstObject();

    const snapshotRows: MediaRecord[] = [];
    while (!photoFetchResult.isAfterLast()) {
      let current_asset = await photoFetchResult.getNextObject();
      let uri_input: string[] = [current_asset.uri];
      let position = current_asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
      if(position==photoAccessHelper.PositionType.CLOUD) {
        //console.error(current_asset.uri + ": is cloud" );
        continue;
      }

      if (updatedTimeCond != undefined) {
        let time_modified = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED).valueOf() as number;

        if (time_modified < updatedTimeCond) {
          continue;
        }
      }

      let id = current_asset.uri;

      let res: boolean = false;

      let mediaType = current_asset.photoType;
      let name = current_asset.displayName;
      let createdAt: number = current_asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN).valueOf() as number ??
        current_asset.get(photoAccessHelper.PhotoKeys.DATE_ADDED) as number;

      let modifiedAt = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED).valueOf() as number;
      let size = current_asset.get(photoAccessHelper.PhotoKeys.SIZE).valueOf() as number;
      let width = current_asset.get(photoAccessHelper.PhotoKeys.WIDTH).valueOf() as number;
      let height = current_asset.get(photoAccessHelper.PhotoKeys.HEIGHT).valueOf() as number;
      let duration =
        Math.floor((current_asset.get(photoAccessHelper.PhotoKeys.DURATION).valueOf() as number) / 1000); //
      //let bucketId = current_asset.get(bucketIdColumn);
      let bucketId = '-1';
      let orientation = current_asset.get(photoAccessHelper.PhotoKeys.ORIENTATION).valueOf() as number;
      let isFavorite: boolean =
        (current_asset.get(photoAccessHelper.PhotoKeys.FAVORITE).valueOf() as number) > 0 ? true : false;

      if (!id) {
        continue;
      }

      let asset: PlatformAsset = new PlatformAsset(
        id,
        name ?? "",
        mediaType,
        createdAt ?? 0,
        modifiedAt ?? 0,
        width ?? 0,
        height ?? 0,
        duration ?? 0,
        orientation,
        isFavorite,
        -1,
        199.9,
        199.9,
      )
      //console.error('get assets for album' + ':' + id);
      assetResult.push(asset);
      snapshotRows.push({ uri: id, mtime: modifiedAt ?? 0, size: size ?? 0 });
    }
    try {
      if (!this.store && this.ctx) {
        await this.initStore(this.ctx);
      }
      if (this.store) {
        await this.replaceSnapshot(snapshotRows);
      }
    } catch (e) {
      console.error(`${this.TAG} replaceSnapshot failed`, e);
    }
    result?.success(assetResult);
    return;
  }

  private store?: relationalStore.RdbStore;

  public async initStore(ctx: Context) {
    this.store = await new Promise((resolve, reject) => {
      relationalStore.getRdbStore(
        ctx,
        { name: DB_NAME, securityLevel: relationalStore.SecurityLevel.S3 },
        async (err, s) => {
          if (err) return reject(err);
          try { await s.execute(CREATE_SQL); } catch (e) { return reject(e); }
          resolve(s);
        },
      );
    });
  }

  public async replaceSnapshot(rows: MediaRecord[]) {
    if (!this.store) throw new Error('store not init');
    await this.store.execute(`DELETE FROM ${TABLE}`);
    for (const row of rows) {
      const values: relationalStore.ValuesBucket = {
        uri: row.uri,
        mtime: row.mtime,
        size: row.size,
      };
      await this.store.insert(TABLE, values);
    }
  }

  public async loadSnapshot(): Promise<Map<string, MediaRecord>> {
    if (!this.store) throw new Error('store not init');
    const rs = await this.store.querySql(`SELECT uri, mtime, size FROM ${TABLE}`);
    const map = new Map<string, MediaRecord>();
    while (rs.goToNextRow()) {
      map.set(rs.getString(0), {
        uri: rs.getString(0),
        mtime: rs.getLong(1),
        size: rs.getLong(2),
      });
    }
    rs.close();
    return map;
  }

  override getPathFromUri(uri: string, result: Result<string>): void {
    let obj = new fileUri.FileUri(uri);
    let path = obj.path;
    result.success(path);
  }

  override getCloudIdForAssetIds(assetIds: Array<string>, result: Result<Array<CloudIdResult>>): void {
    const results: CloudIdResult[] = [];
    for (const id of assetIds) {
      const item = new CloudIdResult();
      item.setAssetId(id);
      item.setCloudId(id);
      item.setError('');
      results.push(item);
    }
    result.success(results);
  }
}
