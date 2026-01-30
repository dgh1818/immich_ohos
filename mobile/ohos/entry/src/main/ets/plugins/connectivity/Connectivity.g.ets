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
export enum NetworkCapability {
  CELLULAR,
  WIFI,
  VPN,
  UNMETERED
}

/* Generated enum Companion class from Pigeon that represents data sent 
   in messages.Do not delete otherwise enum type data transfer will be failed*/
export class NetworkCapabilityEnum {
  index: string|null = null;
	constructor(index: string){
    this.index = index;
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
        return value == null ? null : NetworkCapability[value as number];
      }
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer , value: ESObject): ESObject{
    if (value instanceof NetworkCapabilityEnum) {
      stream.writeUint8(this.getByte(129));
      this.writeValue(stream, value == null ? null : NetworkCapability[value.index as string]);
    } else {
      super.writeValue(stream, value);
    }
  }
}

/* Generated abstract class from Pigeon that represents a handler of messages from Flutter.*/
export abstract class ConnectivityApi {

  abstract getCapabilities(): Array<NetworkCapability>;
  /** The codec used by ConnectivityApi. */
  static getCodec(): MessageCodec<Object>{
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `ConnectivityApi` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: ConnectivityApi | null): void {
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.ConnectivityApi.getCapabilities", ConnectivityApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: Array<NetworkCapability> = api!.getCapabilities();
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
  }
}
