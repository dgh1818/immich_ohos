import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import BasicMessageChannel, { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { BinaryMessenger,TaskQueue } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
import MessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/MessageCodec';
import { ByteBuffer } from '@ohos/flutter_ohos/src/main/ets/util/ByteBuffer';


/** Error class for passing custom error details to Flutter via a thrown PlatformException. */
export class FlutterError implements Error {

  /** The error code. */
  public code: string;

  /** The error name. */
  public name: string;

  /** The error message. */
  public message: string;
  /** The error stack. */
  public stack?: string;

  constructor(code: string, name: string,  message: string, stack?: string) 
  {
    this.code = code;
    this.name = name;
    this.message = message;
    this.stack = stack;
  }
}

function wrapError(error: Error): Array<Object> {
  let errorList: Array<Object> = new Array<Object>(3);
  if (error instanceof FlutterError) {
    let err: FlutterError = error as FlutterError;
    errorList[0] = err.code;
    errorList[1] = err.name;
    errorList[2] = err.message;
  } else {
    errorList[0] = error.toString();
    errorList[1] = error.name;
    errorList[2] = "Cause: " + error.message + ", Stacktrace: " + error.stack;
  }
  return errorList;
}

/* Generated enum from Pigeon that represents data sent in messages.*/
export enum PlatformAssetPlaybackStyle {
  UNKNOWN,
  IMAGE,
  VIDEO,
  IMAGE_ANIMATED,
  LIVE_PHOTO,
  VIDEO_LOOPING
}

/* Generated enum Companion class from Pigeon that represents data sent 
   in messages.Do not delete otherwise enum type data transfer will be failed*/
export class PlatformAssetPlaybackStyleEnum {
  index: string|null = null;
	constructor(index: string){
    this.index = index;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class HashResult {
  private assetId: string;

  public setAssetId(assetId:string):void {
    this.assetId = assetId;
  }

  getAssetId(): string{
    return this.assetId;
  }

  private error?: string;

  public setError(error:string | undefined):void {
    this.error = error;
  }

  getError(): string | undefined{
    return this.error;
  }

  private hash?: string;

  public setHash(hash:string | undefined):void {
    this.hash = hash;
  }

  getHash(): string | undefined{
    return this.hash;
  }

  constructor(assetId: string, error?: string, hash?: string) {
    this.assetId = assetId;
    this.error = error;
    this.hash = hash;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.assetId !== undefined ? this.assetId : null);
    arr.push(this.error !== undefined ? this.error : null);
    arr.push(this.hash !== undefined ? this.hash : null);
    return arr;
  }

  static fromList(arr: (Object | null)[]): HashResult {
    let assetId: string = arr[0] as string;
    let error: string | undefined = arr[1] != null ? arr[1] as string : undefined;
    let hash: string | undefined = arr[2] != null ? arr[2] as string : undefined;
    return new HashResult(assetId, error, hash);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlatformAsset {
  private id: string;

  public setId(id:string):void {
    this.id = id;
  }

  getId(): string{
    return this.id;
  }

  private name: string;

  public setName(name:string):void {
    this.name = name;
  }

  getName(): string{
    return this.name;
  }

  private type: number;

  public setType(type:number):void {
    this.type = type;
  }

  getType(): number{
    return this.type;
  }

  private createdAt?: number;

  public setCreatedAt(createdAt:number | undefined):void {
    this.createdAt = createdAt;
  }

  getCreatedAt(): number | undefined{
    return this.createdAt;
  }

  private updatedAt?: number;

  public setUpdatedAt(updatedAt:number | undefined):void {
    this.updatedAt = updatedAt;
  }

  getUpdatedAt(): number | undefined{
    return this.updatedAt;
  }

  private width?: number;

  public setWidth(width:number | undefined):void {
    this.width = width;
  }

  getWidth(): number | undefined{
    return this.width;
  }

  private height?: number;

  public setHeight(height:number | undefined):void {
    this.height = height;
  }

  getHeight(): number | undefined{
    return this.height;
  }

  private durationMs: number;

  public setDurationMs(durationMs:number):void {
    this.durationMs = durationMs;
  }

  getDurationMs(): number{
    return this.durationMs;
  }

  private orientation: number;

  public setOrientation(orientation:number):void {
    this.orientation = orientation;
  }

  getOrientation(): number{
    return this.orientation;
  }

  private isFavorite: boolean;

  public setIsFavorite(isFavorite:boolean):void {
    this.isFavorite = isFavorite;
  }

  getIsFavorite(): boolean{
    return this.isFavorite;
  }

  private adjustmentTime?: number;

  public setAdjustmentTime(adjustmentTime:number | undefined):void {
    this.adjustmentTime = adjustmentTime;
  }

  getAdjustmentTime(): number | undefined{
    return this.adjustmentTime;
  }

  private latitude?: number;

  public setLatitude(latitude:number | undefined):void {
    this.latitude = latitude;
  }

  getLatitude(): number | undefined{
    return this.latitude;
  }

  private longitude?: number;

  public setLongitude(longitude:number | undefined):void {
    this.longitude = longitude;
  }

  getLongitude(): number | undefined{
    return this.longitude;
  }

  private playbackStyle: PlatformAssetPlaybackStyle;

  public setPlaybackStyle(playbackStyle:PlatformAssetPlaybackStyle):void {
    this.playbackStyle = playbackStyle;
  }

  getPlaybackStyle(): PlatformAssetPlaybackStyle{
    return this.playbackStyle;
  }

  constructor(id: string, name: string, type: number, durationMs: number, orientation: number, isFavorite: boolean, playbackStyle: PlatformAssetPlaybackStyle, createdAt?: number, updatedAt?: number, width?: number, height?: number, adjustmentTime?: number, latitude?: number, longitude?: number) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.durationMs = durationMs;
    this.orientation = orientation;
    this.isFavorite = isFavorite;
    this.playbackStyle = playbackStyle;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.width = width;
    this.height = height;
    this.adjustmentTime = adjustmentTime;
    this.latitude = latitude;
    this.longitude = longitude;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.id !== undefined ? this.id : null);
    arr.push(this.name !== undefined ? this.name : null);
    arr.push(this.type !== undefined ? this.type : null);
    arr.push(this.createdAt !== undefined ? this.createdAt : null);
    arr.push(this.updatedAt !== undefined ? this.updatedAt : null);
    arr.push(this.width !== undefined ? this.width : null);
    arr.push(this.height !== undefined ? this.height : null);
    arr.push(this.durationMs !== undefined ? this.durationMs : null);
    arr.push(this.orientation !== undefined ? this.orientation : null);
    arr.push(this.isFavorite !== undefined ? this.isFavorite : null);
    arr.push(this.adjustmentTime !== undefined ? this.adjustmentTime : null);
    arr.push(this.latitude !== undefined ? this.latitude : null);
    arr.push(this.longitude !== undefined ? this.longitude : null);
    if (this.playbackStyle !== undefined) {
      const playbackStyleStr = PlatformAssetPlaybackStyle[this.playbackStyle as number];
      arr.push(new PlatformAssetPlaybackStyleEnum(playbackStyleStr));
    } else {
      arr.push(null);
    }
    return arr;
  }

  static fromList(arr: (Object | null)[]): PlatformAsset {
    let id: string = arr[0] as string;
    let name: string = arr[1] as string;
    let type: number = arr[2] as number;
    let createdAt: number | undefined = arr[3] != null ? arr[3] as number : undefined;
    let updatedAt: number | undefined = arr[4] != null ? arr[4] as number : undefined;
    let width: number | undefined = arr[5] != null ? arr[5] as number : undefined;
    let height: number | undefined = arr[6] != null ? arr[6] as number : undefined;
    let durationMs: number = arr[7] as number;
    let orientation: number = arr[8] as number;
    let isFavorite: boolean = arr[9] as boolean;
    let adjustmentTime: number | undefined = arr[10] != null ? arr[10] as number : undefined;
    let latitude: number | undefined = arr[11] != null ? arr[11] as number : undefined;
    let longitude: number | undefined = arr[12] != null ? arr[12] as number : undefined;
    let playbackStyleRaw: Object | null = arr[13];
    const playbackStyleStr: string = playbackStyleRaw as string;
    let playbackStyle: PlatformAssetPlaybackStyle = PlatformAssetPlaybackStyle[playbackStyleStr];
    return new PlatformAsset(id, name, type, durationMs, orientation, isFavorite, playbackStyle, createdAt, updatedAt, width, height, adjustmentTime, latitude, longitude);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlatformAlbum {
  private id: string;

  public setId(id:string):void {
    this.id = id;
  }

  getId(): string{
    return this.id;
  }

  private name: string;

  public setName(name:string):void {
    this.name = name;
  }

  getName(): string{
    return this.name;
  }

  private updatedAt?: number;

  public setUpdatedAt(updatedAt:number | undefined):void {
    this.updatedAt = updatedAt;
  }

  getUpdatedAt(): number | undefined{
    return this.updatedAt;
  }

  private isCloud: boolean;

  public setIsCloud(isCloud:boolean):void {
    this.isCloud = isCloud;
  }

  getIsCloud(): boolean{
    return this.isCloud;
  }

  private assetCount: number;

  public setAssetCount(assetCount:number):void {
    this.assetCount = assetCount;
  }

  getAssetCount(): number{
    return this.assetCount;
  }

  constructor(id: string, name: string, isCloud: boolean, assetCount: number, updatedAt?: number) {
    this.id = id;
    this.name = name;
    this.isCloud = isCloud;
    this.assetCount = assetCount;
    this.updatedAt = updatedAt;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.id !== undefined ? this.id : null);
    arr.push(this.name !== undefined ? this.name : null);
    arr.push(this.updatedAt !== undefined ? this.updatedAt : null);
    arr.push(this.isCloud !== undefined ? this.isCloud : null);
    arr.push(this.assetCount !== undefined ? this.assetCount : null);
    return arr;
  }

  static fromList(arr: (Object | null)[]): PlatformAlbum {
    let id: string = arr[0] as string;
    let name: string = arr[1] as string;
    let updatedAt: number | undefined = arr[2] != null ? arr[2] as number : undefined;
    let isCloud: boolean = arr[3] as boolean;
    let assetCount: number = arr[4] as number;
    return new PlatformAlbum(id, name, isCloud, assetCount, updatedAt);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class CloudIdResult {
  private assetId: string;

  public setAssetId(assetId:string):void {
    this.assetId = assetId;
  }

  getAssetId(): string{
    return this.assetId;
  }

  private error?: string;

  public setError(error:string | undefined):void {
    this.error = error;
  }

  getError(): string | undefined{
    return this.error;
  }

  private cloudId?: string;

  public setCloudId(cloudId:string | undefined):void {
    this.cloudId = cloudId;
  }

  getCloudId(): string | undefined{
    return this.cloudId;
  }

  constructor(assetId: string, error?: string, cloudId?: string) {
    this.assetId = assetId;
    this.error = error;
    this.cloudId = cloudId;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.assetId !== undefined ? this.assetId : null);
    arr.push(this.error !== undefined ? this.error : null);
    arr.push(this.cloudId !== undefined ? this.cloudId : null);
    return arr;
  }

  static fromList(arr: (Object | null)[]): CloudIdResult {
    let assetId: string = arr[0] as string;
    let error: string | undefined = arr[1] != null ? arr[1] as string : undefined;
    let cloudId: string | undefined = arr[2] != null ? arr[2] as string : undefined;
    return new CloudIdResult(assetId, error, cloudId);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class SyncDelta {
  private hasChanges: boolean;

  public setHasChanges(hasChanges:boolean):void {
    this.hasChanges = hasChanges;
  }

  getHasChanges(): boolean{
    return this.hasChanges;
  }

  private updates: Array<PlatformAsset>;

  public setUpdates(updates:Array<PlatformAsset>):void {
    this.updates = updates;
  }

  getUpdates(): Array<PlatformAsset>{
    return this.updates;
  }

  private deletes: Array<string>;

  public setDeletes(deletes:Array<string>):void {
    this.deletes = deletes;
  }

  getDeletes(): Array<string>{
    return this.deletes;
  }

  private assetAlbums: Map<string, Array<string>>;

  public setAssetAlbums(assetAlbums:Map<string, Array<string>>):void {
    this.assetAlbums = assetAlbums;
  }

  getAssetAlbums(): Map<string, Array<string>>{
    return this.assetAlbums;
  }

  constructor(hasChanges: boolean, updates: Array<PlatformAsset>, deletes: Array<string>, assetAlbums: Map<string, Array<string>>) {
    this.hasChanges = hasChanges;
    this.updates = updates;
    this.deletes = deletes;
    this.assetAlbums = assetAlbums;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.hasChanges !== undefined ? this.hasChanges : null);
    arr.push(this.updates !== undefined ? this.updates : null);
    arr.push(this.deletes !== undefined ? this.deletes : null);
    arr.push(this.assetAlbums !== undefined ? this.assetAlbums : null);
    return arr;
  }

  static fromList(arr: (Object | null)[]): SyncDelta {
    let hasChanges: boolean = arr[0] as boolean;
    let updates: Array<PlatformAsset> = arr[1] as Array<PlatformAsset>;
    let deletes: Array<string> = arr[2] as Array<string>;
    let assetAlbums: Map<string, Array<string>> = arr[3] as Map<string, Array<string>>;
    return new SyncDelta(hasChanges, updates, deletes, assetAlbums);
  }
}

export class PigeonCodec extends StandardMessageCodec {
  static readonly INSTANCE: PigeonCodec  = new PigeonCodec();

  getByte(n: number): number {
    let byteArray = new Uint8Array(1);
    byteArray[0] = n;
    return byteArray[0] as number;
  }
  private constructor() {
    super();
  }

  readValueOfType(type: number,  buffer: ByteBuffer): ESObject {
    switch (type) {
      case this.getByte(129): {
        let value: Object= super.readValue(buffer);
        return value == null ? null : PlatformAssetPlaybackStyle[value as number];
      }
      case this.getByte(130):
        return HashResult.fromList(super.readValue(buffer) as (Object | null)[]);
      case this.getByte(131):
        return PlatformAsset.fromList(super.readValue(buffer) as (Object | null)[]);
      case this.getByte(132):
        return PlatformAlbum.fromList(super.readValue(buffer) as (Object | null)[]);
      case this.getByte(133):
        return CloudIdResult.fromList(super.readValue(buffer) as (Object | null)[]);
      case this.getByte(134):
        return SyncDelta.fromList(super.readValue(buffer) as (Object | null)[]);
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer , value: ESObject): ESObject{
    if (value instanceof PlatformAssetPlaybackStyleEnum) {
      stream.writeUint8(this.getByte(129));
      this.writeValue(stream, value == null ? null : PlatformAssetPlaybackStyle[value.index as string]);
    } else if (value instanceof HashResult) {
      stream.writeUint8(this.getByte(130));
      this.writeValue(stream, (value as HashResult).toList());
    } else if (value instanceof PlatformAsset) {
      stream.writeUint8(this.getByte(131));
      this.writeValue(stream, (value as PlatformAsset).toList());
    } else if (value instanceof PlatformAlbum) {
      stream.writeUint8(this.getByte(132));
      this.writeValue(stream, (value as PlatformAlbum).toList());
    } else if (value instanceof CloudIdResult) {
      stream.writeUint8(this.getByte(133));
      this.writeValue(stream, (value as CloudIdResult).toList());
    } else if (value instanceof SyncDelta) {
      stream.writeUint8(this.getByte(134));
      this.writeValue(stream, (value as SyncDelta).toList());
    } else {
      super.writeValue(stream, value);
    }
  }
}


export interface Result<T> {
  success( result: T ): void;

  error( error: Error): void;
}
/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class NativeSyncApiOhos {

  abstract shouldFullSync(): boolean;

  abstract getMediaChanges(): SyncDelta;

  abstract checkpointSync(): void;

  abstract clearSyncCheckpoint(): void;

  abstract getAssetIdsForAlbum(albumId: string , result: Result<Array<string>>): void;

  abstract getAlbums(result: Result<Array<PlatformAlbum>>): void;

  abstract getAssetsCountSince(albumId: string , timestamp: number , result: Result<number>): void;

  abstract getAssetsForAlbum(albumId: string , updatedTimeCond: number , result: Result<Array<PlatformAsset>>): void;

  abstract hashAssets(assetIds: Array<string> , allowNetworkAccess: boolean , result: Result<Array<HashResult>>): void;

  abstract cancelHashing(): void;

  abstract cancelSync(): void;

  abstract startBackgroundTransfer(result: Result<number>): void;

  abstract updateBackgroundTransferProgress(progress: number , title: string , fileName: string , result: Result<void>): void;

  abstract stopBackgroundTransfer(result: Result<void>): void;

  abstract getTrashedAssets(): Map<string, Array<PlatformAsset>>;

  abstract restoreFromTrashById(mediaId: string , type: number , result: Result<boolean>): void;

  abstract getPathFromUri(uri: string , result: Result<string>): void;

  abstract getCloudIdForAssetIds(assetIds: Array<string> , result: Result<Array<CloudIdResult>>): void;
  /** The codec used by NativeSyncApiOhos. */
  static getCodec(): MessageCodec<Object>{
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `NativeSyncApiOhos` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: NativeSyncApiOhos | null): void {
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.shouldFullSync", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: boolean = api!.shouldFullSync();
                res.push(output);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getMediaChanges", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: SyncDelta = api!.getMediaChanges();
                res.push(output);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.checkpointSync", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                api!.checkpointSync();
                res.push(null);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.clearSyncCheckpoint", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                api!.clearSyncCheckpoint();
                res.push(null);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAssetIdsForAlbum", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<Array<string>>{
                    success(result: Array<string>): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Array<string>> = new ResultImp();

              api!.getAssetIdsForAlbum(args[0] as string, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAlbums", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              class ResultImp implements Result<Array<PlatformAlbum>>{
                    success(result: Array<PlatformAlbum>): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Array<PlatformAlbum>> = new ResultImp();

              api!.getAlbums(resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAssetsCountSince", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<number>{
                    success(result: number): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<number> = new ResultImp();

              api!.getAssetsCountSince(args[0] as string, args[1] as number, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAssetsForAlbum", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<Array<PlatformAsset>>{
                    success(result: Array<PlatformAsset>): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Array<PlatformAsset>> = new ResultImp();

              api!.getAssetsForAlbum(args[0] as string, args[1] as number, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.hashAssets", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<Array<HashResult>>{
                    success(result: Array<HashResult>): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Array<HashResult>> = new ResultImp();

              api!.hashAssets(args[0] as Array<string>, args[1] as boolean, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.cancelHashing", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                api!.cancelHashing();
                res.push(null);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.cancelSync", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                api!.cancelSync();
                res.push(null);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.startBackgroundTransfer", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              class ResultImp implements Result<number>{
                    success(result: number): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<number> = new ResultImp();

              api!.startBackgroundTransfer(resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.updateBackgroundTransferProgress", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<void>{
                    success(result: void): void {
                      let res: Array<Object> = [];
                      res.push(null);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<void> = new ResultImp();

              api!.updateBackgroundTransferProgress(args[0] as number, args[1] as string, args[2] as string, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.stopBackgroundTransfer", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              class ResultImp implements Result<void>{
                    success(result: void): void {
                      let res: Array<Object> = [];
                      res.push(null);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<void> = new ResultImp();

              api!.stopBackgroundTransfer(resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getTrashedAssets", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: Map<string, Array<PlatformAsset>> = api!.getTrashedAssets();
                res.push(output);
              }
 catch (error) {
                let wrappedError: Array<Object> = wrapError(error);
                res = wrappedError;
              }
              reply.reply(res);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.restoreFromTrashById", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<boolean>{
                    success(result: boolean): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<boolean> = new ResultImp();

              api!.restoreFromTrashById(args[0] as string, args[1] as number, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getPathFromUri", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<string>{
                    success(result: string): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<string> = new ResultImp();

              api!.getPathFromUri(args[0] as string, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getCloudIdForAssetIds", NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<Array<CloudIdResult>>{
                    success(result: Array<CloudIdResult>): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Array<CloudIdResult>> = new ResultImp();

              api!.getCloudIdForAssetIds(args[0] as Array<string>, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
  }
}
