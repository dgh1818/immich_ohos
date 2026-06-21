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
  private data?: Uint8Array;

  public setData(data:Uint8Array):void {
    this.data = data;
  }

  getData(): Uint8Array | undefined{
    return this.data;
  }

  private password?: string;

  public setPassword(password:string):void {
    this.password = password;
  }

  getPassword(): string | undefined{
    return this.password;
  }

  constructor(data?: Uint8Array, password?: string) {
    this.data = data;
    this.password = password;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.data !==undefined){
      arr.push(this.data);
    }
    if(this.password !==undefined){
      arr.push(this.password);
    }
    return arr;
  }

  static fromList(arr: Object[]): ClientCertData {
    let pigeonResult: ClientCertData = new ClientCertData();
    let data: Object = arr[0];
    pigeonResult.setData(data as Uint8Array);
    let password: Object = arr[1];
    pigeonResult.setPassword(password as string);
    return pigeonResult;
  }
}

/* Generated class from Pigeon that represents data sent in messages.*/
export class ClientCertPrompt {
  private title?: string;

  public setTitle(title:string):void {
    this.title = title;
  }

  getTitle(): string | undefined{
    return this.title;
  }

  private message?: string;

  public setMessage(message:string):void {
    this.message = message;
  }

  getMessage(): string | undefined{
    return this.message;
  }

  private cancel?: string;

  public setCancel(cancel:string):void {
    this.cancel = cancel;
  }

  getCancel(): string | undefined{
    return this.cancel;
  }

  private confirm?: string;

  public setConfirm(confirm:string):void {
    this.confirm = confirm;
  }

  getConfirm(): string | undefined{
    return this.confirm;
  }

  constructor(title?: string, message?: string, cancel?: string, confirm?: string) {
    this.title = title;
    this.message = message;
    this.cancel = cancel;
    this.confirm = confirm;
  }

  toList(): Object[] {
    let arr: Object[] = new Array();
    if(this.title !==undefined){
      arr.push(this.title);
    }
    if(this.message !==undefined){
      arr.push(this.message);
    }
    if(this.cancel !==undefined){
      arr.push(this.cancel);
    }
    if(this.confirm !==undefined){
      arr.push(this.confirm);
    }
    return arr;
  }

  static fromList(arr: Object[]): ClientCertPrompt {
    let pigeonResult: ClientCertPrompt = new ClientCertPrompt();
    let title: Object = arr[0];
    pigeonResult.setTitle(title as string);
    let message: Object = arr[1];
    pigeonResult.setMessage(message as string);
    let cancel: Object = arr[2];
    pigeonResult.setCancel(cancel as string);
    let confirm: Object = arr[3];
    pigeonResult.setConfirm(confirm as string);
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
        return ClientCertData.fromList(super.readValue(buffer) as Object[]);
      case this.getByte(130):
        return ClientCertPrompt.fromList(super.readValue(buffer) as Object[]);
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

  abstract hasCertificate(): boolean;

  abstract getClientPointer(): number;

  abstract setRequestHeaders(headers: Map<string, string> , serverUrls: Array<string> , token: string | null ): void;

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
                api!.setRequestHeaders(args[0] as Map<string, string>, args[1] as Array<string>, args[2] as string | null);
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
