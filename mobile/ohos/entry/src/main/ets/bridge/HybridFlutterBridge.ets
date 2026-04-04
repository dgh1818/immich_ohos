import { FlutterEngine } from '@ohos/flutter_ohos';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import { HybridLaunchModePreferences } from './HybridLaunchModePreferences';

interface FetchPhotoPageArgs {
  offset: number;
  limit: number;
}

interface LaunchModePreferenceState {
  hybridArkuiPhotos: boolean;
  initialized: boolean;
}

export class HybridFlutterBridge {
  private static channel?: MethodChannel;
  private static launchModePreferences?: HybridLaunchModePreferences;

  static attachEngine(flutterEngine: FlutterEngine, context: Context): void {
    HybridFlutterBridge.channel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      'immich/hybrid',
    );
    HybridFlutterBridge.launchModePreferences = new HybridLaunchModePreferences(context);
    HybridFlutterBridge.channel.setMethodCallHandler(
      new HybridFlutterBridgeMethodHandler(HybridFlutterBridge.launchModePreferences),
    );
  }

  static getSavedLaunchMode(): string {
    return HybridFlutterBridge.launchModePreferences?.isHybridEnabled() === true
      ? 'hybrid_arkui_photos'
      : 'legacy_flutter';
  }

  static async fetchPhotoPage(offset: number, limit: number): Promise<string> {
    const args: FetchPhotoPageArgs = { offset, limit };
    const result: ESObject | undefined = await HybridFlutterBridge.invokeMethodWithRetry(
      'fetchPhotoPage',
      args as ESObject,
      12,
      250,
    );
    return typeof result === 'string' ? result : '';
  }

  private static async invokeMethodWithRetry(
    method: string,
    args: ESObject,
    attempts: number,
    delayMs: number,
  ): Promise<ESObject | undefined> {
    let lastError: Error | undefined = undefined;

    for (let attempt = 1; attempt <= attempts; attempt += 1) {
      try {
        return await HybridFlutterBridge.invokeMethod(method, args);
      } catch (error) {
        lastError = error as Error;
        if (attempt >= attempts || !HybridFlutterBridge.shouldRetry(error)) {
          throw lastError ?? new Error(`${error}`);
        }
        await HybridFlutterBridge.delay(delayMs);
      }
    }

    throw lastError ?? new Error(`Hybrid bridge call failed: ${method}`);
  }

  private static invokeMethod(method: string, args?: ESObject): Promise<ESObject | undefined> {
    return new Promise((resolve, reject) => {
      const channel = HybridFlutterBridge.channel;
      if (!channel) {
        reject(new Error('Hybrid Flutter bridge is not ready'));
        return;
      }

      const callback: MethodResult = {
        success: (result: ESObject) => {
          resolve(result);
        },
        error: (errorCode: string, errorMessage: string) => {
          reject(new Error(`${errorCode}: ${errorMessage}`));
        },
        notImplemented: () => {
          reject(new Error(`Hybrid bridge method not implemented: ${method}`));
        },
      };

      channel.invokeMethod(method, args, callback);
    });
  }

  private static shouldRetry(error: Object): boolean {
    const message = `${error}`.toLowerCase();
    return message.includes('not implemented') || message.includes('not ready');
  }

  private static delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(() => resolve(), ms);
    });
  }
}

class HybridFlutterBridgeMethodHandler implements MethodCallHandler {
  private readonly launchModePreferences: HybridLaunchModePreferences;

  constructor(launchModePreferences: HybridLaunchModePreferences) {
    this.launchModePreferences = launchModePreferences;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'getLaunchModePreferenceState': {
        const state: LaunchModePreferenceState = {
          hybridArkuiPhotos: this.launchModePreferences.isHybridEnabled(),
          initialized: this.launchModePreferences.isInitialized(),
        };
        result.success(JSON.stringify(state));
        return;
      }
      case 'setLaunchModePreference': {
        this.launchModePreferences.setHybridEnabled(this.readHybridEnabled(call.args));
        result.success(true);
        return;
      }
      default:
        result.notImplemented();
        return;
    }
  }

  private readHybridEnabled(args: ESObject): boolean {
    return args === true;
  }
}
