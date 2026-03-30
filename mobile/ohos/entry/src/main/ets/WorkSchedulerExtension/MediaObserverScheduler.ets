import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';

export class MediaObserverScheduler extends WorkSchedulerExtensionAbility {
  private ctx: common.ApplicationContext = this.context.getApplicationContext();

  public static enqueueBackgroundWorker() {
    const constraints: workScheduler.WorkInfo = BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO;
    BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO = constraints;
    workScheduler.startWork(constraints);
    console.info("MediaObserverScheduler", "Enqueued background worker");
  }

  async onWorkStart(workInfo: workScheduler.WorkInfo) {
    try {
      MediaObserverScheduler.enqueueBackgroundWorker();
    } catch (e) {
      console.error("MediaObserverScheduler.enqueueBackgroundWorker error", e);
    }
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx);
  }
}
