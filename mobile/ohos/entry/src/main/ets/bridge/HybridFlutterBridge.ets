import { common } from '@kit.AbilityKit';
import { FlutterEngine } from '@ohos/flutter_ohos';
import MethodCall from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodCall';
import MethodChannel, {
  MethodCallHandler,
  MethodResult,
} from '@ohos/flutter_ohos/src/main/ets/plugin/common/MethodChannel';
import * as Shared from '../pages/hybrid/HybridPhotoGridShared';
import { TimelineLayoutBuilder } from '../pages/hybrid/TimelineLayoutBuilder';
import * as Thumbnail from '../pages/hybrid/HybridPhotoThumbnail';
import * as ThumbnailDisk from '../pages/hybrid/HybridPhotoThumbnailDisk';
import { HybridLaunchModePreferences } from './HybridLaunchModePreferences';

interface FetchTimelineWindowArgs {
  offset: number;
  limit: number;
}

interface OpenTimelineAssetViewerAtArgs {
  index: number;
}

interface LaunchModePreferenceState {
  hybridArkuiPhotos: boolean;
  initialized: boolean;
}

interface PredownloadTimelineHeadThumbnailsArgs {
  pages: number;
}

export class HybridFlutterBridge {
  private static channel?: MethodChannel;
  private static uiAbilityContext?: common.UIAbilityContext;
  private static launchModePreferences?: HybridLaunchModePreferences;

