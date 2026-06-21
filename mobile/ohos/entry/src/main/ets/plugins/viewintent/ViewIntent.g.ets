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

/* Generated class from Pigeon that represents data sent in messages.*/
export class ViewIntentPayload {
  private path?: string;

  public setPath(path:string):void {
    this.path = path;
  }

  getPath(): string | undefined{
    return this.path;
  }

  private mimeType?: string;

  public setMimeType(mimeType:string):void {
    this.mimeType = mimeType;
  }

  getMimeType(): string | undefined{
    return this.mimeType;
  }

  private localAssetId?: string;

  public setLocalAssetId(localAssetId:string):void {
    this.localAssetId = localAssetId;
  }

  getLocalAssetId(): string | undefined{
    return this.localAssetId;
  }

  constructor(path?: string, mimeType?: string, localAssetId?: string) {
    this.path = path;
    this.mimeType = mimeType;
    this.localAssetId = localAssetId;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.path !==undefined){
      arr.push(this.path);
    }
    if(this.mimeType !==undefined){
      arr.push(this.mimeType);
    }
    if(this.localAssetId !==undefined){
      arr.push(this.localAssetId);
    }
    return arr;
  }

  static fromList(arr: Object[]): ViewIntentPayload {
    let pigeonResult: ViewIntentPayload = new ViewIntentPayload();
    let path: Object = arr[0];
    pigeonResult.setPath(path as string);
    let mimeType: Object = arr[1];
    pigeonResult.setMimeType(mimeType as string);
    let localAssetId: Object = arr[2];
    pigeonResult.setLocalAssetId(localAssetId as string);
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
      case this.getByte(129):
        return ViewIntentPayload.fromList(super.readValue(buffer) as Object[]);
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer , value: ESObject): ESObject{
    if (value instanceof ViewIntentPayload) {
      stream.writeUint8(this.getByte(129));
      this.writeValue(stream, (value as ViewIntentPayload).toList());
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
export abstract class ViewIntentHostApi {

  abstract consumeViewIntent(result: Result<ViewIntentPayload>): void;
  /** The codec used by ViewIntentHostApi. */
  static getCodec(): MessageCodec<Object>{
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `ViewIntentHostApi` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: ViewIntentHostApi | null): void {
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.ViewIntentHostApi.consumeViewIntent", ViewIntentHostApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              class ResultImp implements Result<ViewIntentPayload>{
                    success(result: ViewIntentPayload): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<ViewIntentPayload> = new ResultImp();

              api!.consumeViewIntent(resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
  }
}
