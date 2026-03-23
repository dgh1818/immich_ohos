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
  private assetId?: string;

  public setAssetId(assetId:string):void {
    this.assetId = assetId;
  }

  getAssetId(): string | undefined{
    return this.assetId;
  }

  private error?: string;

  public setError(error:string):void {
    this.error = error;
  }

  getError(): string | undefined{
    return this.error;
  }

  private hash?: string;

  public setHash(hash:string):void {
    this.hash = hash;
  }

  getHash(): string | undefined{
    return this.hash;
  }

  constructor(assetId?: string, error?: string, hash?: string) {
    this.assetId = assetId;
    this.error = error;
    this.hash = hash;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.assetId !==undefined){
      arr.push(this.assetId);
    }
    if(this.error !==undefined){
      arr.push(this.error);
    }
    if(this.hash !==undefined){
      arr.push(this.hash);
    }
    return arr;
  }

  static fromList(arr: Object[]): HashResult {
    let pigeonResult: HashResult = new HashResult();
    let assetId: Object = arr[0];
    pigeonResult.setAssetId(assetId as string);
    let error: Object = arr[1];
    pigeonResult.setError(error as string);
    let hash: Object = arr[2];
    pigeonResult.setHash(hash as string);
    return pigeonResult;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlatformAsset {
  private id?: string;

  public setId(id:string):void {
    this.id = id;
  }

  getId(): string | undefined{
    return this.id;
  }

  private name?: string;

  public setName(name:string):void {
    this.name = name;
  }

  getName(): string | undefined{
    return this.name;
  }

  private type?: number;

  public setType(type:number):void {
    this.type = type;
  }

  getType(): number | undefined{
    return this.type;
  }

  private createdAt?: number;

  public setCreatedAt(createdAt:number):void {
    this.createdAt = createdAt;
  }

  getCreatedAt(): number | undefined{
    return this.createdAt;
  }

  private updatedAt?: number;

  public setUpdatedAt(updatedAt:number):void {
    this.updatedAt = updatedAt;
  }

  getUpdatedAt(): number | undefined{
    return this.updatedAt;
  }

  private width?: number;

  public setWidth(width:number):void {
    this.width = width;
  }

  getWidth(): number | undefined{
    return this.width;
  }

  private height?: number;

  public setHeight(height:number):void {
    this.height = height;
  }

  getHeight(): number | undefined{
    return this.height;
  }

  private durationInSeconds?: number;

  public setDurationInSeconds(durationInSeconds:number):void {
    this.durationInSeconds = durationInSeconds;
  }

  getDurationInSeconds(): number | undefined{
    return this.durationInSeconds;
  }

  private orientation?: number;

  public setOrientation(orientation:number):void {
    this.orientation = orientation;
  }

  getOrientation(): number | undefined{
    return this.orientation;
  }

  private isFavorite?: boolean;

  public setIsFavorite(isFavorite:boolean):void {
    this.isFavorite = isFavorite;
  }

  getIsFavorite(): boolean | undefined{
    return this.isFavorite;
  }

  private adjustmentTime?: number;

  public setAdjustmentTime(adjustmentTime:number):void {
    this.adjustmentTime = adjustmentTime;
  }

  getAdjustmentTime(): number | undefined{
    return this.adjustmentTime;
  }

  private latitude?: number;

  public setLatitude(latitude:number):void {
    this.latitude = latitude;
  }

  getLatitude(): number | undefined{
    return this.latitude;
  }

  private longitude?: number;

  public setLongitude(longitude:number):void {
    this.longitude = longitude;
  }

  getLongitude(): number | undefined{
    return this.longitude;
  }

  private playbackStyle?: PlatformAssetPlaybackStyle;

  public setPlaybackStyle(playbackStyle:PlatformAssetPlaybackStyle):void {
    this.playbackStyle = playbackStyle;
  }

  getPlaybackStyle(): PlatformAssetPlaybackStyle | undefined{
    return this.playbackStyle;
  }

  constructor(id?: string, name?: string, type?: number, createdAt?: number, updatedAt?: number, width?: number, height?: number, durationInSeconds?: number, orientation?: number, isFavorite?: boolean, adjustmentTime?: number, latitude?: number, longitude?: number, playbackStyle?: PlatformAssetPlaybackStyle) {
    this.id = id;
    this.name = name;
    this.type = type;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.width = width;
    this.height = height;
    this.durationInSeconds = durationInSeconds;
    this.orientation = orientation;
    this.isFavorite = isFavorite;
    this.adjustmentTime = adjustmentTime;
    this.latitude = latitude;
    this.longitude = longitude;
    this.playbackStyle = playbackStyle;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.id !==undefined){
      arr.push(this.id);
    }
    if(this.name !==undefined){
      arr.push(this.name);
    }
    if(this.type !==undefined){
      arr.push(this.type);
    }
    if(this.createdAt !==undefined){
      arr.push(this.createdAt);
    }
    if(this.updatedAt !==undefined){
      arr.push(this.updatedAt);
    }
    if(this.width !==undefined){
      arr.push(this.width);
    }
    if(this.height !==undefined){
      arr.push(this.height);
    }
    if(this.durationInSeconds !==undefined){
      arr.push(this.durationInSeconds);
    }
    if(this.orientation !==undefined){
      arr.push(this.orientation);
    }
    if(this.isFavorite !==undefined){
      arr.push(this.isFavorite);
    }
    if(this.adjustmentTime !==undefined){
      arr.push(this.adjustmentTime);
    }
    if(this.latitude !==undefined){
      arr.push(this.latitude);
    }
    if(this.longitude !==undefined){
      arr.push(this.longitude);
    }
    if(this.playbackStyle !==undefined){
      const playbackStyleStr = PlatformAssetPlaybackStyle[this.playbackStyle as number];
      arr.push(new PlatformAssetPlaybackStyleEnum(playbackStyleStr));
    }
    return arr;
  }

  static fromList(arr: Object[]): PlatformAsset {
    let pigeonResult: PlatformAsset = new PlatformAsset();
    let id: Object = arr[0];
    pigeonResult.setId(id as string);
    let name: Object = arr[1];
    pigeonResult.setName(name as string);
    let type: Object = arr[2];
    pigeonResult.setType(type as number);
    let createdAt: Object = arr[3];
    pigeonResult.setCreatedAt(createdAt as number);
    let updatedAt: Object = arr[4];
    pigeonResult.setUpdatedAt(updatedAt as number);
    let width: Object = arr[5];
    pigeonResult.setWidth(width as number);
    let height: Object = arr[6];
    pigeonResult.setHeight(height as number);
    let durationInSeconds: Object = arr[7];
    pigeonResult.setDurationInSeconds(durationInSeconds as number);
    let orientation: Object = arr[8];
    pigeonResult.setOrientation(orientation as number);
    let isFavorite: Object = arr[9];
    pigeonResult.setIsFavorite(isFavorite as boolean);
    let adjustmentTime: Object = arr[10];
    pigeonResult.setAdjustmentTime(adjustmentTime as number);
    let latitude: Object = arr[11];
    pigeonResult.setLatitude(latitude as number);
    let longitude: Object = arr[12];
    pigeonResult.setLongitude(longitude as number);
    const playbackStyleStr: string = arr[13]! as string;
    pigeonResult.setPlaybackStyle(PlatformAssetPlaybackStyle[playbackStyleStr]);
    return pigeonResult;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlatformAlbum {
  private id?: string;

  public setId(id:string):void {
    this.id = id;
  }

  getId(): string | undefined{
    return this.id;
  }

  private name?: string;

  public setName(name:string):void {
    this.name = name;
  }

  getName(): string | undefined{
    return this.name;
  }

  private updatedAt?: number;

  public setUpdatedAt(updatedAt:number):void {
    this.updatedAt = updatedAt;
  }

  getUpdatedAt(): number | undefined{
    return this.updatedAt;
  }

  private isCloud?: boolean;

  public setIsCloud(isCloud:boolean):void {
    this.isCloud = isCloud;
  }

  getIsCloud(): boolean | undefined{
    return this.isCloud;
  }

  private assetCount?: number;

  public setAssetCount(assetCount:number):void {
    this.assetCount = assetCount;
  }

  getAssetCount(): number | undefined{
    return this.assetCount;
  }

  constructor(id?: string, name?: string, updatedAt?: number, isCloud?: boolean, assetCount?: number) {
    this.id = id;
    this.name = name;
    this.updatedAt = updatedAt;
    this.isCloud = isCloud;
    this.assetCount = assetCount;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.id !==undefined){
      arr.push(this.id);
    }
    if(this.name !==undefined){
      arr.push(this.name);
    }
    if(this.updatedAt !==undefined){
      arr.push(this.updatedAt);
    }
    if(this.isCloud !==undefined){
      arr.push(this.isCloud);
    }
    if(this.assetCount !==undefined){
      arr.push(this.assetCount);
    }
    return arr;
  }

  static fromList(arr: Object[]): PlatformAlbum {
    let pigeonResult: PlatformAlbum = new PlatformAlbum();
    let id: Object = arr[0];
    pigeonResult.setId(id as string);
    let name: Object = arr[1];
    pigeonResult.setName(name as string);
    let updatedAt: Object = arr[2];
    pigeonResult.setUpdatedAt(updatedAt as number);
    let isCloud: Object = arr[3];
    pigeonResult.setIsCloud(isCloud as boolean);
    let assetCount: Object = arr[4];
    pigeonResult.setAssetCount(assetCount as number);
    return pigeonResult;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class CloudIdResult {
  private assetId?: string;

  public setAssetId(assetId:string):void {
    this.assetId = assetId;
  }

  getAssetId(): string | undefined{
    return this.assetId;
  }

  private error?: string;

  public setError(error:string):void {
    this.error = error;
  }

  getError(): string | undefined{
    return this.error;
  }

  private cloudId?: string;

  public setCloudId(cloudId:string):void {
    this.cloudId = cloudId;
  }

  getCloudId(): string | undefined{
    return this.cloudId;
  }

  constructor(assetId?: string, error?: string, cloudId?: string) {
    this.assetId = assetId;
    this.error = error;
    this.cloudId = cloudId;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.assetId !==undefined){
      arr.push(this.assetId);
    }
    if(this.error !==undefined){
      arr.push(this.error);
    }
    if(this.cloudId !==undefined){
      arr.push(this.cloudId);
    }
    return arr;
  }

  static fromList(arr: Object[]): CloudIdResult {
    let pigeonResult: CloudIdResult = new CloudIdResult();
    let assetId: Object = arr[0];
    pigeonResult.setAssetId(assetId as string);
    let error: Object = arr[1];
    pigeonResult.setError(error as string);
    let cloudId: Object = arr[2];
    pigeonResult.setCloudId(cloudId as string);
    return pigeonResult;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class SyncDelta {
  private hasChanges?: boolean;

  public setHasChanges(hasChanges:boolean):void {
    this.hasChanges = hasChanges;
  }

  getHasChanges(): boolean | undefined{
    return this.hasChanges;
  }

  private updates?: Array<PlatformAsset>;

  public setUpdates(updates:Array<PlatformAsset>):void {
    this.updates = updates;
  }

  getUpdates(): Array<PlatformAsset> | undefined{
    return this.updates;
  }

  private deletes?: Array<string>;

  public setDeletes(deletes:Array<string>):void {
    this.deletes = deletes;
  }

  getDeletes(): Array<string> | undefined{
    return this.deletes;
  }

  private assetAlbums?: Map<string, Array<string>>;

  public setAssetAlbums(assetAlbums:Map<string, Array<string>>):void {
    this.assetAlbums = assetAlbums;
  }

  getAssetAlbums(): Map<string, Array<string>> | undefined{
    return this.assetAlbums;
  }

  constructor(hasChanges?: boolean, updates?: Array<PlatformAsset>, deletes?: Array<string>, assetAlbums?: Map<string, Array<string>>) {
    this.hasChanges = hasChanges;
    this.updates = updates;
    this.deletes = deletes;
    this.assetAlbums = assetAlbums;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.hasChanges !==undefined){
      arr.push(this.hasChanges);
    }
    if(this.updates !==undefined){
      arr.push(this.updates);
    }
    if(this.deletes !==undefined){
      arr.push(this.deletes);
    }
    if(this.assetAlbums !==undefined){
      arr.push(this.assetAlbums);
    }
    return arr;
  }

  static fromList(arr: Object[]): SyncDelta {
    let pigeonResult: SyncDelta = new SyncDelta();
    let hasChanges: Object = arr[0];
    pigeonResult.setHasChanges(hasChanges as boolean);
    let updates: Object = arr[1];
    pigeonResult.setUpdates(updates as Array<PlatformAsset>);
    let deletes: Object = arr[2];
    pigeonResult.setDeletes(deletes as Array<string>);
    let assetAlbums: Object = arr[3];
    pigeonResult.setAssetAlbums(assetAlbums as Map<string, Array<string>>);
    return pigeonResult;
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
        return HashResult.fromList(super.readValue(buffer) as Object[]);
      case this.getByte(131):
        return PlatformAsset.fromList(super.readValue(buffer) as Object[]);
      case this.getByte(132):
        return PlatformAlbum.fromList(super.readValue(buffer) as Object[]);
      case this.getByte(133):
        return CloudIdResult.fromList(super.readValue(buffer) as Object[]);
      case this.getByte(134):
        return SyncDelta.fromList(super.readValue(buffer) as Object[]);
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

  abstract startBackgroundTransfer(result: Result<number>): void;

  abstract updateBackgroundTransferProgress(progress: number , title: string , fileName: string , result: Result<void>): void;

  abstract stopBackgroundTransfer(result: Result<void>): void;

  abstract getTrashedAssets(): Map<string, Array<PlatformAsset>>;

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
