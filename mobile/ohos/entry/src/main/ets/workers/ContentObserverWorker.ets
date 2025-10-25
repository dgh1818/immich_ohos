import { ContentObserverWorker } from './ContentObserverWorkerImpl';
import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { SendableObject } from '../plugins/BackgroundServicePlugin';
import { sendableContextManager } from '@kit.AbilityKit';
import dataPreferences from '@ohos.data.preferences'
import { BackupWorker } from './BackupWorkerImpl';
import { photoAccessHelper } from '@kit.MediaLibraryKit';


let ContentObserverWorkerClass:ContentObserverWorker;
const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

workerPort.onmessage = (event: MessageEvents) => {
   //上架屏蔽
  let input: SendableObject = event.data;
  if(input.command == undefined) {
    return;
  }
  let command: string = input.command;
  ContentObserverWorkerClass.context_input = input.sendableContext;
  ContentObserverWorkerClass.ui_context = sendableContextManager.convertToUIAbilityContext(ContentObserverWorkerClass.context_input);

  switch (command) {
    case "doWork":
      ContentObserverWorkerClass = new ContentObserverWorker();
      ContentObserverWorkerClass.context_input = input.sendableContext;
      ContentObserverWorkerClass.ui_context = sendableContextManager.convertToUIAbilityContext(ContentObserverWorkerClass.context_input);

      if (ContentObserverWorkerClass.triggeredContentUris.length > 0) {
        ContentObserverWorkerClass.startBackupWorker(ContentObserverWorkerClass.ui_context, 0);
      }

      ContentObserverWorkerClass.enqueueObserverWorker(ContentObserverWorkerClass.ui_context);
      break;
    case "enable":
      let immediate = input.immediate ?? false;
      ContentObserverWorkerClass.enqueueObserverWorker(ContentObserverWorkerClass.ui_context);
      console.info(ContentObserverWorkerClass.TAG, "enabled ContentObserverWorker")
      if (immediate) {
        ContentObserverWorkerClass.startBackupWorker(ContentObserverWorkerClass.ui_context, 5000)
      }
      break;

    case "configureWork":
      let requireWifi = input.requireWifi ?? false;
      let requireCharging = input.requireCharging ?? false;
      let triggerUpdateDelay = input.triggerUpdateDelay ?? 5000;
      let triggerMaxDelay = input.triggerMaxDelay ?? 5000;

      dataPreferences.getPreferences(ContentObserverWorkerClass.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
        if (err) {
          console.error('获取Preferences实例失败:', err)
          return
        }

        if (ContentObserverWorkerClass.context_input == undefined) {
          return;
        }

        sp.putSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, true);
        sp.putSync(ContentObserverWorker.SHARED_PREF_REQUIRE_WIFI, requireWifi);
        sp.putSync(ContentObserverWorker.SHARED_PREF_REQUIRE_CHARGING, requireCharging);
        sp.putSync(ContentObserverWorker.SHARED_PREF_TRIGGER_UPDATE_DELAY, triggerUpdateDelay);
        sp.putSync(ContentObserverWorker.SHARED_PREF_TRIGGER_MAX_DELAY, triggerMaxDelay);
        sp.flushSync();
        let object2: SendableObject =
          new SendableObject("updateBackupWorker", ContentObserverWorkerClass.context_input, undefined, requireWifi, requireCharging);
        ContentObserverWorkerClass.BackupWorkerInstance?.postMessageWithSharedSendable(object2);
      })
      break;

    case "disable":
      dataPreferences.getPreferences(ContentObserverWorkerClass.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
        if (err) {
          console.error('获取Preferences实例失败:', err)
          return
        }

        if (ContentObserverWorkerClass.context_input == undefined) {
          return;
        }

        sp.putSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, false);
        sp.flushSync();
        if (ContentObserverWorkerClass.phAccessHelper == undefined) {
          return;
        }
        console.info(ContentObserverWorkerClass.TAG,"disabled ContentObserverWorker");
        ContentObserverWorkerClass.phAccessHelper.unRegisterChange(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI);
        //ContentObserverWorkerClass = undefined;
      })
      break;

    case "isEnabled":
      dataPreferences.getPreferences(ContentObserverWorkerClass.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {
        let result = sp.getSync(ContentObserverWorker.SHARED_PREF_SERVICE_ENABLED, false) as boolean
        if(result) {
          ContentObserverWorkerClass.workerPort.postMessage("contentObserver_is_enabled");
        } else {
          ContentObserverWorkerClass.workerPort.postMessage("contentObserver_is_disabled");
        }
      });
      break;
    case "workManagerAppClearedWorkaround":
      if (ContentObserverWorkerClass.phAccessHelper == undefined) {
        return;
      }

      // ContentObserverWorkerClass.ContentObserverWorker = new worker.ThreadWorker('../workers/ContentObserverWorker');
      // let object: SendableObject = new SendableObject("doWork", ContentObserverWorkerClass.context_input!);
      // ContentObserverWorkerClass.ContentObserverWorker.postMessageWithSharedSendable(object);

      //backgroundTaskManager.startBackgroundRunning(ContentObserverWorkerClass.ui_context,)
      break;
    case "startBackupWorker":
      ContentObserverWorkerClass.startBackupWorker(ContentObserverWorkerClass.ui_context!, 5000);
      break;

  }
};
