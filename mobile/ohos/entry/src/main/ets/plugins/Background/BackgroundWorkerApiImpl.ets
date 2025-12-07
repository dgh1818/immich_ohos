import { common } from '@kit.AbilityKit'
import { BackgroundWorkerFgHostApi } from './BackgroundWorker.g'
import dataPreferences from '@ohos.data.preferences'
import preferences from '@ohos.data.preferences';
import { workScheduler } from '@kit.BackgroundTasksKit';

export class BackgroundWorkerApiImpl extends BackgroundWorkerFgHostApi {
  private ctx?: common.ApplicationContext;
  static readonly TAG: string = "BackgroundUploadImpl"

  constructor(context: common.ApplicationContext) {
    super();
    this.ctx = context;
  }

  override enable() {
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx!)
  }

  override disable() {
    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.MEDIAOBSERVER_WORKER_INFO)
      workScheduler.stopWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO, true);
      console.info(BackgroundWorkerApiImpl.TAG, "Cancelled background upload tasks success")
    }catch (e) {
      console.info(BackgroundWorkerApiImpl.TAG, "Cancelled background upload tasks failed")
    }
  }

  static readonly BACKGROUND_WORKER_NAME = "immich/BackgroundWorkerV1"
  static readonly BACKGROUND_WORKER_ID = 1;
  static readonly MediaObserver_WORKER_ID = 2;
  static readonly OBSERVER_WORKER_NAME = "immich/MediaObserverV1"
  static readonly WORKER_DATA_TASK_TYPE = "taskType"
  public static readonly SHARED_PREF_NAME = "Immich::Background"
  public static readonly SHARED_PREF_BACKUP_ENABLED = "Background::backup::enabled"
  public static readonly SHARED_PREF_CALLBACK_HANDLE = "Background::backup::callbackHandle"
  static BACKGROUND_WORKER_INFO:workScheduler.WorkInfo =
   {
    workId: BackgroundWorkerApiImpl.BACKGROUND_WORKER_ID,
    bundleName: 'com.dgh18.immich',
    abilityName: 'BackgroundWorker',
    batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
    //.setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
  }

  static MEDIAOBSERVER_WORKER_INFO:workScheduler.WorkInfo = {
    workId: BackgroundWorkerApiImpl.MediaObserver_WORKER_ID,
    bundleName: 'com.dgh18.immich',
    abilityName: 'MediaObserver',
    batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
    isCharging:true,
    isDeepIdle:true,
  };

  static updateUploadEnabled(context: common.ApplicationContext, enabled: Boolean) {
    let options: preferences.Options = { name: BackgroundWorkerApiImpl.SHARED_PREF_NAME };
    dataPreferences.getPreferencesSync(context, options)
      .putSync(BackgroundWorkerApiImpl.SHARED_PREF_BACKUP_ENABLED, enabled);
    dataPreferences.getPreferencesSync(context, options).flush;

  }

  public static enqueueMediaObserver(ctx: common.ApplicationContext) {
    // val constraints = Constraints.Builder()
    //   .addContentUriTrigger(MediaStore.Images.Media.INTERNAL_CONTENT_URI, true)
    //   .addContentUriTrigger(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, true)
    //   .addContentUriTrigger(MediaStore.Video.Media.INTERNAL_CONTENT_URI, true)
    //   .addContentUriTrigger(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, true)
    //   .setTriggerContentUpdateDelay(5, TimeUnit.SECONDS)
    //   .setTriggerContentMaxDelay(1, TimeUnit.MINUTES)
    //   .build()
    let constraints: workScheduler.WorkInfo = {
      workId: BackgroundWorkerApiImpl.MediaObserver_WORKER_ID,
      bundleName: 'com.dgh18.immich',
      abilityName: 'MediaObserver',
      batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
      isCharging:true,
      isDeepIdle:true,
    }

    BackgroundWorkerApiImpl.MEDIAOBSERVER_WORKER_INFO = constraints;
    workScheduler.startWork(constraints);
    console.info(BackgroundWorkerApiImpl.TAG, "Enqueued media observer worker with name" + BackgroundWorkerApiImpl.OBSERVER_WORKER_NAME +
    BackgroundWorkerApiImpl.MediaObserver_WORKER_ID);
  }

  public static enqueueBackgroundWorker(ctx: common.ApplicationContext) {
    let constraints: workScheduler.WorkInfo = {
      workId: BackgroundWorkerApiImpl.BACKGROUND_WORKER_ID,
      bundleName: 'com.dgh18.immich',
      abilityName: 'BackgroundWorker',
      batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
      //.setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
    }

    BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO = constraints;

    workScheduler.startWork(constraints);
    console.info(BackgroundWorkerApiImpl.TAG, "Enqueued background worker with name" + BackgroundWorkerApiImpl.BACKGROUND_WORKER_NAME +
    BackgroundWorkerApiImpl.BACKGROUND_WORKER_ID);
  }
}





