import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { common } from '@kit.AbilityKit';
import { BackgroundTaskType } from './BackgroundWorker';
import { preferences } from '@kit.ArkData';
import { BackgroundWorkerApiImpl } from './BackgroundWorkerApiImpl';
import dataPreferences from '@ohos.data.preferences'

class MediaObserver extends WorkSchedulerExtensionAbility {
  private ctx: common.ApplicationContext = this.context.getApplicationContext();
  onWorkStart(workInfo: workScheduler.WorkInfo) {
    let type =
      this.isBackupEnabled(this.ctx)? BackgroundTaskType.UPLOAD : BackgroundTaskType.LOCAL_SYNC
    BackgroundWorkerApiImpl.enqueueBackgroundWorker(this.ctx, type)
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx)
  }

  private isBackupEnabled(context: Context): boolean {
    let options: preferences.Options = { name: BackgroundWorkerApiImpl.SHARED_PREF_NAME };
    return dataPreferences.getPreferencesSync(context, options)
      .getSync(BackgroundWorkerApiImpl.SHARED_PREF_BACKUP_ENABLED, false) as boolean;
  }
}
