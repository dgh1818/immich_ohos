import { workScheduler, WorkSchedulerExtensionAbility } from "@kit.BackgroundTasksKit";
import {BackupWorker} from "./BackupWorkerImpl"
import { ThreadWorkerGlobalScope, worker } from "@kit.ArkTS";
import { common, sendableContextManager } from '@kit.AbilityKit';
import { SendableObject } from "../plugins/BackgroundServicePlugin";

export class ContentObserverWorkerTask extends WorkSchedulerExtensionAbility {
  public ContentObserverWorkclass?: BackupWorker
  public ContentObserverWorker?:worker.ThreadWorker
  private context_input?: sendableContextManager.SendableContext;
  public ui_context?:common.UIAbilityContext

  // 延迟任务开始回调
  onWorkStart(workInfo: workScheduler.WorkInfo) {
    //上架屏蔽
    // this.ContentObserverWorker = new worker.ThreadWorker('../workers/ContentObserverWorker');
    // this.context_input = AppStorage.get<sendableContextManager.SendableContext>('UIsendablecontext');
    //
    // if(this.context_input==undefined) {
    //   console.error("AppStorage SendableContext is underfined")
    //   return;
    // }
    //
    // this.ui_context = sendableContextManager.convertToUIAbilityContext(this.context_input);
    // let object1: SendableObject = new SendableObject("doWork", this.context_input)
    // this.ContentObserverWorker.postMessageWithSharedSendable(object1);
    //
    // console.info(`onWorkStart, workInfo = ${JSON.stringify(workInfo)}`);
  }

  // 延迟任务结束回调。当延迟任务2分钟超时或应用调用stopWork接口取消任务时，触发该回调。
  onWorkStop(workInfo: workScheduler.WorkInfo) {
    this.ContentObserverWorkclass= undefined;
    this.ui_context = undefined;
    this.ContentObserverWorker?.terminate();
    this.ContentObserverWorker = undefined;
    this.context_input = undefined;

    console.info(`onWorkStop, workInfo is ${JSON.stringify(workInfo)}`);
  }


}