  static attachEngine(flutterEngine: FlutterEngine, context: Context): void {
    HybridFlutterBridge.channel = new MethodChannel(
      flutterEngine.dartExecutor.getBinaryMessenger(),
      'immich/hybrid',
    );
    HybridFlutterBridge.uiAbilityContext = context as common.UIAbilityContext;
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

  static getUIAbilityContext(): common.UIAbilityContext | undefined {
    return HybridFlutterBridge.uiAbilityContext;
  }

  static async fetchTimelineWindow(offset: number, limit: number): Promise<string> {
    const args: FetchTimelineWindowArgs = { offset, limit };
    const result: ESObject | undefined = await HybridFlutterBridge.invokeMethodWithRetry(
      'fetchTimelineWindow',
      args as ESObject,
      12,
      250,
    );
    return typeof result === 'string' ? result : '';
  }

  static async openTimelineAssetViewerAt(index: number): Promise<void> {
    const args: OpenTimelineAssetViewerAtArgs = { index };
    await HybridFlutterBridge.invokeMethodWithRetry(
      'openTimelineAssetViewerAt',
      args as ESObject,
      12,
      250,
    );
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

class HybridTimelineHeadThumbnailPredownloadCoordinator {
  private static readonly DEFAULT_PAGES: number = 4;
  private static readonly MAX_PAGES: number = 4;
  private static readonly START_DELAY_MS: number = 1200;
  private static readonly BATCH_SIZE: number = 2;
  private static readonly WAIT_WHILE_BUSY_MS: number = Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 4;
  private static readonly INTER_BATCH_DELAY_MS: number = Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 2;

  private static running: boolean = false;
  private static queuedPages: number = 0;

  static schedule(pages: number): void {
    const normalizedPages = HybridTimelineHeadThumbnailPredownloadCoordinator.normalizePages(pages);
    if (HybridTimelineHeadThumbnailPredownloadCoordinator.running) {
      HybridTimelineHeadThumbnailPredownloadCoordinator.queuedPages = Math.max(
        HybridTimelineHeadThumbnailPredownloadCoordinator.queuedPages,
        normalizedPages,
      );
      return;
    }

    HybridTimelineHeadThumbnailPredownloadCoordinator.running = true;
    void HybridTimelineHeadThumbnailPredownloadCoordinator.run(normalizedPages)
      .catch((error: Object) => {
        console.error(`[HybridFlutterBridge] head thumbnail predownload failed: ${error}`);
      })
      .finally(() => {
        HybridTimelineHeadThumbnailPredownloadCoordinator.running = false;
        const queuedPages = HybridTimelineHeadThumbnailPredownloadCoordinator.queuedPages;
        HybridTimelineHeadThumbnailPredownloadCoordinator.queuedPages = 0;
        if (queuedPages > 0) {
          HybridTimelineHeadThumbnailPredownloadCoordinator.schedule(queuedPages);
        }
      });
  }

  private static async run(pages: number): Promise<void> {
    await Shared.delay(HybridTimelineHeadThumbnailPredownloadCoordinator.START_DELAY_MS);

    const context = HybridFlutterBridge.getUIAbilityContext();
    if (!context) {
      return;
    }

    const timelineBuilder = new TimelineLayoutBuilder();
    const seenUrls: Set<string> = new Set();
    let offset = 0;

    for (
      let pageIndex = 0;
      pageIndex < pages && Thumbnail.shouldContinueBackgroundPredownload(context);
      pageIndex += 1
    ) {
      await HybridTimelineHeadThumbnailPredownloadCoordinator.waitUntilLowPressure();
      const payload = await HybridFlutterBridge.fetchTimelineWindow(offset, Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE);
      const page = timelineBuilder.parsePageResult(payload);
      if (!page.ready || page.sections.length <= 0) {
        break;
      }

      const assets = timelineBuilder.collectPredownloadAssets(page.sections, true);
      await HybridTimelineHeadThumbnailPredownloadCoordinator.predownloadAssets(context, assets, seenUrls);

      if (!page.hasMore || page.nextOffset <= offset) {
        break;
      }
      offset = page.nextOffset;
    }

    Thumbnail.flushDeferredThumbnailWritesIfIdle();
    Thumbnail.trimRemoteThumbnailCacheIfNeeded(context);
  }

  private static async predownloadAssets(
    context: common.UIAbilityContext,
    assets: Array<Shared.HybridPhotoAsset>,
    seenUrls: Set<string>,
  ): Promise<void> {
    for (
      let index = 0;
      index < assets.length && Thumbnail.shouldContinueBackgroundPredownload(context);
      index += HybridTimelineHeadThumbnailPredownloadCoordinator.BATCH_SIZE
    ) {
      await HybridTimelineHeadThumbnailPredownloadCoordinator.waitUntilLowPressure();

      const batch = assets.slice(
        index,
        index + HybridTimelineHeadThumbnailPredownloadCoordinator.BATCH_SIZE,
      );
      await Promise.all(batch.map(async (asset: Shared.HybridPhotoAsset): Promise<void> => {
        const url = asset.thumbnailUrl;
        if (!url || seenUrls.has(url)) {
          return;
        }
        seenUrls.add(url);
        try {
          await Thumbnail.backgroundPredownloadRemoteThumbnail(context, url, Shared.HYBRID_REQUEST_SIZE);
        } catch (_) {
          // best-effort low-priority warmup
        }
      }));

      await Shared.delay(HybridTimelineHeadThumbnailPredownloadCoordinator.INTER_BATCH_DELAY_MS);
    }
  }

  private static async waitUntilLowPressure(): Promise<void> {
    while (ThumbnailDisk.HybridScrollState.isScrolling || Thumbnail.HybridThumbnailRequestLimiter.isUnderPressure()) {
      await Shared.delay(HybridTimelineHeadThumbnailPredownloadCoordinator.WAIT_WHILE_BUSY_MS);
    }
  }

  private static normalizePages(pages: number): number {
    if (!Number.isFinite(pages)) {
      return HybridTimelineHeadThumbnailPredownloadCoordinator.DEFAULT_PAGES;
    }

    const roundedPages = Math.round(pages);
    if (roundedPages < 1) {
      return 1;
    }
    if (roundedPages > HybridTimelineHeadThumbnailPredownloadCoordinator.MAX_PAGES) {
      return HybridTimelineHeadThumbnailPredownloadCoordinator.MAX_PAGES;
    }
    return roundedPages;
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
      case 'setHybridSelectedPane': {
        AppStorage.setOrCreate('hybridSelectedPane', this.readPaneIndex(call.args));
        result.success(true);
        return;
      }
      case 'predownloadTimelineHeadThumbnails': {
        const pages = this.readPredownloadPages(call.args);
        result.success(true);
        HybridTimelineHeadThumbnailPredownloadCoordinator.schedule(pages);
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

  private readPaneIndex(args: ESObject): number {
    if (typeof args === 'number' && Number.isFinite(args)) {
      return args;
    }
    return 0;
  }

  private readPredownloadPages(args: ESObject): number {
    if (args && typeof args === 'object') {
      const payload = args as PredownloadTimelineHeadThumbnailsArgs;
      if (typeof payload.pages === 'number' && Number.isFinite(payload.pages)) {
        const roundedPages = Math.round(payload.pages);
        if (roundedPages < 1) {
          return 1;
        }
        if (roundedPages > 4) {
          return 4;
        }
        return roundedPages;
      }
    }
    return 4;
  }
}
