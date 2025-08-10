import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { fileUri, hash } from '@kit.CoreFileKit';
import { fileUriService } from '@kit.ScenarioFusionKit';

import { NativeSyncApiOhos,SyncDelta,PlatformAsset,PlatformAlbum } from './Messages_ohos.g'
import { BusinessError } from '@kit.BasicServicesKit';

export class MessagesImplBase extends NativeSyncApiOhos {
  public async hashPaths(paths: string[]): Promise<Uint8Array[]> {
    try {
      const results = await Promise.all(
        paths.map(path =>
        new Promise<Uint8Array | null>((resolve) => {
          hash.hash(path, 'sha1', (err: BusinessError, digest: string) => {
            if (err) {
              console.error(`Cannot calculate digest of ${path}: ${err.message}`);
              resolve(null);
            } else {
              try {
                const bytes: Uint8Array = this.hexStringToBytes(digest);
                resolve(bytes);
              } catch (e) {
                console.error(`Invalid digest format`);
                resolve(null);
              }
            }
          });
        })
        )
      );

      // 过滤 null
      return results.filter(x => x !== null) as Uint8Array[];
    } catch (error) {
      console.error(`hashPaths failed: ${(error as BusinessError).message}`);
      return [];
    }
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
  }

  override clearSyncCheckpoint() {
    // No-op for Android 10 and below
  }

  override getMediaChanges(): SyncDelta {
    throw new Error();
  }


  private ctx?: common.Context;
  private readonly TAG = "NativeSyncApiBase";

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
    let a = await cursor.getNextObject();
    let path: string;
    let assetResult: Array<PlatformAsset> = [];
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
      let durationInSeconds = type == photoAccessHelper.PhotoType.IMAGE ? 0 : 0; //ohos not support
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

  public async getAlbums(): Promise<PlatformAlbum[]> {
    let albums: PlatformAlbum[] = [];
    //let albumsCount: Map<string, number>;

    let fetchColumns: string[] = [
      photoAccessHelper.AlbumKeys.URI,
      photoAccessHelper.AlbumKeys.ALBUM_NAME,
    ];

    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.orderByAsc(photoAccessHelper.AlbumKeys.URI);
    let fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: fetchColumns,
      predicates: predicates
    };
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.Album>;

    let assets: Array<photoAccessHelper.Album> = [];
    let assets_count_map: Map<number, number> = new Map();

    try {
      let fetchResult =
        await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.USER_GENERIC,
          fetchOptions);
      //let album: photoAccessHelper.Album = await fetchResult.getFirstObject();
      let iter: number = 0;

