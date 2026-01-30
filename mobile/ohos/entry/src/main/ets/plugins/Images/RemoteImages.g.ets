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
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer , value: ESObject): ESObject{
    {
      super.writeValue(stream, value);
    }
  }
}


export interface Result<T> {
  success( result: T ): void;

  error( error: Error): void;
}
/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class RemoteImageApiOhos {

  abstract requestImage(url: string , headers: Map<string, string> , requestId: number , result: Result<Map<string, Object>>): void;

  abstract cancelRequest(requestId: number ): void;

  abstract clearCache(result: Result<number>): void;
  /** The codec used by RemoteImageApiOhos. */
  static getCodec(): MessageCodec<Object>{
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `RemoteImageApiOhos` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: RemoteImageApiOhos | null): void {
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.RemoteImageApiOhos.requestImage", RemoteImageApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<Map<string, Object>>{
                    success(result: Map<string, Object>): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<Map<string, Object>> = new ResultImp();

              api!.requestImage(args[0] as string, args[1] as Map<string, string>, args[2] as number, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.RemoteImageApiOhos.cancelRequest", RemoteImageApiOhos.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              let res: Array<Object> = [];
              try {
                api!.cancelRequest(args[0] as number);
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
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.RemoteImageApiOhos.clearCache", RemoteImageApiOhos.getCodec());
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

              api!.clearCache(resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
  }
}
