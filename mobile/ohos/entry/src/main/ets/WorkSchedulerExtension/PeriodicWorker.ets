import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';
import { BackgroundWorkerLog } from './BackgroundWorkerLog';

export class PeriodicWorker extends WorkSchedulerExtensionAbility {
  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    BackgroundWorkerLog.info(`PeriodicWorker triggered: workId=${workInfo.workId}, abilityName=${workInfo.abilityName}`);
    BackgroundWorkerApiImpl.enqueueBackgroundWorker();
    try {
      workScheduler.stopWork(workInfo, false);
      BackgroundWorkerLog.info('PeriodicWorker callback completed and work stopped');
    } catch (e) {
      BackgroundWorkerLog.error(`PeriodicWorker stopWork failed: ${String(e)}`);
      throw new Error(`PeriodicWorker stopWork failed: ${String(e)}`);
    }
  }
}
