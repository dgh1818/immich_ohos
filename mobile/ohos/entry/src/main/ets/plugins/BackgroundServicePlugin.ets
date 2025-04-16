import { FlutterPlugin, FlutterPluginBinding, MethodCall,
  MethodCallHandler,
  MethodChannel, MethodResult,
  StandardMethodCodec } from "@ohos/flutter_ohos";
import router from '@ohos.router';
import { ErrorCode, UIAbility } from "@kit.AbilityKit";
import { hash } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';


export class BackgroundServicePlugin implements FlutterPlugin,MethodCallHandler{
  private channel: MethodChannel | null = null;
  //private photoPlugin?:PhotoPlugin;
  getUniqueClassName(): string {
    return "BackgroundServicePlugin"
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "digestFiles":
        this.handleDigestFiles(call,result)
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "immich/foregroundChannel");
    this.channel.setMethodCallHandler(this);

  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
  }

    // let longitude: string = args[i] as number;
    //
    // hash.hash(path, 'SHA1', (err: BusinessError, digest: string)
    //
    // // 异步处理所有文件哈希
  hexStringToBytes(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
      bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
    }
    return bytes;
  }

  handleDigestFiles(call: MethodCall, result: MethodResult) {
    const args: string[] = call.args as string[];
    const promises: Promise<Uint8Array | null>[] = [];

    for (let i = 0; i < args.length; i++) {
      const promise = new Promise<Uint8Array | null>((resolve) => {
        hash.hash(args[i], "sha1", (err: BusinessError, digest: string) => {
          if (err) {
            console.error(`Cannot calculate digest of ${args[i]}: ${err.message}`);
            resolve(null);
          } else {
            try {
              const bytes: Uint8Array = this.hexStringToBytes(digest);
              resolve(bytes);
            } catch (e) {
              console.error(`Invalid digest format for ${args[i]}: ${e}`);
              resolve(null);
            }
          }
        });
      });
      promises.push(promise);
    }

    Promise.all(promises)
      .then((hashes) => {
        result.success(hashes);
      })
      .catch((error: BusinessError) => {
        result.error(
          'HASH_FAILURE',
          `Failed to process ${args.length} files`,
          args.map(() => null)
        );
      });
  }
}