      while (!fetchResult.isAfterLast()) {
        let asset = await fetchResult.getNextObject()
        assets.push(asset);
        assets_count_map[iter] = asset.count;
        iter++;
      }
    } catch (e) {
      console.error('getAlbums', e);
    }

    let sortedMap = this.sortMapByValue(assets_count_map);

    for (let entry of sortedMap) {
      let currrent_asset = assets[entry[0]];

      let uri_input: string[] = [currrent_asset.albumUri];

      let fileUriResult_array = await fileUriService.convertFileUris(uri_input);
      const fileUriResult = fileUriResult_array[0];

      const path = fileUriResult?.targetUri;
      const name = currrent_asset.albumName;
      const updatedAt = -1;
      const isCloud: boolean = false;
      const assetCount = currrent_asset.count;

      let album = new PlatformAlbum(path, name, updatedAt, isCloud, assetCount)
      albums.push(album);
    }

    return albums;
  }

  private sortMapByValue<K, V>(map: Map<K, V>, compareFn?: (a: V, b: V) => number): Map<K, V> {
    // 转数组并排序，默认升序
    const entries = Array.from(map.entries());
    entries.sort((a, b) => {
      if (compareFn) {
        return compareFn(a[1], b[1]);
      }
      // 默认 V 类型是 number 或可比较类型
      if (a[1] < b[1]) return -1;
      if (a[1] > b[1]) return 1;
      return 0;
    });

    return new Map(entries);
  }

  public async getAssetIdsForAlbum(albumPath: string): Promise<Array<string>> {

    let albumUri = fileUri.getUriFromPath(albumPath);

    let fetchColumns: string[] = [
      photoAccessHelper.AlbumKeys.URI,
    ];

    let predicates = new dataSharePredicates.DataSharePredicates();
    let albumId: photoAccessHelper.AlbumKeys = photoAccessHelper.AlbumKeys.URI;
    predicates.equalTo(albumId, albumUri);

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
    let assetsPath = photoAsset.map(pa => pa.uri);
    return assetsPath;
  }

  public async getAssetsCountSince(albumId: string, timestamp: number): Promise<number> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    let assetsCountfetchColumns: string[] = [
      photoAccessHelper.PhotoKeys.URI,
      photoAccessHelper.PhotoKeys.DATE_ADDED,
    ];
    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.in(photoAccessHelper.PhotoKeys.DATE_ADDED, [timestamp, Math.floor(Date.now() / 1000) + 10000]);

    let getAssetsCountetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetsCountfetchColumns,
      predicates: predicates
    };

    let fetchResult = await phAccessHelper.getAssets(getAssetsCountetchOptions);
    let count = fetchResult.getCount();
    return count;

  }

  public async getAssetsForAlbum(albumId: string, updatedTimeCond?: number): Promise<Array<PlatformAsset>> {
    let predicates_album: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();

    let albumName: photoAccessHelper.AlbumKeys = photoAccessHelper.AlbumKeys.ALBUM_NAME;
    let albumUri = fileUri.getUriFromPath(albumId);
    predicates_album.equalTo(albumName, albumUri);

    let albumFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: predicates_album
    };
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);

    let albumFetchResult =
      await phAccessHelper.getAlbums(photoAccessHelper.AlbumType.USER, photoAccessHelper.AlbumSubtype.USER_GENERIC,
        albumFetchOptions);
    let assetResult: Array<PlatformAsset> = [];
    let album = await albumFetchResult.getFirstObject();
    let predicates_photo: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    if (updatedTimeCond != undefined) {
      predicates_photo.in(photoAccessHelper.PhotoKeys.DATE_ADDED,
        [updatedTimeCond, Math.floor(Date.now() / 1000) + 10000]);
    }
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

    let photoFetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: assetForAlbumfetchColumns,
      predicates: predicates_photo
    };
    let photoFetchResult = await album.getAssets(photoFetchOptions);

    while (!photoFetchResult.isAfterLast()) {
      let current_asset = await photoFetchResult.getNextObject();
      let uri_input: string[] = [current_asset.uri];

      let fileUriResult_array = await fileUriService.convertFileUris(uri_input);
      let fileUriResult = fileUriResult_array[0];
      if (fileUriResult == undefined) {
        continue;
      }

      let id = fileUriResult?.targetUri;
      let mediaType = current_asset.photoType;
      let name = current_asset.displayName;
      let createdAt: number = current_asset.get(photoAccessHelper.PhotoKeys.DATE_TAKEN) as number ??
        current_asset.get(photoAccessHelper.PhotoKeys.DATE_ADDED) as number;

      let modifiedAt = current_asset.get(photoAccessHelper.PhotoKeys.DATE_MODIFIED) as number;
      let width = current_asset.get(photoAccessHelper.PhotoKeys.WIDTH) as number;
      let height = current_asset.get(photoAccessHelper.PhotoKeys.HEIGHT) as number;
      let duration = mediaType == photoAccessHelper.PhotoType.IMAGE ? 0 : 0; //ohos not support
      //let bucketId = current_asset.get(bucketIdColumn);
      let bucketId = '-1';
      let orientation = current_asset.get(photoAccessHelper.PhotoKeys.ORIENTATION) as number;
      let isFavorite = current_asset.get(photoAccessHelper.PhotoKeys.FAVORITE) as boolean;

      if (!id) continue;

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

      assetResult.push(asset);
    }

    return assetResult;
  }
}

