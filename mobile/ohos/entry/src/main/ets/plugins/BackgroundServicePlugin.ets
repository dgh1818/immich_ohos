import { FlutterPlugin, FlutterPluginBinding, MethodCall,
  MethodCallHandler,
  MethodChannel, MethodResult,
  StandardMethodCodec,AbilityAware,AbilityPluginBinding,FlutterLoader,
  PluginRegistry } from "@ohos/flutter_ohos";
import { abilityAccessCtrl, common, ErrorCode, PermissionRequestResult, Permissions,
  sendableContextManager,
  StartOptions,
  UIAbility,
  Want } from "@kit.AbilityKit";
import { hash } from '@kit.CoreFileKit';
import { BusinessError } from '@ohos.base';
import { ArrayList, MessageEvents, uri, url, worker} from "@kit.ArkTS";
import { fileUri } from '@kit.CoreFileKit';
import dataPreferences from '@ohos.data.preferences'
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import FileUtils from "image_picker_ohos/src/main/ets/image_picker/FileUtils";
import { dataSharePredicates } from "@kit.ArkData";
import { ContentObserverWorker } from "../workers/ContentObserverWorkerImpl";
import { BackupWorker } from "../workers/BackupWorkerImpl";

@Sendable
export class SendableObject {
  //constructor(sendableContext: sendableContextManager.SendableContext, contextName: string) {
    constructor(command:string,sendableContext: sendableContextManager.SendableContext, immediate?:boolean,requireWifi?:boolean,requireCharging?:boolean,triggerUpdateDelay?:number,triggerMaxDelay?:number) {

    this.command = command;
    this.sendableContext = sendableContext;
    this.immediate = immediate;
    this.requireWifi = requireWifi;
    this.requireCharging = requireCharging;
    this.triggerUpdateDelay = triggerUpdateDelay;
    this.triggerMaxDelay = triggerMaxDelay;

  }

  //args: Map<string, ESObject>;
  command:string = "";
  sendableContext:sendableContextManager.SendableContext;
  immediate?:boolean = false;
  requireWifi?: boolean = false;
  requireCharging?: boolean = false;
  triggerUpdateDelay?: number = 5000;
  triggerMaxDelay?: number  = 50000;
}

export class BackgroundServicePlugin implements FlutterPlugin, MethodCallHandler, AbilityAware{
  private methodChannel?: MethodChannel = undefined;
  private fileTrashChannel?: MethodChannel = undefined;
  private context: common.Context = getContext();
  private activityBinding?: AbilityPluginBinding = undefined;

