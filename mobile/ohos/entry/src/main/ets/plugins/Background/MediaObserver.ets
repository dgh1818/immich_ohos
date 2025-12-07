import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';
import dataPreferences from '@ohos.data.preferences'

class MediaObserver extends WorkSchedulerExtensionAbility {
  private ctx: common.ApplicationContext = this.context.getApplicationContext();
  onWorkStart(workInfo: workScheduler.WorkInfo) {
    BackgroundWorkerApiImpl.enqueueBackgroundWorker(this.ctx)
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx)
  }
}
