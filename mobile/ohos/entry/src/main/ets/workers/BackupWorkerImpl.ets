import { ArrayList, ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { SendableObject } from '../plugins/BackgroundServicePlugin';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { FlutterEngine, MethodCall, MethodChannel, MethodResult,FlutterLoader,
  MethodCallHandler,
  FlutterPluginBinding,
  FlutterCallbackInformation,
  DartExecutor,
  //DartCallback,
  FlutterShellArgs,
  } from '@ohos/flutter_ohos';

import { notificationManager } from '@kit.NotificationKit';
import dataPreferences from '@ohos.data.preferences'
import { BusinessError } from '@kit.BasicServicesKit';
import { process } from '@kit.ArkTS';
import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';

export class BackupWorker implements MethodCallHandler {
  public readonly TAG = "BackupWorker"

  public  resolvableFuture = new ResolvablePromise<ResultCode>();
  public engine?: FlutterEngine;
  public backgroundChannel?: MethodChannel;
  // private notificationManager = notificationManager; //ohos直接调用
  public isIgnoringBatteryOptimizations = true;
  //private isIgnoringBatteryOptimizations = isIgnoringBatteryOptimizations(applicationContext)
  public timeBackupStarted: number = 0;
  public notificationBuilder?: notificationManager.NotificationRequest;
  public notificationDetailBuilder?: notificationManager.NotificationRequest;
  public fgFuture?: Promise<void>;

  constructor() {

  }

  public runDart() {
    dataPreferences.getPreferences(this.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
      let callbackDispatcherHandle = sp.getSync("SHARED_PREF_CALLBACK_KEY",0) as number;
      let callbackInformation = FlutterCallbackInformation.lookupCallbackInformation(callbackDispatcherHandle);
      let appBundlePath = this.flutterLoader?.findAppBundlePath();
      //this.engine.
      if(this.engine) {
        this.backgroundChannel = new MethodChannel(this.engine.dartExecutor, "immich/backgroundChannel");
        this.backgroundChannel.setMethodCallHandler(this);

        // dartCallback:DartCallback
        // this.engine.dartExecutor.executeDartCallback(
        //   new DartCallback(
        //     this.ui_context?.resourceManager,
        //     appBundlePath,
        //     callbackInformation
        //   )
        // ); //修改了index.ets
      }
    });
  };

  public waitOnSetForegroundAsync() {
    let fgFuture = this.fgFuture
    let finished = false;

    let timer = setTimeout(() => {
      if (!finished) {
        console.warn("fgFuture timeout after 500ms");
        return;
        // 超时逻辑，可能标记错误状态或取消任务
      }
    }, 500);

    fgFuture?.then(() => {
      if (!finished) {
        finished = true;
        clearTimeout(timer);
        console.log("fgFuture resolved in time");
      }
    }).catch((e:BusinessError) => {
      if (!finished) {
        finished = true;
        clearTimeout(timer);
        console.log("fgFuture failed before timeout");
      }
    });
  }

  public async ensureInitializationCompleteAsync(ctx:common.UIAbilityContext,appBundlePath?:string) {
    const flutterShellArgs = new FlutterShellArgs();
    this.flutterLoader?.ensureInitializationComplete(flutterShellArgs.toArray() ?? []);

    return;
  }

  public stopEngine(result: ResultCode) {
    this.clearBackgroundNotification();
    this.engine?.destroy();
    this.engine = undefined;
    if (result) {
      console.info(`stopEngine result=${result}`);

      this.resolvableFuture?.resolve(result);
      //MethodChannel.Result

    }
    this.waitOnSetForegroundAsync()
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case "initialized" :
        this.timeBackupStarted = process.uptime() * 1000;

        this.backgroundChannel?.invokeMethod("onAssetsChanged",null,
          {
            notImplemented: () => {
              this.stopEngine(ResultCode.FAILURE);
            },
            error: (errorCode: string, errorMessage?: string, errorDetails?: ESObject) => {
              this.stopEngine(ResultCode.FAILURE);

            },
            success: (receivedResult: ESObject) => {
              const success = receivedResult as boolean;
              this.stopEngine(success ? ResultCode.SUCCESS : ResultCode.RETRY);
            }
          }
        );
        break;
      case "updateNotification" :
        let args:ArrayList<ESObject> = call.args as ArrayList<ESObject>;
        let title = args[0] as string
        let content = args[1] as string
        let progress = args[2] as number
        let max = args[3] as number
        let indeterminate = args[4] as boolean
        let isDetail = args[5] as boolean
        let onlyIfFG = args[6] as boolean

        //if (!onlyIfFG || isIgnoringBatteryOptimizations) {
        if (!onlyIfFG) {
          this.showInfo(
            this.getInfoBuilder(title, content, isDetail, progress, max, indeterminate),
            isDetail
          );
        }
        break;
      case "showError":
        let args2:ArrayList<ESObject> = call.args as ArrayList<ESObject>;
        let title2 = args2[0] as string
        let content2 = args2[1] as string
        let individualTag = args2[2] as string
        this.showError(title2, content2, individualTag);
        break;
      case "clearErrorNotifications":
        this.clearErrorNotifications();
        break;
      case "hasContentChanged":
        dataPreferences.getPreferences(this.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
          let lastChange = sp.getSync(BackupWorker.SHARED_PREF_LAST_CHANGE, this.timeBackupStarted)
          let hasContentChanged = lastChange > this.timeBackupStarted;
          this.timeBackupStarted = process.uptime() * 1000;
          result.success(hasContentChanged);
        });
        break;
      default:
        result.notImplemented();
    }
  }

  public showError(title: string, content?: string, individualTag?: string) {
    let notification:notificationManager.NotificationRequest = {
      id: BackupWorker.NOTIFICATION_ERROR_ID,
      content: {

        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
        normal: {
          title: title,
          text: content??'',
          //additionalText: 'test_additionalText',
        },
      },
      template: {
        name: 'downloadTemplate',
        data: { title: title, fileName: '', progressValue: 0 }
      },
      notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
      smallIcon: this.icon?.getPixelMap(),
    };
  }

  public clearErrorNotifications() {
    notificationManager.cancel(BackupWorker.NOTIFICATION_ERROR_ID);
  }

  public  clearBackgroundNotification() {
    notificationManager.cancel(BackupWorker.NOTIFICATION_ID);
    notificationManager.cancel(BackupWorker.NOTIFICATION_DETAIL_ID);
  }

  public  showInfo(notification: notificationManager.NotificationRequest, isDetail: Boolean = false) {
    let id = isDetail ? BackupWorker.NOTIFICATION_DETAIL_ID : BackupWorker.NOTIFICATION_ID

    //if (isIgnoringBatteryOptimizations && !isDetail) {
    if (!isDetail) {
      notificationManager.publish(notification);
      this.fgFuture=Promise.resolve();
    } else {
      notificationManager.publish(notification);
    }
  }

  public getInfoBuilder(
    title?:string,
    content?: string,
    isDetail: boolean = false,
    progress: number = 0,
    max: number = 0,
    indeterminate: boolean = false
  ): notificationManager.NotificationRequest {
    let builder = isDetail? this.notificationDetailBuilder : this.notificationBuilder

    if (builder == undefined) {
      builder = {
        id: this.NOTIFICATION_CHANNEL_ID,
        content: {

          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
          normal: {
            title: '',
            text: '',
            //additionalText: 'test_additionalText',
          },
        },
        template: {
          name: 'downloadTemplate',
          data: { title: '', fileName: '', progressValue: 0 }
        },
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        smallIcon: this.icon?.getPixelMap(),
        isAlertOnce: true,
        isOngoing: true,
      };
      if (isDetail) {
        this.notificationDetailBuilder = builder
      } else {
        this.notificationBuilder = builder
      }
    }
    if (title != undefined) {
      builder = {
        updateOnly: true,
        id: this.NOTIFICATION_CHANNEL_ID,
        content:{

          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
          normal: {
            title: title!,
            text: "",
            //additionalText: 'test_additionalText',
          },
        },
        template: {
          name: 'downloadTemplate',
          data: { title: title!, fileName: '', progressValue: progress }
        },
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        smallIcon: this.icon?.getPixelMap(),
        isAlertOnce:true,
        isOngoing:true,
      };
    }

    if (content != undefined) {
      builder = {
        updateOnly: true,
        id: this.NOTIFICATION_CHANNEL_ID,
        content:{

          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
          normal: {
            title: title!,
            text: content,
            //additionalText: 'test_additionalText',
          },
        },
        template: {
          name: 'downloadTemplate',
          data: { title: title!, fileName: '', progressValue: progress }
        },
        notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
        smallIcon: this.icon?.getPixelMap(),
        isAlertOnce:true,
        isOngoing:true,
      };
    }
    return builder;
  }

  // private async createChannel(title:string) {
  //   this.foreground = {
  //     id: this.NOTIFICATION_CHANNEL_ID,
  //     //groupName: this.NOTIFICATION_CHANNEL_name,
  //     content: {
  //       notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
  //       normal: {
  //         title: title!,
  //         text: 'test_text',
  //         additionalText: 'test_additionalText',
  //       }
  //     },
  //     notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION
  //   };
  //
  //   this.error = {
  //     id: this.NOTIFICATION_CHANNEL_ERROR_ID,
  //     //groupName: this.NOTIFICATION_CHANNEL_name,
  //     content: {
  //       notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
  //       normal: {
  //         title: 'test_title',
  //         text: 'test_text',
  //         additionalText: 'test_additionalText',
  //       }
  //     },
  //     notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
  //   };
  // }

  public buildWorkRequest(
  requireWifi: boolean = false,
  requireCharging: boolean = false,
  delayMilliseconds: number = 0
  ): workScheduler.WorkInfo {

    let constraints:workScheduler.WorkInfo = {
      workId:BackupWorker.TASK_NAME_BACKUP_ID,
      bundleName:'com.dgh18.immich',
      abilityName:'BackupWorkerTask',
      networkType: requireWifi? workScheduler.NetworkType.NETWORK_TYPE_WIFI:workScheduler.NetworkType.NETWORK_TYPE_ANY,
      batteryStatus:workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
      isCharging:requireCharging,
    }

    return constraints;
}
  public  ui_context?: common.UIAbilityContext
  public context_input?: sendableContextManager.SendableContext;

  public backupWorkInfo?:workScheduler.WorkInfo;
  public flutterLoader?:FlutterLoader;
  public NOTIFICATION_CHANNEL_ID:number = 1;
  public NOTIFICATION_CHANNEL_name = "immich/backgroundService"
  public foreground?: notificationManager.NotificationRequest
  public error?:notificationManager.NotificationRequest
  public NOTIFICATION_CHANNEL_ERROR_ID:number = 2;
  public methodChannel?: MethodChannel = undefined;
