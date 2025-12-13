import { workScheduler, WorkSchedulerExtensionAbility } from "@kit.BackgroundTasksKit";
import {BackupWorker} from "../workers/BackupWorkerImpl"
import { ThreadWorkerGlobalScope, worker } from "@kit.ArkTS";
import { common, sendableContextManager } from '@kit.AbilityKit';
import { SendableObject } from "../plugins/BackgroundServicePlugin";

export class BackupWorkerTask extends WorkSchedulerExtensionAbility {
  public backupWorkclass?: BackupWorker
  public BackupWorker?:worker.ThreadWorker
  private context_input?: sendableContextManager.SendableContext;
  public ui_context?:common.UIAbilityContext

  // 延迟任务开始回调
  onWorkStart(workInfo: workScheduler.WorkInfo) {
    this.BackupWorker = new worker.ThreadWorker('../workers/BackupWorker');
    this.context_input = AppStorage.get<sendableContextManager.SendableContext>('UIsendablecontext');

    if(this.context_input==undefined) {
      console.error("AppStorage SendableContext is underfined")
      return;
    }

    this.ui_context = sendableContextManager.convertToUIAbilityContext(this.context_input);
    let object1: SendableObject = new SendableObject("startWork", this.context_input)
    this.BackupWorker.postMessageWithSharedSendable(object1);

    if(workInfo.parameters!=undefined) {
      if(workInfo.parameters["needQueueBackupWorker"] as boolean) {
        let requireWifi = workInfo.networkType==workScheduler.NetworkType.NETWORK_TYPE_WIFI?true:false;
        let requireCharging =workInfo.isCharging?true:false;
        let object2: SendableObject =
          new SendableObject("enqueueBackupWorker", this.context_input, undefined, requireWifi, requireCharging,
            3000);
        this.BackupWorker.postMessageWithSharedSendable(object2);
      }
    }

    console.info(`onWorkStart, workInfo = ${JSON.stringify(workInfo)}`);
  }

  // 延迟任务结束回调。当延迟任务2分钟超时或应用调用stopWork接口取消任务时，触发该回调。
  onWorkStop(workInfo: workScheduler.WorkInfo) {
    this.backupWorkclass= undefined;
    this.ui_context = undefined;
    this.BackupWorker?.terminate();
    this.BackupWorker = undefined;
    this.context_input = undefined;

    console.info(`onWorkStop, workInfo is ${JSON.stringify(workInfo)}`);
  }


}
