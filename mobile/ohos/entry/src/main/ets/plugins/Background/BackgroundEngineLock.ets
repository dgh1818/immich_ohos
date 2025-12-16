import { BackgroundWorkerLockApi } from './BackgroundWorkerLock.g';
import { preferences } from '@kit.ArkData';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { BackgroundWorkerApiImpl } from '../../WorkSchedulerExtension/BackgroundWorkerApiImpl';
import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';
import ImmichPlugin from '../core/ImmichPlugin';

class BackgroundWorkerPreferences {
  private readonly ctx: Context;
  private static readonly PREF_NAME = 'Immich::BackgroundWorkerLock';
  private static readonly KEY_LOCKED = 'BackgroundWorker::locked';
  private static readonly OPTIONS: preferences.Options = { name: BackgroundWorkerPreferences.PREF_NAME };

  constructor(ctx: Context) {
    this.ctx = ctx;
  }

  isLocked(): boolean {
    const pref = preferences.getPreferencesSync(this.ctx, BackgroundWorkerPreferences.OPTIONS);
    return pref.getSync(BackgroundWorkerPreferences.KEY_LOCKED, false) as boolean;
  }

  setLocked(value: boolean) {
    const pref = preferences.getPreferencesSync(this.ctx, BackgroundWorkerPreferences.OPTIONS);
    pref.putSync(BackgroundWorkerPreferences.KEY_LOCKED, value);
    pref.flush();
  }
}

class BackgroundEngineLock extends BackgroundWorkerLockApi implements FlutterPlugin{
  private ctx: Context;
  private static engineCount = 0;
  private pluginHelper: ImmichPlugin = new ImmichPlugin();

  constructor(ctx: Context) {
    super();
    this.ctx = ctx;
  }

  private checkAndEnforceBackgroundLock() {
    const prefs = new BackgroundWorkerPreferences(this.ctx);
    const locked = prefs.isLocked();
    if (locked && BackgroundEngineLock.engineCount > 1) {
      // 背景任务运行时主应用已打开，取消后台任务
      try {
        workScheduler.stopWork(BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO);
      } catch (_) {
        // ignore stop errors
      }
    }
  }

  override lock() {
    const prefs = new BackgroundWorkerPreferences(this.ctx);
    prefs.setLocked(true);
    this.checkAndEnforceBackgroundLock();
  }

  override unlock() {
    const prefs = new BackgroundWorkerPreferences(this.ctx);
    prefs.setLocked(false);
  }

  getUniqueClassName(): string {
    return 'BackgroundEngineLock';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.pluginHelper.onAttachedToEngine(binding);
    BackgroundEngineLock.onEngineAttached(binding.getApplicationContext());
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.pluginHelper.onDetachedFromEngine(binding);
    BackgroundEngineLock.onEngineDetached();
  }

  public detachFromEngine(): void {
    this.pluginHelper.detachFromEngine();
  }

  // 需要在合适位置调用，比如插件注册时
  public static onEngineAttached(ctx: Context) {
    BackgroundEngineLock.engineCount += 1;
    new BackgroundEngineLock(ctx).checkAndEnforceBackgroundLock();
  }

  public static onEngineDetached() {
    BackgroundEngineLock.engineCount = Math.max(0, BackgroundEngineLock.engineCount - 1);
  }
}

export default BackgroundEngineLock;