;
  static readonly SHARED_PREF_NAME = "immichBackgroundService";
  static readonly SHARED_PREF_CALLBACK_KEY = "callbackDispatcherHandle";
  static readonly SHARED_PREF_NOTIFICATION_TITLE = "notificationTitle";
  static readonly SHARED_PREF_LAST_CHANGE = "lastChange";
  //
  static readonly TASK_NAME_BACKUP = "immich/BackupWorker"
  static readonly TASK_NAME_BACKUP_ID = 10010;
  static readonly NOTIFICATION_CHANNEL_ID = "immich/backgroundService"
  static readonly NOTIFICATION_CHANNEL_ERROR_ID = "immich/backgroundServiceError"
  static readonly NOTIFICATION_DEFAULT_TITLE = "Immich"
  static readonly NOTIFICATION_ID = 1
  static readonly NOTIFICATION_ERROR_ID = 2
  static readonly NOTIFICATION_DETAIL_ID = 3
  static readonly ONE_MINUTE = 60000;
  private notification_content?:notificationManager.NotificationProgress;
  private icon?:DrawableDescriptor = this.ui_context?.resourceManager.getDrawableDescriptor($r('app.media.icon').id);

  private workerPort: ThreadWorkerGlobalScope = worker.workerPort;
  //private BackupWorkerClass?:BackupWorker;

  onAttachedToEngine(binding: FlutterPluginBinding): void {

    //this.BackupWorkerClass = new BackupWorker();
    this.flutterLoader = binding?.getFlutterEngine().getFlutterLoader();
    //context = ctx;
    this.methodChannel = new MethodChannel(binding.getBinaryMessenger(), "immich/foregroundChannel");
    this.methodChannel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.methodChannel?.setMethodCallHandler(undefined);
    this.methodChannel = undefined;
  }
}

class ResolvablePromise<T> {
  promise: Promise<T>;
  resolve!: (v: T) => void;
  reject!: (e?: ESObject) => void;

  constructor() {
    this.promise = new Promise<T>((res, rej) => {
      this.resolve = res;
      this.reject = rej;
    });
  }
}

export enum ResultCode {
  SUCCESS = "success",
  FAILURE = "failure",
  RETRY   = "retry",
}







