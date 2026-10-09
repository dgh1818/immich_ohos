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

/* Generated class from Pigeon that represents data sent in messages.*/
export class BackgroundWorkerSettings {
  private requiresCharging: boolean;

  public setRequiresCharging(requiresCharging: boolean): void {
    this.requiresCharging = requiresCharging;
  }

  getRequiresCharging(): boolean {
    return this.requiresCharging;
  }

  private minimumDelaySeconds: number;

  public setMinimumDelaySeconds(minimumDelaySeconds: number): void {
    this.minimumDelaySeconds = minimumDelaySeconds;
  }

  getMinimumDelaySeconds(): number {
    return this.minimumDelaySeconds;
  }

  constructor(requiresCharging: boolean, minimumDelaySeconds: number) {
    this.requiresCharging = requiresCharging;
    this.minimumDelaySeconds = minimumDelaySeconds;
  }

  toList(): Array<Object | null> {
    let arr: Array<Object | null> = new Array<Object | null>();
    if (this.requiresCharging === undefined || this.requiresCharging === null) {
      arr.push(null);
    } else {
      arr.push(this.requiresCharging);
    }
    if (this.minimumDelaySeconds === undefined || this.minimumDelaySeconds === null) {
      arr.push(null);
    } else {
      arr.push(this.minimumDelaySeconds);
    }
    return arr;
  }

