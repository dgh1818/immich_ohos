import { BackupWorker, ResultCode } from './BackupWorkerImpl';
import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { SendableObject } from '../plugins/BackgroundServicePlugin';
import { sendableContextManager } from '@kit.AbilityKit';
import dataPreferences from '@ohos.data.preferences'
import { FlutterEngine, FlutterShellArgs } from '@ohos/flutter_ohos';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';


let BackupWorkerClass:BackupWorker;

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

workerPort.onmessage = (event: MessageEvents) => {
  let input: SendableObject = event.data;
  let command: string = input.command;
  BackupWorkerClass.ui_context = sendableContextManager.convertToUIAbilityContext(input.sendableContext);


  switch (command) {
    case "startWork":
      BackupWorkerClass = new BackupWorker();
      BackupWorkerClass.ui_context = sendableContextManager.convertToUIAbilityContext(input.sendableContext);

      if (!BackupWorkerClass.flutterLoader?.initialized) {
        BackupWorkerClass.flutterLoader?.startInitialization(BackupWorkerClass.ui_context);
      }

      // Create a Notification channel
      //BackupWorkerClass.createChannel(title);
      dataPreferences.getPreferences(BackupWorkerClass.ui_context, BackupWorker.SHARED_PREF_NAME, (err, sp) => {

        let title = sp.getSync(BackupWorker.SHARED_PREF_NOTIFICATION_TITLE, BackupWorker.NOTIFICATION_DEFAULT_TITLE) as string;

        // if (isIgnoringBatteryOptimizations) {
        //   // normal background services can only up to 10 minutes
        //   // foreground services are allowed to run indefinitely
        //   // requires battery optimizations to be disabled (either manually by the user
        //   // or by the system learning that immich is important to the user)
        //   val title = ctx.getSharedPreferences(SHARED_PREF_NAME, Context.MODE_PRIVATE)
        //     .getString(SHARED_PREF_NOTIFICATION_TITLE, NOTIFICATION_DEFAULT_TITLE)!!
        //   showInfo(getInfoBuilder(title, indeterminate = true).build())
        // }

        BackupWorkerClass.showInfo(BackupWorkerClass.getInfoBuilder(title, undefined,false,0,0,true));

        BackupWorkerClass.engine = new FlutterEngine(BackupWorkerClass.ui_context!,null,null,null);
        const flutterShellArgs = new FlutterShellArgs();

        let appBundlePath = BackupWorkerClass.flutterLoader?.findAppBundlePath();
        BackupWorkerClass.ensureInitializationCompleteAsync(BackupWorkerClass.ui_context!,appBundlePath).then(()=>{
          BackupWorkerClass.runDart();
        })
      });

      //return BackupWorkerClass.resolvableFuture; //待完善
      break;

    case "onStopped":
      console.info(BackupWorkerClass.TAG,"onStopped");
      // called when the system has to stop BackupWorkerClass worker because constraints are
      // no longer met or the system needs resources for more important tasks

      Promise.resolve().then(() => {
        if (BackupWorkerClass.backgroundChannel) {
          BackupWorkerClass.backgroundChannel.invokeMethod("systemStop", undefined);
        }
        BackupWorkerClass.waitOnSetForegroundAsync();

        setTimeout(() => {
          // 这里的 BackupWorkerClass 就是你的类实例
          BackupWorkerClass.stopEngine(ResultCode.SUCCESS);
          //BackupWorkerClass.BackupWorkerClass = undefined;
        }, 5000);
      });
      break;

    case "enqueueBackupWorker":
      let requireWifi = input.requireWifi;
      let requireCharging = input.requireCharging;
      let delayMilliseconds = input.triggerUpdateDelay;
      BackupWorkerClass.backupWorkInfo = BackupWorkerClass.buildWorkRequest(requireWifi, requireCharging, delayMilliseconds)
      workScheduler.startWork(BackupWorkerClass.backupWorkInfo);
      break;

    case "updateBackupWorker":
      let context = BackupWorkerClass.ui_context;
      let requireWifi2: boolean = false;
      let requireCharging2: boolean = false

      //let workInfoFuture = workScheduler.getWorkStatus(BackupWorker.TASK_NAME_BACKUP_ID);

      try{
        workScheduler.obtainAllWorks((error: BusinessError, workInfoList: Array<workScheduler.WorkInfo>) =>{
          if (error) {
            console.error(`workschedulerLog obtainAllWorks failed. code is ${error.code} message is ${error.message}`);

          } else {
            if(!workInfoList==undefined) {
              for (const workInfo of workInfoList) {
                let workRequest = BackupWorkerClass.buildWorkRequest(requireWifi, requireCharging)
                workScheduler.stopWork(workInfo); // 先停止原来的
                workScheduler.startWork(workRequest);
                console.info(BackupWorkerClass.TAG, "updateBackupWorker updated BackupWorker constraints");

                return;
              }
            }
            console.info(BackupWorkerClass.TAG, "updateBackupWorker: BackupWorker not enqueued");
          }
        });
      } catch(error) {
        console.error('updateBackupWorker failed:', error);
      }
      break;

    case "stopWork":
      workScheduler.stopWork(BackupWorkerClass.backupWorkInfo); // 先停止原来的
      console.info(BackupWorkerClass.TAG, 'stopWork: BackupWorker cancelled');
      break;

    case "isIgnoringBatteryOptimizations":
      break;
  }
};
