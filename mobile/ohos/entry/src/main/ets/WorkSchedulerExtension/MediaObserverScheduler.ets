import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';
import { BackgroundWorkerLog } from './BackgroundWorkerLog';

export class MediaObserverScheduler extends WorkSchedulerExtensionAbility {
  private ctx: common.ApplicationContext = this.context.getApplicationContext();

  public static enqueueBackgroundWorker() {
    BackgroundWorkerApiImpl.enqueueBackgroundWorker();
  }

  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    BackgroundWorkerLog.info(`MediaObserverScheduler triggered: workId=${workInfo.workId}, abilityName=${workInfo.abilityName}`);
    try {
      BackgroundWorkerLog.info('MediaObserverScheduler requesting one-shot upload worker');
      MediaObserverScheduler.enqueueBackgroundWorker();
    } catch (e) {
      BackgroundWorkerLog.error(`MediaObserverScheduler enqueueBackgroundWorker failed: ${String(e)}`);
      console.error("MediaObserverScheduler.enqueueBackgroundWorker error", e);
    }
    try {
      workScheduler.stopWork(workInfo, false);
      BackgroundWorkerLog.info('MediaObserverScheduler callback work stopped');
    } catch (e) {
      BackgroundWorkerLog.error(`MediaObserverScheduler stopWork failed: ${String(e)}`);
      throw new Error(`MediaObserverScheduler stopWork failed: ${String(e)}`);
    }
    BackgroundWorkerLog.info('MediaObserverScheduler re-enqueuing media observer');
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx);
  }
}