  static fromList(arr: Object[]): BackgroundWorkerSettings {
    let requiresChargingObject: Object = arr[0];
    const requiresCharging: boolean = requiresChargingObject as boolean;
    let minimumDelaySecondsObject: Object = arr[1];
    const minimumDelaySeconds: number = minimumDelaySecondsObject as number;
    return new BackgroundWorkerSettings(requiresCharging, minimumDelaySeconds);
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
      case this.getByte(129):
        return BackgroundWorkerSettings.fromList(super.readValue(buffer) as Object[]);
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer, value: ESObject): ESObject {
    if (value instanceof BackgroundWorkerSettings) {
      stream.writeUint8(this.getByte(129));
      this.writeValue(stream, (value as BackgroundWorkerSettings).toList());
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
export abstract class BackgroundWorkerFgHostApi {

  abstract enable(): void;

  abstract saveNotificationMessage(title: string, body: string): void;

  abstract configure(settings: BackgroundWorkerSettings): void;

  abstract disable(): void;

  abstract wasLaunchedInBackground(): boolean;
  /** The codec used by BackgroundWorkerFgHostApi. */
  static getCodec(): MessageCodec<Object> {
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `BackgroundWorkerFgHostApi` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: BackgroundWorkerFgHostApi | null, messageChannelSuffix: string = ''): void {
    const separatedMessageChannelSuffix: string = messageChannelSuffix !== '' ? '.' + messageChannelSuffix : '';
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFgHostApi.enable' + separatedMessageChannelSuffix, BackgroundWorkerFgHostApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.enable();
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFgHostApi.saveNotificationMessage' + separatedMessageChannelSuffix, BackgroundWorkerFgHostApi.getCodec());
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
              let res: Array<Object | null> = [];
              try {
                api!.saveNotificationMessage(args[0] as string, args[1] as string);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFgHostApi.configure' + separatedMessageChannelSuffix, BackgroundWorkerFgHostApi.getCodec());
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
              let res: Array<Object | null> = [];
              try {
                api!.configure(args[0] as BackgroundWorkerSettings);
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFgHostApi.disable' + separatedMessageChannelSuffix, BackgroundWorkerFgHostApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.disable();
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFgHostApi.wasLaunchedInBackground' + separatedMessageChannelSuffix, BackgroundWorkerFgHostApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                let output: boolean = api!.wasLaunchedInBackground();
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
  }
}
/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class BackgroundWorkerBgHostApi {

  abstract onInitialized(): void;

  abstract close(): void;
  /** The codec used by BackgroundWorkerBgHostApi. */
  static getCodec(): MessageCodec<Object> {
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `BackgroundWorkerBgHostApi` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: BackgroundWorkerBgHostApi | null, messageChannelSuffix: string = ''): void {
    const separatedMessageChannelSuffix: string = messageChannelSuffix !== '' ? '.' + messageChannelSuffix : '';
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerBgHostApi.onInitialized' + separatedMessageChannelSuffix, BackgroundWorkerBgHostApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.onInitialized();
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
              binaryMessenger, 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerBgHostApi.close' + separatedMessageChannelSuffix, BackgroundWorkerBgHostApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object, reply: Reply<Object>) {
              let res: Array<Object | null> = [];
              try {
                api!.close();
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
  }
}
/* Generated class from Pigeon that represents Flutter messages that can be called from ArkTS.*/
export class BackgroundWorkerFlutterApi {
  binaryMessenger: BinaryMessenger;
  private messageChannelSuffix: string;

  constructor(binaryMessenger: BinaryMessenger, messageChannelSuffix: string = '') {
    this.binaryMessenger = binaryMessenger;
    this.messageChannelSuffix = messageChannelSuffix !== '' ? '.' + messageChannelSuffix : '';
  }

  /** The codec used by BackgroundWorkerFlutterApi. */
  static getCodec(): MessageCodec<Object> {
    return PigeonCodec.INSTANCE;
  }

  onIosUpload(isRefreshArg: boolean,maxSecondsArg: number | undefined, callback: Reply<void>) {
    const channelName: string = 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFlutterApi.onIosUpload' + this.messageChannelSuffix;
    let channel: BasicMessageChannel<Object> = 
        new BasicMessageChannel<Object>(
            this.binaryMessenger, channelName, BackgroundWorkerFlutterApi.getCodec());
    channel.send(
        [isRefreshArg, maxSecondsArg],
        channelReply => {
          if (Array.isArray(channelReply)) {
            let listReply: ESObject[] = channelReply as ESObject[];
            if (listReply.length > 1) {
              let arrFirst:string = listReply[0] as string;
              let arrSecond:string = listReply[1] as string;
              let arrThird:string = listReply[2] as string;
              let replyArr: ESObject = new FlutterError(arrFirst, arrSecond, arrThird);
              callback.reply(replyArr);
            } else {
              callback.reply();
            }
          } else {
            let connErr: ESObject = new FlutterError('channel-error', 'Unable to establish connection on channel: ' + channelName + '.', '');
            callback.reply(connErr);
          } 
        });
  }
  onAndroidUpload(maxMinutesArg: number | undefined, callback: Reply<boolean>) {
    const channelName: string = 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFlutterApi.onAndroidUpload' + this.messageChannelSuffix;
    let channel: BasicMessageChannel<Object> = 
        new BasicMessageChannel<Object>(
            this.binaryMessenger, channelName, BackgroundWorkerFlutterApi.getCodec());
    channel.send(
        [maxMinutesArg],
        channelReply => {
          if (Array.isArray(channelReply)) {
            let listReply: ESObject[] = channelReply as ESObject[];
            if (listReply.length > 1) {
              let arrFirst:string = listReply[0] as string;
              let arrSecond:string = listReply[1] as string;
              let arrThird:string = listReply[2] as string;
              let replyArr: ESObject = new FlutterError(arrFirst, arrSecond, arrThird);
              callback.reply(replyArr);
            } else if (listReply[0] == null) {
              let replyNull: ESObject = new FlutterError('null-error', 'Flutter api returned null value for non-null return value.', '');
              callback.reply(replyNull);
            } else {
              let output:boolean = listReply[0] as boolean;
              callback.reply(output);
            }
          } else {
            let connErr: ESObject = new FlutterError('channel-error', 'Unable to establish connection on channel: ' + channelName + '.', '');
            callback.reply(connErr);
          } 
        });
  }
  cancel(callback: Reply<void>):void {
    const channelName: string = 'dev.flutter.pigeon.immich_mobile.BackgroundWorkerFlutterApi.cancel' + this.messageChannelSuffix;
    let channel: BasicMessageChannel<Object> = 
        new BasicMessageChannel<Object>(
            this.binaryMessenger, channelName, BackgroundWorkerFlutterApi.getCodec());
    channel.send(
        null,
        channelReply => {
          if (Array.isArray(channelReply)) {
            let listReply: ESObject[] = channelReply as ESObject[];
            if (listReply.length > 1) {
              let arrFirst:string = listReply[0] as string;
              let arrSecond:string = listReply[1] as string;
              let arrThird:string = listReply[2] as string;
              let replyArr: ESObject = new FlutterError(arrFirst, arrSecond, arrThird);
              callback.reply(replyArr);
            } else {
              callback.reply();
            }
          } else {
            let connErr: ESObject = new FlutterError('channel-error', 'Unable to establish connection on channel: ' + channelName + '.', '');
            callback.reply(connErr);
          } 
        });
  }
}
