/*
* Copyright (C) 2024 Huawei Device Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
import StandardMessageCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMessageCodec';
import BasicMessageChannel, { Reply } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BasicMessageChannel';
import { BinaryMessenger } from '@ohos/flutter_ohos/src/main/ets/plugin/common/BinaryMessenger';
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

  constructor(code: string, name: string, message: string, stack?: string) {
    this.code = code;
    this.name = name;
    this.message = message;
    this.stack = stack;
  }
}

/**
 * Wrapper so PigeonCodec always serializes a Dart `double` as float64.
 * ArkTS `number` values such as `1` or `1.0` would otherwise be encoded
 * as integers by StandardMessageCodec and fail strict Dart double casts.
 */
export class PigeonInternalDoubleBox {
  value: number;
  constructor(value: number) {
    this.value = value;
  }
}

function wrapError(error: Error): Array<Object | null> {
  let errorList: Array<Object | null> = new Array<Object | null>(3);
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
  index: string | null = null;
  constructor(index: string) {
    this.index = index;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class HashResult {
  private assetId: string;

  public setAssetId(assetId: string): void {
    this.assetId = assetId;
  }

  getAssetId(): string {
    return this.assetId;
  }

  private error?: string;

  public setError(error: string | undefined): void {
    this.error = error;
  }

  getError(): string | undefined {
    return this.error;
  }

  private hash?: string;

  public setHash(hash: string | undefined): void {
    this.hash = hash;
  }

  getHash(): string | undefined {
    return this.hash;
  }

  constructor(assetId: string, error?: string, hash?: string) {
    this.assetId = assetId;
    this.error = error;
    this.hash = hash;
  }

  toList(): Array<Object | null> {
    let arr: Array<Object | null> = new Array<Object | null>();
    if (this.assetId === undefined || this.assetId === null) {
      arr.push(null);
    } else {
      arr.push(this.assetId);
    }
    if (this.error === undefined || this.error === null) {
      arr.push(null);
    } else {
      arr.push(this.error);
    }
    if (this.hash === undefined || this.hash === null) {
      arr.push(null);
    } else {
      arr.push(this.hash);
    }
    return arr;
  }

  static fromList(arr: Object[]): HashResult {
    let assetIdObject: Object = arr[0];
    const assetId: string = assetIdObject as string;
    let error: string | undefined = undefined;
    if (arr[1] !== null && arr[1] !== undefined) {
      let errorObject: Object = arr[1];
      error = errorObject as string | undefined;
    }
    let hash: string | undefined = undefined;
    if (arr[2] !== null && arr[2] !== undefined) {
      let hashObject: Object = arr[2];
      hash = hashObject as string | undefined;
    }
    return new HashResult(assetId, error, hash);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlatformAsset {
  private id: string;

  public setId(id: string): void {
    this.id = id;
  }

  getId(): string {
    return this.id;
  }

  private name: string;

  public setName(name: string): void {
    this.name = name;
  }

  getName(): string {
    return this.name;
  }

  private type: number;

  public setType(type: number): void {
    this.type = type;
  }

  getType(): number {
    return this.type;
  }

  private createdAt?: number;

  public setCreatedAt(createdAt: number | undefined): void {
    this.createdAt = createdAt;
  }

  getCreatedAt(): number | undefined {
    return this.createdAt;
  }

  private updatedAt?: number;

  public setUpdatedAt(updatedAt: number | undefined): void {
    this.updatedAt = updatedAt;
  }

  getUpdatedAt(): number | undefined {
    return this.updatedAt;
  }

  private width?: number;

  public setWidth(width: number | undefined): void {
    this.width = width;
  }

  getWidth(): number | undefined {
    return this.width;
  }

  private height?: number;

  public setHeight(height: number | undefined): void {
    this.height = height;
  }

  getHeight(): number | undefined {
    return this.height;
  }

  private durationMs: number;

  public setDurationMs(durationMs: number): void {
    this.durationMs = durationMs;
  }

  getDurationMs(): number {
    return this.durationMs;
  }

  private orientation: number;

  public setOrientation(orientation: number): void {
    this.orientation = orientation;
  }

  getOrientation(): number {
    return this.orientation;
  }

  private isFavorite: boolean;

  public setIsFavorite(isFavorite: boolean): void {
    this.isFavorite = isFavorite;
  }

  getIsFavorite(): boolean {
    return this.isFavorite;
  }

  private adjustmentTime?: number;

  public setAdjustmentTime(adjustmentTime: number | undefined): void {
    this.adjustmentTime = adjustmentTime;
  }

  getAdjustmentTime(): number | undefined {
    return this.adjustmentTime;
  }

  private latitude?: number;

  public setLatitude(latitude: number | undefined): void {
    this.latitude = latitude;
  }

  getLatitude(): number | undefined {
    return this.latitude;
  }

  private longitude?: number;

  public setLongitude(longitude: number | undefined): void {
    this.longitude = longitude;
  }

  getLongitude(): number | undefined {
    return this.longitude;
  }

  private playbackStyle: PlatformAssetPlaybackStyle;

  public setPlaybackStyle(playbackStyle: PlatformAssetPlaybackStyle): void {
    this.playbackStyle = playbackStyle;
  }

  getPlaybackStyle(): PlatformAssetPlaybackStyle {
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

  toList(): Array<Object | null> {
    let arr: Array<Object | null> = new Array<Object | null>();
    if (this.id === undefined || this.id === null) {
      arr.push(null);
    } else {
      arr.push(this.id);
    }
    if (this.name === undefined || this.name === null) {
      arr.push(null);
    } else {
      arr.push(this.name);
    }
    if (this.type === undefined || this.type === null) {
      arr.push(null);
    } else {
      arr.push(this.type);
    }
    if (this.createdAt === undefined || this.createdAt === null) {
      arr.push(null);
    } else {
      arr.push(this.createdAt);
    }
    if (this.updatedAt === undefined || this.updatedAt === null) {
      arr.push(null);
    } else {
      arr.push(this.updatedAt);
    }
    if (this.width === undefined || this.width === null) {
      arr.push(null);
    } else {
      arr.push(this.width);
    }
    if (this.height === undefined || this.height === null) {
      arr.push(null);
    } else {
      arr.push(this.height);
    }
    if (this.durationMs === undefined || this.durationMs === null) {
      arr.push(null);
    } else {
      arr.push(this.durationMs);
    }
    if (this.orientation === undefined || this.orientation === null) {
      arr.push(null);
    } else {
      arr.push(this.orientation);
    }
    if (this.isFavorite === undefined || this.isFavorite === null) {
      arr.push(null);
    } else {
      arr.push(this.isFavorite);
    }
    if (this.adjustmentTime === undefined || this.adjustmentTime === null) {
      arr.push(null);
    } else {
      arr.push(this.adjustmentTime);
    }
    if (this.latitude === undefined || this.latitude === null) {
      arr.push(null);
    } else {
      arr.push((this.latitude === null || this.latitude === undefined ? null : new PigeonInternalDoubleBox(this.latitude)));
    }
    if (this.longitude === undefined || this.longitude === null) {
      arr.push(null);
    } else {
      arr.push((this.longitude === null || this.longitude === undefined ? null : new PigeonInternalDoubleBox(this.longitude)));
    }
    if (this.playbackStyle === undefined || this.playbackStyle === null) {
      arr.push(null);
    } else {
      const playbackStyleStr = PlatformAssetPlaybackStyle[this.playbackStyle as number];
      arr.push(new PlatformAssetPlaybackStyleEnum(playbackStyleStr));
    }
    return arr;
  }

  static fromList(arr: Object[]): PlatformAsset {
    let idObject: Object = arr[0];
    const id: string = idObject as string;
    let nameObject: Object = arr[1];
    const name: string = nameObject as string;
    let typeObject: Object = arr[2];
    const type: number = typeObject as number;
    let createdAt: number | undefined = undefined;
    if (arr[3] !== null && arr[3] !== undefined) {
      let createdAtObject: Object = arr[3];
      createdAt = createdAtObject as number | undefined;
    }
    let updatedAt: number | undefined = undefined;
    if (arr[4] !== null && arr[4] !== undefined) {
      let updatedAtObject: Object = arr[4];
      updatedAt = updatedAtObject as number | undefined;
    }
    let width: number | undefined = undefined;
    if (arr[5] !== null && arr[5] !== undefined) {
      let widthObject: Object = arr[5];
      width = widthObject as number | undefined;
    }
    let height: number | undefined = undefined;
    if (arr[6] !== null && arr[6] !== undefined) {
      let heightObject: Object = arr[6];
      height = heightObject as number | undefined;
    }
    let durationMsObject: Object = arr[7];
    const durationMs: number = durationMsObject as number;
    let orientationObject: Object = arr[8];
    const orientation: number = orientationObject as number;
    let isFavoriteObject: Object = arr[9];
    const isFavorite: boolean = isFavoriteObject as boolean;
    let adjustmentTime: number | undefined = undefined;
    if (arr[10] !== null && arr[10] !== undefined) {
      let adjustmentTimeObject: Object = arr[10];
      adjustmentTime = adjustmentTimeObject as number | undefined;
    }
    let latitude: number | undefined = undefined;
    if (arr[11] !== null && arr[11] !== undefined) {
      let latitudeObject: Object = arr[11];
      latitude = latitudeObject as number | undefined;
    }
    let longitude: number | undefined = undefined;
    if (arr[12] !== null && arr[12] !== undefined) {
      let longitudeObject: Object = arr[12];
      longitude = longitudeObject as number | undefined;
    }
    const playbackStyleStr: string = arr[13] as string;
    const playbackStyle: PlatformAssetPlaybackStyle = PlatformAssetPlaybackStyle[playbackStyleStr];
    return new PlatformAsset(id, name, type, durationMs, orientation, isFavorite, playbackStyle, createdAt, updatedAt, width, height, adjustmentTime, latitude, longitude);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class PlatformAlbum {
  private id: string;

  public setId(id: string): void {
    this.id = id;
  }

  getId(): string {
    return this.id;
  }

  private name: string;

  public setName(name: string): void {
    this.name = name;
  }

  getName(): string {
    return this.name;
  }

  private updatedAt?: number;

  public setUpdatedAt(updatedAt: number | undefined): void {
    this.updatedAt = updatedAt;
  }

  getUpdatedAt(): number | undefined {
    return this.updatedAt;
  }

  private isCloud: boolean;

  public setIsCloud(isCloud: boolean): void {
    this.isCloud = isCloud;
  }

  getIsCloud(): boolean {
    return this.isCloud;
  }

  private assetCount: number;

  public setAssetCount(assetCount: number): void {
    this.assetCount = assetCount;
  }

  getAssetCount(): number {
    return this.assetCount;
  }

  constructor(id: string, name: string, isCloud: boolean, assetCount: number, updatedAt?: number) {
    this.id = id;
    this.name = name;
    this.isCloud = isCloud;
    this.assetCount = assetCount;
    this.updatedAt = updatedAt;
  }

  toList(): Array<Object | null> {
    let arr: Array<Object | null> = new Array<Object | null>();
    if (this.id === undefined || this.id === null) {
      arr.push(null);
    } else {
      arr.push(this.id);
    }
    if (this.name === undefined || this.name === null) {
      arr.push(null);
    } else {
      arr.push(this.name);
    }
    if (this.updatedAt === undefined || this.updatedAt === null) {
      arr.push(null);
    } else {
      arr.push(this.updatedAt);
    }
    if (this.isCloud === undefined || this.isCloud === null) {
      arr.push(null);
    } else {
      arr.push(this.isCloud);
    }
    if (this.assetCount === undefined || this.assetCount === null) {
      arr.push(null);
    } else {
      arr.push(this.assetCount);
    }
    return arr;
  }

  static fromList(arr: Object[]): PlatformAlbum {
    let idObject: Object = arr[0];
    const id: string = idObject as string;
    let nameObject: Object = arr[1];
    const name: string = nameObject as string;
    let updatedAt: number | undefined = undefined;
    if (arr[2] !== null && arr[2] !== undefined) {
      let updatedAtObject: Object = arr[2];
      updatedAt = updatedAtObject as number | undefined;
    }
    let isCloudObject: Object = arr[3];
    const isCloud: boolean = isCloudObject as boolean;
    let assetCountObject: Object = arr[4];
    const assetCount: number = assetCountObject as number;
    return new PlatformAlbum(id, name, isCloud, assetCount, updatedAt);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class CloudIdResult {
  private assetId: string;

  public setAssetId(assetId: string): void {
    this.assetId = assetId;
  }

  getAssetId(): string {
    return this.assetId;
  }

  private error?: string;

  public setError(error: string | undefined): void {
    this.error = error;
  }

  getError(): string | undefined {
    return this.error;
  }

  private cloudId?: string;

  public setCloudId(cloudId: string | undefined): void {
    this.cloudId = cloudId;
  }

  getCloudId(): string | undefined {
    return this.cloudId;
  }

  constructor(assetId: string, error?: string, cloudId?: string) {
    this.assetId = assetId;
    this.error = error;
    this.cloudId = cloudId;
  }

  toList(): Array<Object | null> {
    let arr: Array<Object | null> = new Array<Object | null>();
    if (this.assetId === undefined || this.assetId === null) {
      arr.push(null);
    } else {
      arr.push(this.assetId);
    }
    if (this.error === undefined || this.error === null) {
      arr.push(null);
    } else {
      arr.push(this.error);
    }
    if (this.cloudId === undefined || this.cloudId === null) {
      arr.push(null);
    } else {
      arr.push(this.cloudId);
    }
    return arr;
  }

  static fromList(arr: Object[]): CloudIdResult {
    let assetIdObject: Object = arr[0];
    const assetId: string = assetIdObject as string;
    let error: string | undefined = undefined;
    if (arr[1] !== null && arr[1] !== undefined) {
      let errorObject: Object = arr[1];
      error = errorObject as string | undefined;
    }
    let cloudId: string | undefined = undefined;
    if (arr[2] !== null && arr[2] !== undefined) {
      let cloudIdObject: Object = arr[2];
      cloudId = cloudIdObject as string | undefined;
    }
    return new CloudIdResult(assetId, error, cloudId);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class SyncDelta {
  private hasChanges: boolean;

  public setHasChanges(hasChanges: boolean): void {
    this.hasChanges = hasChanges;
  }

  getHasChanges(): boolean {
    return this.hasChanges;
  }

  private updates: Array<PlatformAsset>;

  public setUpdates(updates: Array<PlatformAsset>): void {
    this.updates = updates;
  }

  getUpdates(): Array<PlatformAsset> {
    return this.updates;
  }

  private deletes: Array<string>;

  public setDeletes(deletes: Array<string>): void {
    this.deletes = deletes;
  }

  getDeletes(): Array<string> {
    return this.deletes;
  }

  private assetAlbums: Map<string, Array<string>>;

  public setAssetAlbums(assetAlbums: Map<string, Array<string>>): void {
    this.assetAlbums = assetAlbums;
  }

  getAssetAlbums(): Map<string, Array<string>> {
    return this.assetAlbums;
  }

  constructor(hasChanges: boolean, updates: Array<PlatformAsset>, deletes: Array<string>, assetAlbums: Map<string, Array<string>>) {
    this.hasChanges = hasChanges;
    this.updates = updates;
    this.deletes = deletes;
    this.assetAlbums = assetAlbums;
  }

  toList(): Array<Object | null> {
    let arr: Array<Object | null> = new Array<Object | null>();
    if (this.hasChanges === undefined || this.hasChanges === null) {
      arr.push(null);
    } else {
      arr.push(this.hasChanges);
    }
    if (this.updates === undefined || this.updates === null) {
      arr.push(null);
    } else {
      arr.push(this.updates);
    }
    if (this.deletes === undefined || this.deletes === null) {
      arr.push(null);
    } else {
      arr.push(this.deletes);
    }
    if (this.assetAlbums === undefined || this.assetAlbums === null) {
      arr.push(null);
    } else {
      arr.push(this.assetAlbums);
    }
    return arr;
  }

  static fromList(arr: Object[]): SyncDelta {
    let hasChangesObject: Object = arr[0];
    const hasChanges: boolean = hasChangesObject as boolean;
    let updatesObject: Object = arr[1];
    const updates: Array<PlatformAsset> = updatesObject as Array<PlatformAsset>;
    let deletesObject: Object = arr[2];
    const deletes: Array<string> = deletesObject as Array<string>;
    let assetAlbumsObject: Object = arr[3];
    const assetAlbums: Map<string, Array<string>> = assetAlbumsObject as Map<string, Array<string>>;
    return new SyncDelta(hasChanges, updates, deletes, assetAlbums);
  }
}

export class PigeonCodec extends StandardMessageCodec {
  static readonly INSTANCE: PigeonCodec = new PigeonCodec();

  getByte(n: number): number {
    let byteArray = new Uint8Array(1);
    byteArray[0] = n;
    return byteArray[0] as number;
  }
  private constructor() {
    super();
  }

  readValueOfType(type: number, buffer: ByteBuffer): ESObject {
    switch (type) {
      case this.getByte(129): {
        let value: Object = super.readValue(buffer);
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

  writeValue(stream: ByteBuffer, value: ESObject): ESObject {
    if (value instanceof PigeonInternalDoubleBox) {
      stream.writeInt8(this.getByte(6));
      this.writeAlignment(stream, 8);
      stream.writeFloat64((value as PigeonInternalDoubleBox).value, true);
      return;
    } else     if (value instanceof PlatformAssetPlaybackStyleEnum) {
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
  success(result: T): void;

  error(error: Error): void;
}
/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class NativeSyncApiOhos {

  abstract shouldFullSync(): boolean;

  abstract getMediaChanges(): SyncDelta;

  abstract checkpointSync(): void;

  abstract clearSyncCheckpoint(): void;

  abstract getAssetIdsForAlbum(albumId: string, result: Result<Array<string>>): void;

  abstract getAlbums(result: Result<Array<PlatformAlbum>>): void;

  abstract getAssetsCountSince(albumId: string, timestamp: number, result: Result<number>): void;

  abstract getAssetsForAlbum(albumId: string, updatedTimeCond: number | undefined, result: Result<Array<PlatformAsset>>): void;

  abstract hashAssets(assetIds: Array<string>, allowNetworkAccess: boolean, result: Result<Array<HashResult>>): void;

  abstract cancelHashing(): void;

  abstract cancelSync(): void;

  abstract startBackgroundTransfer(result: Result<number>): void;

  abstract updateBackgroundTransferProgress(progress: number, title: string, fileName: string, result: Result<void>): void;

  abstract stopBackgroundTransfer(result: Result<void>): void;

  abstract getTrashedAssets(): Map<string, Array<PlatformAsset>>;

  abstract restoreFromTrashById(mediaId: string, type: number, result: Result<boolean>): void;

  abstract getPathFromUri(uri: string, result: Result<string>): void;

  abstract getCloudIdForAssetIds(assetIds: Array<string>, result: Result<Array<CloudIdResult>>): void;
  /** The codec used by NativeSyncApiOhos. */
  static getCodec(): MessageCodec<Object> {
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `NativeSyncApiOhos` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: NativeSyncApiOhos | null, messageChannelSuffix: string = ''): void {
    const separatedMessageChannelSuffix: string = messageChannelSuffix !== '' ? '.' + messageChannelSuffix : '';
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.shouldFullSync' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                let output: boolean = api!.shouldFullSync();
                res.push(output);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getMediaChanges' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                let output: SyncDelta = api!.getMediaChanges();
                res.push(output);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.checkpointSync' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.checkpointSync();
                res.push(null);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.clearSyncCheckpoint' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.clearSyncCheckpoint();
                res.push(null);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAssetIdsForAlbum' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 1) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 1 argument(s).')));
                  return;
              }
              class ResultImp implements Result<Array<string>>{
                    success(result: Array<string>): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAlbums' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              class ResultImp implements Result<Array<PlatformAlbum>>{
                    success(result: Array<PlatformAlbum>): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAssetsCountSince' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 2) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 2 argument(s).')));
                  return;
              }
              class ResultImp implements Result<number>{
                    success(result: number): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getAssetsForAlbum' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 2) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 2 argument(s).')));
                  return;
              }
              class ResultImp implements Result<Array<PlatformAsset>>{
                    success(result: Array<PlatformAsset>): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Array<PlatformAsset>> = new ResultImp();

              api!.getAssetsForAlbum(args[0] as string, args[1] as number | undefined, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.hashAssets' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 2) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 2 argument(s).')));
                  return;
              }
              class ResultImp implements Result<Array<HashResult>>{
                    success(result: Array<HashResult>): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.cancelHashing' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.cancelHashing();
                res.push(null);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.cancelSync' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.cancelSync();
                res.push(null);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.startBackgroundTransfer' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              class ResultImp implements Result<number>{
                    success(result: number): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.updateBackgroundTransferProgress' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 3) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 3 argument(s).')));
                  return;
              }
              class ResultImp implements Result<void>{
                    success(result: void): void {
                      let res: Array<Object | null> = [];
                      res.push(null);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.stopBackgroundTransfer' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              class ResultImp implements Result<void>{
                    success(result: void): void {
                      let res: Array<Object | null> = [];
                      res.push(null);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getTrashedAssets' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                let output: Map<string, Array<PlatformAsset>> = api!.getTrashedAssets();
                res.push(output);
              } catch (error) {
                let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.restoreFromTrashById' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 2) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 2 argument(s).')));
                  return;
              }
              class ResultImp implements Result<boolean>{
                    success(result: boolean): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getPathFromUri' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 1) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 1 argument(s).')));
                  return;
              }
              class ResultImp implements Result<string>{
                    success(result: string): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.NativeSyncApiOhos.getCloudIdForAssetIds' + separatedMessageChannelSuffix, NativeSyncApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              if (!(Array.isArray(message))) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected List.')));
                  return;
              }
              let args: Array<Object> = message as Array<Object>;
              if (args.length < 1) {
                  reply.reply(wrapError(new Error('Invalid Pigeon message: expected at least 1 argument(s).')));
                  return;
              }
              class ResultImp implements Result<Array<CloudIdResult>>{
                    success(result: Array<CloudIdResult>): void {
                      let res: Array<Object | null> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object | null> = wrapError(error);
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
