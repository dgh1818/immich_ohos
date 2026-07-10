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
export class ClientCertData {
  private data: Uint8Array;

  public setData(data:Uint8Array):void {
    this.data = data;
  }

  getData(): Uint8Array{
    return this.data;
  }

  private password: string;

  public setPassword(password:string):void {
    this.password = password;
  }

  getPassword(): string{
    return this.password;
  }

  constructor(data: Uint8Array, password: string) {
    this.data = data;
    this.password = password;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.data !== undefined ? this.data : null);
    arr.push(this.password !== undefined ? this.password : null);
    return arr;
  }

  static fromList(arr: (Object | null)[]): ClientCertData {
    let data: Uint8Array = arr[0] as Uint8Array;
    let password: string = arr[1] as string;
    return new ClientCertData(data, password);
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class ClientCertPrompt {
  private title: string;

  public setTitle(title:string):void {
    this.title = title;
  }

  getTitle(): string{
    return this.title;
  }

  private message: string;

  public setMessage(message:string):void {
    this.message = message;
  }

  getMessage(): string{
    return this.message;
  }

  private cancel: string;

  public setCancel(cancel:string):void {
    this.cancel = cancel;
  }

  getCancel(): string{
    return this.cancel;
  }

  private confirm: string;

  public setConfirm(confirm:string):void {
    this.confirm = confirm;
  }

  getConfirm(): string{
    return this.confirm;
  }

  constructor(title: string, message: string, cancel: string, confirm: string) {
    this.title = title;
    this.message = message;
    this.cancel = cancel;
    this.confirm = confirm;
  }

  toList(): (Object | null)[] {
    let arr: (Object | null)[] = [];
    arr.push(this.title !== undefined ? this.title : null);
    arr.push(this.message !== undefined ? this.message : null);
    arr.push(this.cancel !== undefined ? this.cancel : null);
    arr.push(this.confirm !== undefined ? this.confirm : null);
    return arr;
  }

  static fromList(arr: (Object | null)[]): ClientCertPrompt {
    let title: string = arr[0] as string;
    let message: string = arr[1] as string;
    let cancel: string = arr[2] as string;
    let confirm: string = arr[3] as string;
    return new ClientCertPrompt(title, message, cancel, confirm);
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
        return ClientCertData.fromList(super.readValue(buffer) as (Object | null)[]);
      case this.getByte(130):
        return ClientCertPrompt.fromList(super.readValue(buffer) as (Object | null)[]);
      default:
        return super.readValueOfType(type, buffer);
    }
  }

  writeValue(stream: ByteBuffer , value: ESObject): ESObject{
    if (value instanceof ClientCertData) {
      stream.writeUint8(this.getByte(129));
      this.writeValue(stream, (value as ClientCertData).toList());
    } else if (value instanceof ClientCertPrompt) {
      stream.writeUint8(this.getByte(130));
      this.writeValue(stream, (value as ClientCertPrompt).toList());
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
export abstract class NetworkApi {

  abstract addCertificate(clientData: ClientCertData , result: Result<void>): void;

  abstract selectCertificate(promptText: ClientCertPrompt , result: Result<ClientCertData>): void;

  abstract removeCertificate(result: Result<void>): void;

  abstract setCaBundle(pemData: Uint8Array , result: Result<void>): void;

  abstract hasCertificate(): boolean;

  abstract getClientPointer(): number;

  abstract setRequestHeaders(headers: Map<string, string> , serverUrls: Array<string> , token: string ): void;

  abstract getAppGroupId(): string;
  /** The codec used by NetworkApi. */
  static getCodec(): MessageCodec<Object>{
    return PigeonCodec.INSTANCE;
  }
  /*Sets up an instance of `NetworkApi` to handle messages through the `binaryMessenger`.*/
  static setup(binaryMessenger: BinaryMessenger, api: NetworkApi | null): void {
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.addCertificate", NetworkApi.getCodec());
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

              api!.addCertificate(args[0] as ClientCertData, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.selectCertificate", NetworkApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              class ResultImp implements Result<ClientCertData>{
                    success(result: ClientCertData): void {
                      let res: Array<Object> = [];
                      res.push(result);
                      reply.reply(res);
                    }

                    error(error: Error): void {
                      let wrappedError: Array<Object> = wrapError(error);
                      reply.reply(wrappedError);
                    }
              }
              let resultCallback: Result<ClientCertData> = new ResultImp();

              api!.selectCertificate(args[0] as ClientCertPrompt, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.removeCertificate", NetworkApi.getCodec());
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

              api!.removeCertificate(resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.setCaBundle", NetworkApi.getCodec());
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

              api!.setCaBundle(args[0] as Uint8Array, resultCallback);
            } });
      } else {
        channel.setMessageHandler(null);
      }
    }
    {
      let channel: BasicMessageChannel<Object> =
          new BasicMessageChannel(
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.hasCertificate", NetworkApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: boolean = api!.hasCertificate();
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
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.getClientPointer", NetworkApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: number = api!.getClientPointer();
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
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.setRequestHeaders", NetworkApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let args: Array<Object> = message as Array<Object>;
              let res: Array<Object> = [];
              try {
                api!.setRequestHeaders(args[0] as Map<string, string>, args[1] as Array<string>, args[2] as string);
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
              binaryMessenger, "dev.flutter.pigeon.immich_mobile.NetworkApi.getAppGroupId", NetworkApi.getCodec());
      if (api != null) {
        channel.setMessageHandler({
            onMessage(message: Object ,reply: Reply<Object> ) {
              let res: Array<Object> = [];
              try {
                let output: string = api!.getAppGroupId();
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
