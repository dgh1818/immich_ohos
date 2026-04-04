import { preferences } from '@kit.ArkData';

export class HybridLaunchModePreferences {
  private readonly ctx: Context;

  private static readonly PREF_NAME = 'Immich::HybridLaunchMode';
  private static readonly KEY_ENABLED = 'HybridLaunchMode::enabled';
  private static readonly KEY_INITIALIZED = 'HybridLaunchMode::initialized';
  private static readonly OPTIONS: preferences.Options = { name: HybridLaunchModePreferences.PREF_NAME };

  constructor(ctx: Context) {
    this.ctx = ctx;
  }

  isInitialized(): boolean {
    const pref = preferences.getPreferencesSync(this.ctx, HybridLaunchModePreferences.OPTIONS);
    return pref.getSync(HybridLaunchModePreferences.KEY_INITIALIZED, false) as boolean;
  }

  isHybridEnabled(): boolean {
    const pref = preferences.getPreferencesSync(this.ctx, HybridLaunchModePreferences.OPTIONS);
    return pref.getSync(HybridLaunchModePreferences.KEY_ENABLED, false) as boolean;
  }

  setHybridEnabled(enabled: boolean): void {
    const pref = preferences.getPreferencesSync(this.ctx, HybridLaunchModePreferences.OPTIONS);
    pref.putSync(HybridLaunchModePreferences.KEY_ENABLED, enabled);
    pref.putSync(HybridLaunchModePreferences.KEY_INITIALIZED, true);
    pref.flush();
  }
}
