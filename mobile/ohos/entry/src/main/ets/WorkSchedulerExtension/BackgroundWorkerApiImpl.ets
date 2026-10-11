import { common } from '@kit.AbilityKit'
import { BackgroundWorkerFgHostApi, BackgroundWorkerSettings } from './BackgroundWorker.g'
import dataPreferences from '@ohos.data.preferences'
import preferences from '@ohos.data.preferences';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { BackgroundWorkerPreferences } from '../plugins/Background/BackgroundWorkerPreferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { FlutterEngineCache } from '@ohos/flutter_ohos';
import { BackgroundWorkerLog } from './BackgroundWorkerLog';

export class BackgroundWorkerApiImpl extends BackgroundWorkerFgHostApi {
  private ctx?: common.ApplicationContext;
  static readonly TAG: string = "BackgroundWorkerApiImpl"

  constructor(context: common.ApplicationContext) {
    super();
    this.ctx = context;
  }

  override enable() {
    BackgroundWorkerLog.info('Background worker enable requested');
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx!)
    BackgroundWorkerApiImpl.enqueuePeriodicWorker(this.ctx!)
  }

  override saveNotificationMessage(title: string, body: string): void {
    const prefs = new BackgroundWorkerPreferences(this.ctx!);
    prefs.updateNotificationConfig(title, body);
  }

  override configure(settings: BackgroundWorkerSettings): void {
    BackgroundWorkerLog.info(`Background worker configuration received: minimumDelaySeconds=${settings.getMinimumDelaySeconds()}, requiresCharging=${settings.getRequiresCharging()}`);
    const prefs = new BackgroundWorkerPreferences(this.ctx!);
    prefs.updateSettings({
      minimumDelaySeconds: settings.getMinimumDelaySeconds() ?? 0,
      requiresCharging: settings.getRequiresCharging() ?? false,
    });
    BackgroundWorkerApiImpl.enqueueMediaObserver(this.ctx!);
    BackgroundWorkerApiImpl.enqueuePeriodicWorker(this.ctx!);
  }

  override disable() {
    BackgroundWorkerLog.info('Background worker disable requested');
    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.MEDIAOBSERVER_WORKER_INFO, true)
      workScheduler.stopWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO, true);
      workScheduler.stopWork(BackgroundWorkerApiImpl.PERIODIC_WORKER_INFO, true);
      BackgroundWorkerLog.info('Cancelled background upload scheduler tasks');
    }catch (e) {
      BackgroundWorkerLog.warn(`Cancelling background upload scheduler tasks failed: ${String(e)}`);
    }
  }

  override wasLaunchedInBackground(): boolean {
    // This signal is only meaningful for iOS background tasks.
    return false;
  }

  static readonly BACKGROUND_WORKER_NAME = "immich/BackgroundWorkerV1"
  static readonly BACKGROUND_WORKER_ID = 1;
  private static backgroundWorkSequence: number = 0;
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
    BackgroundWorkerLog.info(`Scheduling MediaObserver: requiresCharging=${settings.requiresCharging}`);
    let constraints: workScheduler.WorkInfo = {
      workId: BackgroundWorkerApiImpl.MediaObserver_WORKER_ID,
      bundleName: 'com.dgh18.immich',
      abilityName: 'MediaObserverScheduler',
      batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
      networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
      isPersisted: true,
    };
    if (settings.requiresCharging) {
      constraints.isCharging = true;
    }

    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.MEDIAOBSERVER_WORKER_INFO, true);
    } catch (error) {
      const e = error as BusinessError;
      BackgroundWorkerLog.info(`No existing media observer work to cancel: code=${e.code}, message=${e.message}`);
    }

    try {
      workScheduler.startWork(constraints);
      BackgroundWorkerLog.info(`MediaObserver scheduled: abilityName=${constraints.abilityName}, workId=${constraints.workId}`);
    } catch (error) {
      const e = error as BusinessError;
      BackgroundWorkerLog.error(`Scheduling MediaObserver failed: code=${e.code}, message=${e.message}`);
      throw new Error(`Scheduling MediaObserver failed: ${e.code} ${e.message}`);
    }
  }

  public static enqueuePeriodicWorker(ctx: common.ApplicationContext): void {
    const settings = new BackgroundWorkerPreferences(ctx).getSettings();
    BackgroundWorkerLog.info(`Scheduling periodic worker: requiresCharging=${settings.requiresCharging}, repeatCycleMs=${BackgroundWorkerApiImpl.PERIODIC_WORKER_REPEAT_MS}`);
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
      BackgroundWorkerLog.info(`No existing periodic work to cancel: code=${e.code}, message=${e.message}`);
    }

    try {
      workScheduler.startWork(constraints);
      BackgroundWorkerLog.info(`Periodic worker scheduled: abilityName=${constraints.abilityName}, workId=${constraints.workId}, persisted=${constraints.isPersisted}`);
    } catch (error) {
      const e = error as BusinessError;
      BackgroundWorkerLog.error(`Scheduling periodic worker failed: code=${e.code}, message=${e.message}`);
      throw new Error(`Scheduling periodic worker failed: ${e.code} ${e.message}`);
    }
  }

  public static enqueueBackgroundWorker(): void {
    BackgroundWorkerLog.info('Requesting one-shot background upload work');
    try {
      const runToken = `${Date.now()}-${++BackgroundWorkerApiImpl.backgroundWorkSequence}`;
      const workInfo: workScheduler.WorkInfo = {
        workId: BackgroundWorkerApiImpl.BACKGROUND_WORKER_ID,
        bundleName: 'com.dgh18.immich',
        abilityName: 'BackgroundWorker',
        batteryStatus: workScheduler.BatteryStatus.BATTERY_STATUS_OKAY,
        parameters: {
          immichBackgroundRunToken: runToken,
        },
      };
      workScheduler.startWork(workInfo);
      BackgroundWorkerLog.info(`One-shot background upload work scheduled: workId=${workInfo.workId}, abilityName=${workInfo.abilityName}, runToken=${runToken}`);
    } catch (error) {
      const e = error as BusinessError;
      BackgroundWorkerLog.error(`One-shot background upload work was not scheduled: code=${e.code}, message=${e.message}`);
    }
  }

  static async isBackgroundWorkerRunning(): Promise<boolean> {
    return await new Promise<boolean>((resolve) => {
      try {
        workScheduler.obtainAllWorks((error: BusinessError, workInfoList: Array<workScheduler.WorkInfo>) => {
          if (error) {
            BackgroundWorkerLog.error(`Querying WorkScheduler state failed: code=${error.code}, message=${error.message}`);
            console.error(`isBackgroundWorkerRunning failed: ${error.code} ${error.message}`);
            resolve(false);
            return;
          }
          const running = workInfoList.some(
            (info) => info.abilityName === BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO.abilityName,
          );
          BackgroundWorkerLog.info(`WorkScheduler state queried: works=${workInfoList.length}, backgroundWorkerRunning=${running}`);
          resolve(running);
        });
      } catch (e) {
        BackgroundWorkerLog.error(`Querying WorkScheduler state threw: ${String(e)}`);
        console.error('isBackgroundWorkerRunning exception', e);
        resolve(false);
      }
    });
  }

  public static cancelBackgroundWorker() {
    BackgroundWorkerLog.info('Cancelling one-shot background worker');
    try {
      workScheduler.stopWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO);
      BackgroundWorkerLog.info('One-shot background worker cancellation requested');
    } catch (e) {
      BackgroundWorkerLog.warn(`One-shot background worker cancellation failed: ${String(e)}`);
    }
    try {
      FlutterEngineCache.getInstance().remove(BackgroundWorkerApiImpl.ENGINE_CACHE_KEY);
      BackgroundWorkerLog.info('Background FlutterEngine cache entry removed during cancellation');
    } catch (e) {
      BackgroundWorkerLog.warn(`Removing background FlutterEngine cache entry during cancellation failed: ${String(e)}`);
    }
  }

}
