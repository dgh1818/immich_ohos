import { common } from '@kit.AbilityKit'
import { photoAccessHelper, sendablePhotoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { fileUri, hash } from '@kit.CoreFileKit';
import { fileUriService } from '@kit.ScenarioFusionKit';

import { NativeSyncApiOhos, SyncDelta, PlatformAsset, PlatformAlbum, Result } from './Messages_ohos.g'
import { BusinessError } from '@kit.BasicServicesKit';
import fs from '@ohos.file.fs';
import { uri, util } from '@kit.ArkTS';
import taskpool from '@ohos.taskpool';

@Concurrent
async function hashFileTask(path: string): Promise<Uint8Array> {
  return await new Promise<Uint8Array>((resolve) => {
    try {
      hash.hash(path, "sha1", (err: BusinessError, digest: string) => {
        console.error("hash:" + path + "success");
        if (err) {
          resolve(new Uint8Array());
          return;
        }
        const bytes = new Uint8Array(digest.length / 2);
        for (let i = 0; i < digest.length; i += 2) {
          bytes[i / 2] = parseInt(digest.substring(i, i + 2), 16);
        }
        resolve(bytes);
      });
    } catch (_) {
      resolve(new Uint8Array());
    }
  });
}

export class MessagesImplBase extends NativeSyncApiOhos {
  public async hashPaths(paths: string[], result: Result<Uint8Array[]>) {
    const group = new taskpool.TaskGroup();

    for (const p of paths) {
      const task = new taskpool.Task(hashFileTask, p);
      group.addTask(task);
    }

    let hashes: Uint8Array[] = [];
    try {
      const res = await taskpool.execute(group, taskpool.Priority.HIGH) as Array<Uint8Array | undefined>;
      hashes = (res ?? []).map((digest) => digest ?? new Uint8Array());
    } catch (e) {
      console.error(`hashPaths taskpool execute error: ${e}`);
      hashes = paths.map(() => new Uint8Array());
    }

    result.success(hashes);
  }

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

  private ctx?: common.UIAbilityContext;
  private readonly TAG = "NativeSyncApiBase";

  constructor(context: common.UIAbilityContext) {
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

  protected async getAssets(cursor: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset>): Promise<Array<PlatformAsset>> {
    console.error("MessagesImplBase 3 ")
    let path: string;
    let assetResult: Array<PlatformAsset> = [];
    await cursor.getFirstObject();
    while (!cursor.isAfterLast()) {
      let current_asset = await cursor.getNextObject();

      let id = await hash.hash(current_asset.uri, "sha1");
      let uri: Array<string> = [current_asset.uri];
      let fileUriResult = (await fileUriService.convertFileUris(uri))[0];
      if (fileUriResult.targetType == fileUriService.TargetType.UNKNOWN) {
        continue;
      }

      let type = current_asset.photoType;
      let name = current_asset.displayName;
      let createdAt: number = current_asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN) as number ??
        current_asset.get(photoAccessHelper.PhotoKeys.DATE_ADDED) as number;

      let updatedAt = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number;
      let width = current_asset.get(photoAccessHelper.PhotoKeys.WIDTH) as number;
      let height = current_asset.get(photoAccessHelper.PhotoKeys.HEIGHT) as number;
      let durationInSeconds = type == photoAccessHelper.PhotoType.IMAGE ? 0 :
        Math.floor((current_asset.get(photoAccessHelper.PhotoKeys.DURATION) as number) / 1000); //ohos not support
      //let bucketId = current_asset.get(bucketIdColumn);
      let bucketId = '-1';
      let orientation = current_asset.get(photoAccessHelper.PhotoKeys.ORIENTATION) as number;
      let isFavorite = current_asset.get(photoAccessHelper.PhotoKeys.FAVORITE) as boolean;

      let asset: PlatformAsset = new PlatformAsset(id,
        name,
        type,
        createdAt,
        updatedAt,
        width,
        height,
        durationInSeconds,
        orientation,
        isFavorite)

      assetResult.push(asset);

    }
    return assetResult;
  }

  public async getAlbums(result: Result<Array<PlatformAlbum>>) {
    console.error("MessagesImplBase 4 ")
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
      let currrent_asset = entry;


      //let uri_input: string[] = [currrent_asset.albumUri];


      //FileUtils.getPathFromUri
      let fileUriResult_array = entry.albumUri;
      //let fileUriResult_array = FileUtils.getPathFromUri(getContext(),currrent_asset.albumUri)
      const fileUriResult = fileUriResult_array;
      const path = fileUriResult;
      let name = currrent_asset.albumName ?? '';
      const hasName = name.trim().length > 0;
      if (!hasName) {
        const subtype = currrent_asset.albumSubtype;
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
      const assetCount = currrent_asset.count;

      let album = new PlatformAlbum(path, name, updatedAt, isCloud, assetCount)
      albums.push(album);
    }

    for (let entry of assets_user) {
      //for (let entry of sortedMap) {
      //let currrent_asset = assets[entry[0]];
      let currrent_asset = entry;


      //let uri_input: string[] = [currrent_asset.albumUri];


      //FileUtils.getPathFromUri
      let fileUriResult_array = entry.albumUri;
      //let fileUriResult_array = FileUtils.getPathFromUri(getContext(),currrent_asset.albumUri)
      const fileUriResult = fileUriResult_array;

      const path = fileUriResult;
      let name = currrent_asset.albumName;
      const updatedAt = -1;
      const isCloud: boolean = false;
      const assetCount = currrent_asset.count;

      let album = new PlatformAlbum(path, name, updatedAt, isCloud, assetCount)
      albums.push(album);
    }

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

  public async getAssetIdsForAlbum(albumPath: string, result: Result<Array<string>>) {
    console.error("MessagesImplBase 6 ")

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
    ];
    let photoPredicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    let photoFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetForAlbumfetchColumns,
      predicates: photoPredicates
    };

    let fetch_result_album =
      await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.USER_GENERIC,
        fetchOptions)
    let album = await fetch_result_album.getFirstObject();
    let photoFetchResult = await album.getAssets(photoFetchOptions);
    let photoAsset = await photoFetchResult.getAllObjects();
    let assetsUri = photoAsset.map(pa => pa.uri);
    let assetsPath: Array<string> = [];

    let i: number = 0;

    //await photoFetchResult!.getFirstObject();
    while (!photoFetchResult!.isAfterLast()) {

      let current_asset = await photoFetchResult!.getNextObject();
      console.error('7:5 success' + current_asset.uri);

      // let position = current_asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
      // if (!(position == photoAccessHelper.PositionType.LOCAL) &&
      //   !(position == photoAccessHelper.PositionType.LOCAL_AND_CLOUD)) {
      //   continue;
      // }

      let fileUriObject = new fileUri.FileUri(current_asset.uri);
      console.error('get path success:' + fileUriObject.path);
      assetsPath.push(fileUriObject.path);
    }

    return result.success(assetsUri);
  }

  public async getAssetsCountSince(albumPath: string, timestamp: number, result: Result<number>) {
    console.error("MessagesImplBase 7 ")
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

    console.error('7:2 success')


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
      console.error('7:5 success' + current_asset.uri);

      // let position = current_asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
      // if(!(position==photoAccessHelper.PositionType.LOCAL) && !(position==photoAccessHelper.PositionType.LOCAL_AND_CLOUD)) {
      //   continue;
      // }

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

  public async getAssetsForAlbum(albumId: string, updatedTimeCond?: number, result?: Result<Array<PlatformAsset>>) {
    console.error("MessagesImplBase 8 ")
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
      //photoAccessHelper.PhotoKeys.,
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

    while (!photoFetchResult.isAfterLast()) {
      let current_asset = await photoFetchResult.getNextObject();
      let uri_input: string[] = [current_asset.uri];
      // let position = current_asset.get(photoAccessHelper.PhotoKeys.POSITION) as photoAccessHelper.PositionType;
      // if(!(position==photoAccessHelper.PositionType.LOCAL) && !(position==photoAccessHelper.PositionType.LOCAL_AND_CLOUD)) {
      //   console.error(current_asset.uri + ": is cloud" );
      //   continue;
      // }

      if (updatedTimeCond != undefined) {
        let time_modified = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED).valueOf() as number;

        if (time_modified < updatedTimeCond) {
          continue;
        }
      }

      let id = current_asset.get(photoAccessHelper.PhotoKeys.URI).valueOf() as string;

      id = new fileUri.FileUri(id).path;

      let res: boolean = false;

      let mediaType = current_asset.photoType;
      let name = current_asset.displayName;
      let createdAt: number = current_asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN).valueOf() as number ??
        current_asset.get(photoAccessHelper.PhotoKeys.DATE_ADDED) as number;

      let modifiedAt = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED).valueOf() as number;
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
        current_asset.displayName ?? "",
        mediaType,
        createdAt ?? 0,
        modifiedAt ?? 0,
        width ?? 0,
        height ?? 0,
        duration ?? 0,
        orientation,
        isFavorite
      )
      console.error('get assets for album' + ':' + id);
      assetResult.push(asset);
    }
    result?.success(assetResult);
    return;
  }
}
