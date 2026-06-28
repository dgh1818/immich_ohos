import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';

export class PeriodicWorker extends WorkSchedulerExtensionAbility {
  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    console.info('PeriodicWorker', 'Periodic worker triggered, starting background worker');
    BackgroundWorkerApiImpl.enqueueBackgroundWorker();
    workScheduler.stopWork(workInfo, false);
  }
}