  private uiContext: common.UIAbilityContext | null = null;
  private static ignoreCheck: boolean = false;
  private sendableCtx?:sendableContextManager.SendableContext = undefined;
  private ContentObserverWorker?:worker.ThreadWorker;
  private BackupWorker?:worker.ThreadWorker;

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    //context = ctx //move to onAttachedToAbility
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), "immich/foregroundChannel");
    this.methodChannel.setMethodCallHandler(this);

    // Add file trash channel
    this.fileTrashChannel = new MethodChannel(binding.getBinaryMessenger(), "file_trash");
    this.methodChannel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(undefined);
    this.methodChannel = undefined;
    this.fileTrashChannel?.setMethodCallHandler(undefined);
    this.fileTrashChannel = undefined;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    let ctx = this.uiContext;
    console.error(call.method);
    switch (call.method) {
      case "enable":
        let args0:ArrayList<ESObject> = call.args as ArrayList<ESObject>;
        dataPreferences.getPreferences(this.uiContext, BackupWorker.SHARED_PREF_NAME, (err, preferences) => {
          if (err) {
            console.error('获取Preferences实例失败:', err)
            return
          }
          preferences.putSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED,true);
          preferences.putSync(BackupWorker.SHARED_PREF_CALLBACK_KEY,args0[0] as number);
          preferences.putSync(BackupWorker.SHARED_PREF_NOTIFICATION_TITLE,args0[1] as string);
          preferences.flushSync();
          console.log('获取Preferences实例成功')

          result.success(true);

          // if(this.sendableCtx != undefined) {
          //   let object1: SendableObject = new SendableObject("doWork", this.sendableCtx,args0[2] as boolean)
          //   this.ContentObserverWorker = new worker.ThreadWorker('../workers/ContentObserverWorker');
          //   this.ContentObserverWorker.postMessageWithSharedSendable(object1);
          //   let object2: SendableObject = new SendableObject("enable", this.sendableCtx,args0[2] as boolean)
          //   this.ContentObserverWorker.postMessageWithSharedSendable(object2);
          //   result.success(true)
          // }    //上架屏蔽
        })
        break;

      case "configure":
        let args1:ArrayList<ESObject> = call.args as ArrayList<ESObject>;
        let requireUnmeteredNetwork = args1[0] as boolean;
        let requireCharging = args1[1] as boolean;
        let triggerUpdateDelay = args1[2] as number;
        let triggerMaxDelay = args1[3] as number;

        if(this.sendableCtx!=undefined) {
          let object: SendableObject = new SendableObject("configureWork", this.sendableCtx,undefined,requireUnmeteredNetwork,requireCharging,triggerUpdateDelay,triggerMaxDelay);
          this.ContentObserverWorker?.postMessageWithSharedSendable(object);
          result.success(true);
        }
        break;

      case "disable":
        if(this.sendableCtx!=undefined) {
          let object: SendableObject = new SendableObject("disable", this.sendableCtx)
          if(this.ContentObserverWorker!=undefined) {
            this.ContentObserverWorker?.postMessageWithSharedSendable(object);
            this.ContentObserverWorker?.terminate();
          }

          if(ContentObserverWorker.BackupWorkerInstance_public!=undefined) {
            let object5: SendableObject = new SendableObject("stopWork", this.sendableCtx)
            ContentObserverWorker.BackupWorkerInstance_public?.postMessageWithSharedSendable(object5);
            ContentObserverWorker.BackupWorkerInstance_public?.terminate();
          }
          result.success(true);
        }
        break;
      case "isEnabled":
        if(this.sendableCtx == undefined) {
          result.error("sendableCtx","sendableCtx is underfined",null);
          return;
        }

        if(ContentObserverWorker.BackupWorkerInstance_public==undefined) {
          result.success(false);
          return;
        }

        let object: SendableObject = new SendableObject("isEnabled", this.sendableCtx)


        ContentObserverWorker.BackupWorkerInstance_public!.onmessage = (e: MessageEvents): void => {
          // 接收Worker子线程的结果
          let contentObserverMessage = e.data as string;
          switch(contentObserverMessage) {
            case "contentObserver_is_enabled" :
              return result.success(true);
              break;
            case "contentObserver_is_disabled" :
              return result.success(false);
          }
        }

        ContentObserverWorker.BackupWorkerInstance_public?.postMessageWithSharedSendable(object)

        break;
      case "isIgnoringBatteryOptimizations":
        result.success(true);
        //result.success(BackupWorker.isIgnoringBatteryOptimizations(ctx));
        break;
      case "digestFiles":
        const args2: string[] = call.args as string[];
        const digest:string = "sha1"
        const hashes: Promise<Uint8Array | null>[] = [];

        //GlobalScope.launch(Dispatchers.IO) {

        for (let i = 0; i < args2.length; i++) {
          const promise = new Promise<Uint8Array | null>((resolve) => {
            hash.hash(args2[i], digest, (err: BusinessError, digest: string) => {
              if (err) {
                console.error(`Cannot calculate digest of ${args2[i]}: ${err.message}`);
                resolve(null);
              } else {
                try {
                  const bytes: Uint8Array = this.hexStringToBytes(digest);
                  resolve(bytes);
                } catch (e) {
                  console.error(`Invalid digest format for ${args2[i]}: ${e}`);
                  resolve(null);
                }
              }
            });
          });
          hashes.push(promise);
        }

        Promise.all(hashes)
          .then((hashes) => {
            result.success(hashes);
          })
          .catch((error: BusinessError) => {
            result.error(
              'HASH_FAILURE',
              `Failed to process ${args2.length} files`,
              args2.map(() => null)
            );
          });
        break;
      case "moveToTrash" :
        const args3:Map<string, ArrayList<string>> = call.args as Map<string, ArrayList<string>>;
          //const mediaUrls:string = args3.args3.("mediaUrls");
          const mediaUrls = args3["mediaUrls"] as Array<string>;
          if (mediaUrls != undefined) {
            if (await this.requestManageMediaPermission()) {
              this.moveToTrash(mediaUrls, result)
            } else {
              result.error("PERMISSION_DENIED", "Media permission required", null);
            }
          } else {
            result.error("INVALID_NAME", "The mediaUrls is not specified.", null);
          }
        break;
      case "restoreFromTrash":
        result.notImplemented();
        // const args4:Map<string, ArrayList<string>> = call.args as Map<string, ESObject>;
        // const fileName = args4["fileName"] as string;
        // const type = args4["type"] as number;
        //
        // if (fileName != undefined && type != undefined) {
        //   if (await this.requestManageMediaPermission()) {
        //     this.restoreFromTrash(fileName, type, result)
        //   } else {
        //     result.error("PERMISSION_DENIED", "Media permission required", null);
        //   }
        // } else {
        //   result.error("INVALID_NAME", "The file name is not specified.", null)
        // }

        break;

      case "requestManageMediaPermission":
        //if (!this.hasManageMediaPermission()) {
          let requestResult = await this.requestManageMediaPermission();
          if(requestResult) {
            result.success(true);
          } else {
            result.error("Manage Media Permission", "Permission not granted","error");
          }
        break;
      default:
        result.notImplemented();
        break;
    }
  }
  // private hasManageMediaPermission(result: MethodResult
  // ): boolean {
  //   let permissions: Array<Permissions> = ['ohos.permission.READ_IMAGEVIDEO', 'ohos.permission.WRITE_IMAGEVIDEO'];
  //
  // }

  private async requestManageMediaPermission(): Promise<boolean> {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();

    if(BackgroundServicePlugin.ignoreCheck) {
      return true;
    }
    let permissions: Array<Permissions> = ['ohos.permission.READ_IMAGEVIDEO', 'ohos.permission.WRITE_IMAGEVIDEO'];
    await atManager.requestPermissionsFromUser(this.uiContext, permissions, (err: BusinessError, data: PermissionRequestResult) => {
      if (permissions.length == 0 || BackgroundServicePlugin.ignoreCheck) {
        // result.error('101', 'permissions is empty', 'make sure you pass the permissions');
        return true;
      }

      if (err) {
        console.error(`requestPermissionsFromUser fail, err->${JSON.stringify(err)}`);
        return false;
      } else {
        let grantStatus: Array<number> = data.authResults;
        let length: number = grantStatus.length;
        for (let i = 0; i < length; i++) {
          if (grantStatus[i] != 0) {
            return false;
          }
        }
        return true;
      }
    })

    return false;
  }

  private async moveToTrash(mediaUrls: Array<string>, result: MethodResult) {
    let urisToTrash:Array<string> =  mediaUrls;

    if (urisToTrash.length==0) {
      result.error("INVALID_ARGS", "No valid URIs provided", null)
      return
    }

    await this.toggleTrash(urisToTrash, true, result);
  }

  // private async restoreFromTrash(name: string, type: number, result: MethodResult) {
  //   let uri = await this.getTrashedFileUri(name, type)
  //   if (uri=="") {
  //     console.error("TrashError", "Asset Uri cannot be found obtained")
  //     result.error("TrashError", "Asset Uri cannot be found obtained", null)
  //     return
  //   }
  //   console.error("FILE_URI", uri.toString());
  //
  //   let uri_list:Array<string> = [uri]
  //   if (uri != undefined) {
  //     this.toggleTrash(uri_list, false, result);
  //   }
  // }

  private async toggleTrash(contentUris: Array<string>, isTrashed: Boolean, result: MethodResult) {
    let activity = this.activityBinding?.getAbility();
    let contentResolver = this.uiContext;
    if (activity == undefined || contentResolver == undefined) {
      result.error("TrashError", "Activity or ContentResolver not available", null)
      return
    }

    try {
      let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.uiContext);
      await photoAccessHelper.MediaAssetChangeRequest.deleteAssets(this.uiContext, contentUris)
      result.success({});

    } catch (e) {
      console.error("TrashError", "Error creating or starting trash request", e);
      result.error("TrashError", "Error creating or starting trash request", e)
    }
  }

  private async getTrashedFileUri(fileName: string, type: number): Promise<string> {
    let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.uiContext);
    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo(photoAccessHelper.PhotoKeys.DISPLAY_NAME, fileName);
    let fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: predicates
    };

    try {
      let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
      let photoAsset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject();
      console.info('getAssets photoAsset.displayName : ' + photoAsset.displayName);
      let queryUri = photoAsset.uri;
      fetchResult.close();
      return queryUri;
    } catch (err) {
      console.error('getAssets failed with err: ' + err);
      return "";
    }
}

  getUniqueClassName(): string {
    return "BackgroundServicePlugin"
  }

  onAttachedToAbility(binding: AbilityPluginBinding) {
    this.activityBinding = binding;
    this.uiContext = binding.getAbility().context;
    this.sendableCtx = sendableContextManager.convertFromContext(this.uiContext);
  }

  onDetachedFromAbility() {
    //activityBinding?.removeActivityResultListener(this)
    this.activityBinding = undefined;
  }

  hexStringToBytes(hex: string): Uint8Array {
    const bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < hex.length; i += 2) {
      bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
    }
    return bytes;
  }
}
