import { preferences } from '@kit.ArkData';
export interface BackgroundWorkerSettings {
  minimumDelaySeconds: number;
  requiresCharging: boolean;
}
export class BackgroundWorkerPreferences {
  private readonly ctx: Context;
  private static readonly PREF_NAME = 'Immich::BackgroundWorker';
  private static readonly KEY_MIN_DELAY = 'BackgroundWorker::minDelaySeconds';
  private static readonly KEY_REQUIRE_CHARGING = 'BackgroundWorker::requireCharging';
  private static readonly KEY_LOCK = 'BackgroundWorker::isLocked';
  private static readonly DEFAULT_MIN_DELAY_SECONDS = 30;
  private static readonly DEFAULT_REQUIRE_CHARGING = false;
  private static readonly OPTIONS: preferences.Options = { name: BackgroundWorkerPreferences.PREF_NAME };
  constructor(ctx: Context) {
    this.ctx = ctx;
  }
  updateSettings(settings: BackgroundWorkerSettings) {
    const pref = preferences.getPreferencesSync(this.ctx, BackgroundWorkerPreferences.OPTIONS);
    pref.putSync(BackgroundWorkerPreferences.KEY_MIN_DELAY, settings.minimumDelaySeconds);
    pref.putSync(BackgroundWorkerPreferences.KEY_REQUIRE_CHARGING, settings.requiresCharging);
    pref.flush();
  }
  getSettings(): BackgroundWorkerSettings {
    const pref = preferences.getPreferencesSync(this.ctx, BackgroundWorkerPreferences.OPTIONS);
    return {
      minimumDelaySeconds: pref.getSync(
        BackgroundWorkerPreferences.KEY_MIN_DELAY,
        BackgroundWorkerPreferences.DEFAULT_MIN_DELAY_SECONDS,
      ) as number,
      requiresCharging: pref.getSync(
        BackgroundWorkerPreferences.KEY_REQUIRE_CHARGING,
        BackgroundWorkerPreferences.DEFAULT_REQUIRE_CHARGING,
      ) as boolean,
    };
  }
  setLocked(paused: boolean) {
    const pref = preferences.getPreferencesSync(this.ctx, BackgroundWorkerPreferences.OPTIONS);
    pref.putSync(BackgroundWorkerPreferences.KEY_LOCK, paused);
    pref.flush();
  }
  isLocked(): boolean {
    const pref = preferences.getPreferencesSync(this.ctx, BackgroundWorkerPreferences.OPTIONS);
    return pref.getSync(BackgroundWorkerPreferences.KEY_LOCK, true) as boolean;
  }
}
