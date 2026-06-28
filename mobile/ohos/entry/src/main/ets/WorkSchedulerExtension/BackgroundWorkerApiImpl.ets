import { common } from '@kit.AbilityKit'
import { BackgroundWorkerFgHostApi, BackgroundWorkerSettings } from './BackgroundWorker.g'
import dataPreferences from '@ohos.data.preferences'
import preferences from '@ohos.data.preferences';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { BackgroundWorkerPreferences } from '../plugins/Background/BackgroundWorkerPreferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { FlutterEngineCache } from '@ohos/flutter_ohos';

export class BackgroundWorkerApiImpl extends BackgroundWorkerFgHostApi {
  private ctx?: common.ApplicationContext;
  static readonly TAG: string = "BackgroundWorkerApiImpl"

  constructor(context: common.ApplicationContext) {
    super();
    this.ctx = context;
  }

  override enable() {
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx!)
    BackgroundWorkerApiImpl.enqueuePeriodicWorker(this.ctx!)
  }

  override saveNotificationMessage(title: string, body: string): void {
    const prefs = new BackgroundWorkerPreferences(this.ctx!);
    prefs.updateNotificationConfig(title, body);
  }

  override configure(settings: BackgroundWorkerSettings): void {
    const prefs = new BackgroundWorkerPreferences(this.ctx!);
    prefs.updateSettings({
      minimumDelaySeconds: settings.getMinimumDelaySeconds() ?? 0,
      requiresCharging: settings.getRequiresCharging() ?? false,
    });
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx!);
    BackgroundWorkerApiImpl.enqueuePeriodicWorker(this.ctx!);
  }

  override disable() {
    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.MEDIAOBSERVER_WORKER_INFO, true)
      workScheduler.stopWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO, true);
      workScheduler.stopWork(BackgroundWorkerApiImpl.PERIODIC_WORKER_INFO, true);
      console.info(BackgroundWorkerApiImpl.TAG, "Cancelled background upload tasks success")
    }catch (e) {
      console.info(BackgroundWorkerApiImpl.TAG, "Cancelled background upload tasks failed")
    }
  }

  static readonly BACKGROUND_WORKER_NAME = "immich/BackgroundWorkerV1"
  static readonly BACKGROUND_WORKER_ID = 1;
  static readonly MediaObserver_WORKER_ID = 2;
  static readonly PERIODIC_WORKER_ID = 3;
  static readonly OBSERVER_WORKER_NAME = "immich/MediaObserverV1"
  static readonly PERIODIC_WORKER_NAME = "immich/PeriodicBackgroundWorkerV1"
  static readonly PERIODIC_WORKER_REPEAT_MS = 2 * 60 * 60 * 1000;
  static readonly WORKER_DATA_TASK_TYPE = "taskType"
  public static readonly SHARED_PREF_NAME = "Immich::Background"
  public static readonly SHARED_PREF_BACKUP_ENABLED = "Background::backup::enabled"
  public static readonly SHARED_PREF_CALLBACK_HANDLE = "Background::backup::callbackHandle"
  public static readonly ENGINE_CACHE_KEY = "immich::background_worker::engine"
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
    abilityName: 'MediaObserverScheduler',
    batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
    networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
  };

  static PERIODIC_WORKER_INFO: workScheduler.WorkInfo = {
    workId: BackgroundWorkerApiImpl.PERIODIC_WORKER_ID,
    bundleName: 'com.dgh18.immich',
    abilityName: 'PeriodicWorker',
    networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
    batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
    isRepeat: true,
    repeatCycleTime: BackgroundWorkerApiImpl.PERIODIC_WORKER_REPEAT_MS,
    isPersisted: true,
  }

  static updateUploadEnabled(context: common.ApplicationContext, enabled: boolean) {
    let options: preferences.Options = { name: BackgroundWorkerApiImpl.SHARED_PREF_NAME };
    dataPreferences.getPreferencesSync(context, options)
      .putSync(BackgroundWorkerApiImpl.SHARED_PREF_BACKUP_ENABLED, enabled);
    dataPreferences.getPreferencesSync(context, options).flush;

  }


  public static enqueueMediaObserver(ctx: common.ApplicationContext): void {
    const settings = new BackgroundWorkerPreferences(ctx).getSettings();
    let constraints: workScheduler.WorkInfo = {
      workId: BackgroundWorkerApiImpl.MediaObserver_WORKER_ID,
      bundleName: 'com.dgh18.immich',
      abilityName: 'MediaObserverScheduler',
      batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
    };
    if (settings.requiresCharging) {
      constraints.isCharging = true;
    }

    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.MEDIAOBSERVER_WORKER_INFO, true);
    } catch (error) {
      const e = error as BusinessError;
      console.info(BackgroundWorkerApiImpl.TAG, `No existing media observer worker to cancel: ${e.code} ${e.message}`);
    }

    workScheduler.startWork(constraints);
    console.info(BackgroundWorkerApiImpl.TAG, "Enqueued media observer worker with name" + BackgroundWorkerApiImpl.OBSERVER_WORKER_NAME +
    BackgroundWorkerApiImpl.MediaObserver_WORKER_ID);
  }

  public static enqueuePeriodicWorker(ctx: common.ApplicationContext): void {
    const settings = new BackgroundWorkerPreferences(ctx).getSettings();
    const constraints: workScheduler.WorkInfo = {
      workId: BackgroundWorkerApiImpl.PERIODIC_WORKER_ID,
      bundleName: 'com.dgh18.immich',
      abilityName: 'PeriodicWorker',
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
      batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
      isRepeat: true,
      repeatCycleTime: BackgroundWorkerApiImpl.PERIODIC_WORKER_REPEAT_MS,
      isPersisted: true,
    };
    if (settings.requiresCharging) {
      constraints.isCharging = true;
    }

    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.PERIODIC_WORKER_INFO, true);
    } catch (error) {
      const e = error as BusinessError;
      console.info(BackgroundWorkerApiImpl.TAG, `No existing periodic background worker to cancel: ${e.code} ${e.message}`);
    }

    workScheduler.startWork(constraints);
    console.info(BackgroundWorkerApiImpl.TAG, "Enqueued periodic background worker with name: " +
    BackgroundWorkerApiImpl.PERIODIC_WORKER_NAME);
  }

  public static enqueueBackgroundWorker(): void {
    try {
      workScheduler.startWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO);
      console.info(BackgroundWorkerApiImpl.TAG, "Enqueued background worker with name: " +
      BackgroundWorkerApiImpl.BACKGROUND_WORKER_NAME);
    } catch (error) {
      const e = error as BusinessError;
      console.info(BackgroundWorkerApiImpl.TAG, `Background worker was not enqueued: ${e.code} ${e.message}`);
    }
  }

  static async isBackgroundWorkerRunning(): Promise<boolean> {
    return await new Promise<boolean>((resolve) => {
      try {
        workScheduler.obtainAllWorks((error: BusinessError, workInfoList: Array<workScheduler.WorkInfo>) => {
          if (error) {
            console.error(`isBackgroundWorkerRunning failed: ${error.code} ${error.message}`);
            resolve(false);
            return;
          }
          const running = workInfoList.some(
            (info) => info.abilityName === BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO.abilityName,
          );
          resolve(running);
        });
      } catch (e) {
        console.error('isBackgroundWorkerRunning exception', e);
        resolve(false);
      }
    });
  }

  public static cancelBackgroundWorker() {
    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO);
      console.info("MediaObserverScheduler", "Cancelled background worker");
    } catch (e) {
      console.error("MediaObserverScheduler cancelBackgroundWorker error", e);
    }
    try {
      FlutterEngineCache.getInstance().remove(BackgroundWorkerApiImpl.ENGINE_CACHE_KEY);
    } catch (_) {
      // ignore cache cleanup errors
    }
  }

}
