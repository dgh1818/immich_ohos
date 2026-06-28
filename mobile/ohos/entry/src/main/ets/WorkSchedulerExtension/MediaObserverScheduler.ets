import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';

export class MediaObserverScheduler extends WorkSchedulerExtensionAbility {
  private ctx: common.ApplicationContext = this.context.getApplicationContext();

  public static enqueueBackgroundWorker() {
    BackgroundWorkerApiImpl.enqueueBackgroundWorker();
  }

  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    try {
      MediaObserverScheduler.enqueueBackgroundWorker();
    } catch (e) {
      console.error("MediaObserverScheduler.enqueueBackgroundWorker error", e);
    }
    workScheduler.stopWork(workInfo, false);
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx);
  }
}
