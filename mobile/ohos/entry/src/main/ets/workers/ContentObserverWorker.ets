import { ArrayList, ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { SendableObject } from '../plugins/BackgroundServicePlugin';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates, preferences } from '@kit.ArkData';
import dataPreferences from '@ohos.data.preferences'
import { BusinessError } from '@kit.BasicServicesKit';
import { process } from '@kit.ArkTS';
import { AbilityAware, FlutterPlugin, MethodCallHandler } from '@ohos/flutter_ohos';
import { BackupWorker } from './BackupWorker';
import { backgroundTaskManager, workScheduler } from '@kit.BackgroundTasksKit';

interface WorkerMessage {
  command: string;
  payload?: ESObject;
}

export class ContentObserverWorker{
  constructor() {

    this.workerPort.onmessage = (event: MessageEvents) => {
      let input: SendableObject = event.data;
      let command: string = input.command;
      this.context_input = input.sendableContext;
      this.ui_context = sendableContextManager.convertToUIAbilityContext(this.context_input);

      switch (command) {
        case "doWork":
          this.context_input = input.sendableContext;
          this.ui_context = sendableContextManager.convertToUIAbilityContext(this.context_input);

          if (this.triggeredContentUris.length > 0) {
            this.startBackupWorker(this.ui_context, 0);
          }

          this.enqueueObserverWorker(this.ui_context);
          break;
        case "enable":
          let immediate = input.immediate ?? false;
          this.enqueueObserverWorker(this.ui_context);
          console.info(this.TAG, "enabled ContentObserverWorker")
          if (immediate) {
            this.startBackupWorker(this.ui_context, 5000)
          }
          break;

        case "configureWork":
          let requireWifi = input.requireWifi ?? false;
          let requireCharging = input.requireCharging ?? false;
          let triggerUpdateDelay = input.triggerUpdateDelay ?? 5000;
          let triggerMaxDelay = input.triggerMaxDelay ?? 5000;

          dataPreferences.getPreferences(this.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
            if (err) {
              console.error('获取Preferences实例失败:', err)
              return
            }

            if (this.context_input == undefined) {
              return;
            }

            sp.putSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, true);
            sp.putSync(ContentObserverWorker.SHARED_PREF_REQUIRE_WIFI, requireWifi);
            sp.putSync(ContentObserverWorker.SHARED_PREF_REQUIRE_CHARGING, requireCharging);
            sp.putSync(ContentObserverWorker.SHARED_PREF_TRIGGER_UPDATE_DELAY, triggerUpdateDelay);
            sp.putSync(ContentObserverWorker.SHARED_PREF_TRIGGER_MAX_DELAY, triggerMaxDelay);
            sp.flushSync();
            let object2: SendableObject =
              new SendableObject("updateBackupWorker", this.context_input, undefined, requireWifi, requireCharging);
            this.BackupWorkerInstance?.postMessageWithSharedSendable(object2);
          })
          break;

        case "disable":
          dataPreferences.getPreferences(this.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
            if (err) {
              console.error('获取Preferences实例失败:', err)
              return
            }

            if (this.context_input == undefined) {
              return;
            }

            sp.putSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, false);
            sp.flushSync();
            if (this.phAccessHelper == undefined) {
              return;
            }
            console.info(this.TAG,"disabled ContentObserverWorker");
            this.phAccessHelper.unRegisterChange(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI);
            ContentObserverWorkerClass = undefined;
          })
         break;

        case "isEnabled":
          dataPreferences.getPreferences(this.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
            let result = sp.getSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, false) as boolean
            if(result) {
              this.workerPort.postMessage("contentObserver_is_enabled");
            } else {
              this.workerPort.postMessage("contentObserver_is_disabled");
            }
          });
          break;
        case "workManagerAppClearedWorkaround":
          if (this.phAccessHelper == undefined) {
            return;
          }

          this.ContentObserverWorker = new worker.ThreadWorker('../workers/ContentObserverWorker');
          let object: SendableObject = new SendableObject("doWork", this.context_input!);
          this.ContentObserverWorker.postMessageWithSharedSendable(object);

          //backgroundTaskManager.startBackgroundRunning(this.ui_context,)
          break;
        case "startBackupWorker":
          this.startBackupWorker(this.ui_context!, 5000);
          break;
      }

    };
    let object: SendableObject = new SendableObject("doWork", this.context_input!);
  };

  private workerPort: ThreadWorkerGlobalScope = worker.workerPort;
  //workerPort.postMessage("doWork");
  private ui_context?: common.UIAbilityContext;
  private triggeredContentUris: string[] = [];
  private context_input?: sendableContextManager.SendableContext;
  private BackupWorkerInstance?: worker.ThreadWorker;
  public static BackupWorkerInstance_public?: worker.ThreadWorker;
  private phAccessHelper?: photoAccessHelper.PhotoAccessHelper;
  private TAG = "ContentObserverWorker";

  private ContentObserverWorker?: worker.ThreadWorker;

  static readonly SHARED_PREF_SERVICE_ENABLED = "serviceEnabled"
  static readonly SHARED_PREF_REQUIRE_WIFI = "requireWifi"
  static readonly SHARED_PREF_REQUIRE_CHARGING = "requireCharging"
  static readonly SHARED_PREF_TRIGGER_UPDATE_DELAY = "triggerUpdateDelay"
  static readonly SHARED_PREF_TRIGGER_MAX_DELAY = "triggerMaxDelay"

  static readonly TASK_NAME_OBSERVER = "immich/ContentObserver"

  private async startBackupWorker(context: common.UIAbilityContext, delayMilliseconds: number) {
    dataPreferences.getPreferences(context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
      if (err) {
        console.error('获取Preferences实例失败:', err)
        return
      }
      let sharedPrefServiceEnabled = sp.getSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, false) as boolean;

      if (!sharedPrefServiceEnabled) {
        return;
      }

      let requireWifi = sp.getSync(ContentObserverWorker.SHARED_PREF_REQUIRE_WIFI, true) as boolean;
      let requireCharging = sp.getSync(ContentObserverWorker.SHARED_PREF_REQUIRE_CHARGING, false) as boolean;

      if (this.context_input == undefined) {
        return;
      }

      PersistentStorage.persistProp('UIsendablecontext', this.context_input);

      let constraints:workScheduler.WorkInfo = {
        workId:BackupWorker.TASK_NAME_BACKUP_ID,
        bundleName:'com.dgh18.immich',
        abilityName:'BackupWorkerTask',
        networkType: requireWifi? workScheduler.NetworkType.NETWORK_TYPE_WIFI:workScheduler.NetworkType.NETWORK_TYPE_ANY,
        isCharging:requireCharging,
        parameters:{
          needQueueBackupWorker:true,
        }
      }

      workScheduler.startWork(constraints);

      sp.putSync(BackupWorker.SHARED_PREF_LAST_CHANGE, process.uptime() * 1000);
      sp.flush();
    })
  }

  private async enqueueObserverWorker(context: common.UIAbilityContext) {
    this.phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    let albumName: photoAccessHelper.AlbumKeys = photoAccessHelper.AlbumKeys.ALBUM_NAME;
    predicates.equalTo(albumName, 'albumName');
    let fetchOptions: photoAccessHelper.FetchOptions = {
      fetchColumns: [],
      predicates: predicates
    };

    try {
      let onCallback = (changeData: photoAccessHelper.ChangeData) => {
        console.info('onCallback successfully, changData: ' + JSON.stringify(changeData));
        //let fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> = await phAccessHelper.getAssets(fetchOptions);
        //let photoAsset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject();
        //console.info('getAssets photoAsset.uri : ' + photoAsset.uri);
        this.triggeredContentUris = changeData.extraUris;
        this.phAccessHelper!.unRegisterChange(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI);
        this.ContentObserverWorker = new worker.ThreadWorker('../workers/ContentObserverWorker');
        let object: SendableObject = new SendableObject("doWork", this.context_input!);
        this.ContentObserverWorker.postMessageWithSharedSendable(object);
        //待完善
        // PersistentStorage.persistProp('UIsendablecontext', this.context_input);
        //
        // let constraints:workScheduler.WorkInfo = {
        //   workId:BackupWorker.TASK_NAME_BACKUP_ID,
        //   bundleName:'com.dgh18.immich',
        //   abilityName:'BackupWorkerTask',
        //   networkType: requireWifi? workScheduler.NetworkType.NETWORK_TYPE_WIFI:workScheduler.NetworkType.NETWORK_TYPE_ANY,
        //   isCharging:requireCharging,
        //   parameters:{
        //     needQueueBackupWorker:true,
        //   }
        //}

        //workScheduler.startWork(constraints);
      }

      this.phAccessHelper!.registerChange(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI, true, onCallback);
    } catch (err) {
      console.error('onCallback failed with err: ' + err);
    }
  }
}

let ContentObserverWorkerClass:ContentObserverWorker|undefined = new ContentObserverWorker();
