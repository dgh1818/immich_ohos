import { workScheduler, WorkSchedulerExtensionAbility } from "@kit.BackgroundTasksKit";
import {
  FlutterEngine,
  FlutterEngineCache,
  FlutterInjector,
  FlutterLoader,
  MethodChannel,
  Reply,
} from "@ohos/flutter_ohos";
import { BackgroundWorkerBgHostApi, BackgroundWorkerFlutterApi } from "./BackgroundWorker.g";
import { BackgroundWorkerApiImpl } from "./BackgroundWorkerApiImpl";
import { notificationManager } from '@kit.NotificationKit';
import { DartEntrypoint } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/dart/DartExecutor';
import { BackgroundGeneratedPluginRegistrant } from '../plugins/BackgroundGeneratedPluginRegistrant';
import { NativeSyncApiOhos } from '../plugins/sync/Messages_ohos.g';
import { MessagesImplBase } from '../plugins/sync/MessagesImplBase';
import { LocalImageApiOhos } from '../plugins/Images/LocalImages.g';
import { RemoteImageApiOhos } from '../plugins/Images/RemoteImages.g';
import { LocalImagesImpl } from '../plugins/Images/LocalImagesImpl';
import { RemoteImagesImpl } from '../plugins/Images/RemoteImagesImpl';
import { BackgroundWorkerFgHostApi } from './BackgroundWorker.g';
import { ConnectivityApi } from '../plugins/connectivity/Connectivity.g';
import { ConnectivityApiImpl } from '../plugins/connectivity/ConnectivityApiImpl';
import BackgroundEngineLock from '../plugins/Background/BackgroundEngineLock';
import { BackgroundWorkerLockApi } from '../plugins/Background/BackgroundWorkerLock.g';
import { BackgroundWorkerPreferences } from '../plugins/Background/BackgroundWorkerPreferences';
import { NetworkApi } from '../plugins/core/Network.g';
import { NetworkApiImpl } from '../plugins/core/NetworkApiImpl';
import { BackgroundWorkerLog } from './BackgroundWorkerLog';

export class Deferred<T> {
  public promise: Promise<T>;
  public resolve: (value: T | PromiseLike<T>) => void = () => {};
  public reject: (reason?: object) => void = () => {};

  constructor() {
    this.promise = new Promise<T>((res, rej) => {
      this.resolve = res;
      this.reject = rej;
    });
  }
}

class BackgroundWorkerReply implements Reply<void> {
  private readonly success: boolean;
  private readonly runId: number;

  constructor(runId: number, success: boolean) {
    this.runId = runId;
    this.success = success;
  }

  reply(reply: void): void {
    BackgroundWorker.completeRun(this.runId, reply == undefined && this.success);
  }
}

class BackgroundWorkerUploadReply implements Reply<boolean> {
  private readonly runId: number;

  constructor(runId: number) {
    this.runId = runId;
  }

  reply(needsRetry: boolean): void {
    // onAndroidUpload returns whether Flutter needs the native worker to retry.
    BackgroundWorkerLog.info(`Dart upload callback returned needsRetry=${needsRetry}`);
    BackgroundWorker.completeRun(this.runId, needsRetry === false);
  }
}

class BackgroundWorker extends WorkSchedulerExtensionAbility {
  private ctx: Context = this.context.getApplicationContext();
  /// The Flutter loader that loads the native Flutter library and resources.
  /// This must be initialized before starting the Flutter engine.
  private loader: FlutterLoader = FlutterInjector.getInstance().getFlutterLoader();
  /// The Flutter engine created specifically for background execution.
  /// This is a separate instance from the main Flutter engine that handles the UI.
  /// It operates in its own isolate and doesn't share memory with the main engine.
  /// Must be properly started, registered, and torn down during background execution.
  public static engine?: FlutterEngine;
  // Used to call methods on the flutter side
  public static flutterApi?: BackgroundWorkerFlutterApi;
  /// Result returned when the background task completes. This is used to signal
  /// to the WorkManager that the task has finished, either successfully or with failure.
  public static completionHandler: Deferred<boolean> = new Deferred<boolean>();
  /// Flag to track whether the background task has completed to prevent duplicate completions
  public static isComplete = false
  public static activeRunId: number = 0;
  public static activeWorkToken?: string;
  public static startupTimeout?: number;
  public static readonly STARTUP_TIMEOUT_MS: number = 60_000;
  private TAG = "BackgroundWorker";
  public static readonly NOTIFICATION_ID = 100;
  public static workerInfo?: workScheduler.WorkInfo;

  public static backgroundWorkerBgHostApiImpl?:BackgroundWorkerBgHostApiImpl;
  public static nativeSyncApiImpl?: MessagesImplBase;
  public static localImageApiImpl?: LocalImagesImpl;
  public static remoteImageApiImpl?: RemoteImagesImpl;
  public static backgroundEngineLock?: BackgroundEngineLock;


  constructor() {
    super();
  }

  public static isActiveRun(runId: number): boolean {
    return runId === BackgroundWorker.activeRunId && !BackgroundWorker.isComplete;
  }

  public static clearStartupTimeout(): void {
    if (BackgroundWorker.startupTimeout !== undefined) {
      clearTimeout(BackgroundWorker.startupTimeout);
      BackgroundWorker.startupTimeout = undefined;
    }
  }

  public static completeRun(runId: number, success: boolean): void {
    if (!BackgroundWorker.isActiveRun(runId)) {
      return;
    }
    BackgroundWorker.backgroundWorkerBgHostApiImpl?.complete(success);
  }

  private registerPlugins(flutterEngine: FlutterEngine) {
    BackgroundWorkerLog.info('Plugin registration started');
    // workScheduler cannot safely import UI/video plugins such as native_video_player
    // on HarmonyOS 6, so the background engine uses a dedicated registrant.
    BackgroundGeneratedPluginRegistrant.registerWith(flutterEngine);
    BackgroundWorkerLog.info('Generated background plugins registered');
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    BackgroundWorker.nativeSyncApiImpl = new MessagesImplBase(this.ctx.getApplicationContext());
    BackgroundWorker.localImageApiImpl = new LocalImagesImpl(this.ctx.getApplicationContext());
    BackgroundWorker.remoteImageApiImpl = new RemoteImagesImpl(this.ctx.getApplicationContext());
    const backgroundWorkerApiImpl = new BackgroundWorkerApiImpl(this.ctx.getApplicationContext());
    const connectivityApiImpl = new ConnectivityApiImpl(this.ctx.getApplicationContext());
    BackgroundWorker.backgroundEngineLock = new BackgroundEngineLock(this.ctx);
    const networkApiImpl = new NetworkApiImpl(this.ctx.getApplicationContext());

    NativeSyncApiOhos.setup(messenger, BackgroundWorker.nativeSyncApiImpl);
    BackgroundWorkerLog.info('Registered NativeSyncApiOhos');
    LocalImageApiOhos.setup(messenger, BackgroundWorker.localImageApiImpl);
    BackgroundWorkerLog.info('Registered LocalImageApiOhos');
    RemoteImageApiOhos.setup(messenger, BackgroundWorker.remoteImageApiImpl);
    BackgroundWorkerLog.info('Registered RemoteImageApiOhos');
    BackgroundWorkerFgHostApi.setup(messenger, backgroundWorkerApiImpl);
    BackgroundWorkerLog.info('Registered BackgroundWorkerFgHostApi');
    ConnectivityApi.setup(messenger, connectivityApiImpl);
    BackgroundWorkerLog.info('Registered ConnectivityApi');
    BackgroundWorkerLockApi.setup(messenger, BackgroundWorker.backgroundEngineLock);
    BackgroundWorkerLog.info('Registered BackgroundWorkerLockApi');
    NetworkApi.setup(messenger, networkApiImpl);
    BackgroundWorkerLog.info('Registered NetworkApi');
    const backgroundEngineLock = BackgroundWorker.backgroundEngineLock;
    if (backgroundEngineLock != undefined) {
      flutterEngine.getPlugins()?.add(backgroundEngineLock);
    }
    BackgroundWorkerLog.info('Plugin registration completed');
  }
  public static cancelPlugins() {
    try {
      BackgroundWorker.backgroundEngineLock?.detachFromEngine();
    } catch (_) {}
    BackgroundWorker.nativeSyncApiImpl = undefined;
    BackgroundWorker.localImageApiImpl = undefined;
    BackgroundWorker.remoteImageApiImpl = undefined;
    BackgroundWorker.backgroundEngineLock = undefined;
  }

  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    if (BackgroundWorker.workerInfo !== undefined && !BackgroundWorker.isComplete) {
      BackgroundWorkerLog.warn('Ignoring duplicate onWorkStart while a background worker is active');
      return;
    }

    BackgroundWorkerLog.beginRun();
    const runId = BackgroundWorker.activeRunId + 1;
    BackgroundWorker.activeRunId = runId;
    const workToken = workInfo.parameters?.immichBackgroundRunToken;
    BackgroundWorker.activeWorkToken = typeof workToken === "string" ? workToken : undefined;
    BackgroundWorker.clearStartupTimeout();
    BackgroundWorker.isComplete = false;
    BackgroundWorker.completionHandler = new Deferred<boolean>();
    BackgroundWorker.backgroundWorkerBgHostApiImpl = new BackgroundWorkerBgHostApiImpl(runId);
    BackgroundWorker.workerInfo = workInfo;
    BackgroundWorkerLog.info(`onWorkStart received workId=${workInfo.workId}, abilityName=${workInfo.abilityName}, runId=${runId}, hasRunToken=${BackgroundWorker.activeWorkToken !== undefined}`);
    BackgroundWorkerLog.info('Background worker run state initialized');
    try {
      const notif = new BackgroundWorkerPreferences(this.ctx).getNotificationConfig();
      BackgroundWorkerLog.info('Publishing background worker startup notification');
      BackgroundWorker.backgroundWorkerBgHostApiImpl?.showNotification(notif.title, notif.message);
    } catch (e) {
      BackgroundWorkerLog.error(`Startup notification setup failed: ${String(e)}`);
    }
    try {
      BackgroundWorkerLog.info('Constructing background FlutterEngine');
      const engine = new FlutterEngine(this.ctx, null, null, null);
      BackgroundWorker.engine = engine;
      // FlutterEngine construction alone does not attach a native shell or create
      // its plugin registry. Match FlutterEngineGroup's init-before-run sequence.
      BackgroundWorkerLog.info('Calling FlutterEngine.init');
      engine.init(this.ctx, null, false);
      BackgroundWorkerLog.info('FlutterEngine.init completed');
      this.registerPlugins(engine);

      const messenger = engine.dartExecutor.getBinaryMessenger();
      BackgroundWorkerLog.info('Creating Flutter/native background message channels');
      BackgroundWorker.flutterApi = new BackgroundWorkerFlutterApi(messenger);
      BackgroundWorkerLog.attach(new MethodChannel(messenger, 'immich/background_worker_diagnostics'));
      BackgroundWorkerBgHostApi.setup(
        messenger,
        BackgroundWorker.backgroundWorkerBgHostApiImpl,
      );

      // Cache the engine similar to Android, so we can detect a running worker.
      try {
        FlutterEngineCache.getInstance().put(BackgroundWorkerApiImpl.ENGINE_CACHE_KEY, engine);
        BackgroundWorkerLog.info('Background FlutterEngine cached');
      } catch (e) {
        BackgroundWorkerLog.warn(`Failed to cache background FlutterEngine: ${String(e)}`);
      }

      // Do not leave a WorkScheduler job and notification active if Dart never
      // completes its initialization handshake.
      BackgroundWorker.startupTimeout = setTimeout(() => {
        if (!BackgroundWorker.isActiveRun(runId)) {
          return;
        }
        BackgroundWorkerLog.error(`Timed out after ${BackgroundWorker.STARTUP_TIMEOUT_MS}ms waiting for Dart initialization handshake`);
        BackgroundWorker.completeRun(runId, false);
      }, BackgroundWorker.STARTUP_TIMEOUT_MS);

      BackgroundWorkerLog.info('Resolving Dart entrypoint bundle path');
      const entrypoint = new DartEntrypoint(
        this.loader.findAppBundlePath(),
        "package:immich_mobile/domain/services/background_worker.service.dart",
        "backgroundSyncNativeEntrypoint"
      );
      BackgroundWorkerLog.info('Executing background Dart entrypoint backgroundSyncNativeEntrypoint');
      engine.dartExecutor.executeDartEntrypoint(entrypoint);
    } catch (e) {
      BackgroundWorkerLog.error(`Failed to start background FlutterEngine: ${String(e)}`);
      BackgroundWorker.completeRun(runId, false);
    }
  }

  onWorkStop(workInfo: workScheduler.WorkInfo) {
    BackgroundWorkerLog.info(`onWorkStop received workId=${workInfo.workId}, abilityName=${workInfo.abilityName}`);
    const workToken = workInfo.parameters?.immichBackgroundRunToken;
    const runId = BackgroundWorker.activeRunId;
    if (workToken !== BackgroundWorker.activeWorkToken) {
      BackgroundWorkerLog.info('Ignoring onWorkStop because its run token does not match the active run');
      return;
    }
    if (!BackgroundWorker.isActiveRun(runId)) {
      BackgroundWorkerLog.info(`Ignoring onWorkStop because runId=${runId} is no longer active`);
      return;
    }
    BackgroundWorkerLog.warn(`Active runId=${runId} was stopped by WorkScheduler; requesting Dart cancellation`);
    BackgroundWorker.clearStartupTimeout();

    // 尝试调用 FlutterApi cancel
    if (BackgroundWorker.flutterApi != null) {
      try {
        BackgroundWorker.flutterApi.cancel(new BackgroundWorkerReply(runId, false));
      } catch (e) {
        BackgroundWorkerLog.error(`Flutter cancel callback failed: ${String(e)}`);
        // 出错也保证失败
        BackgroundWorker.completeRun(runId, false);
      }
    }

    // 5 秒后 fallback，保证任务完成
    setTimeout(() => {
      BackgroundWorkerLog.warn(`Dart cancellation fallback expired for runId=${runId}`);
      BackgroundWorker.completeRun(runId, false);
    }, 5000);
  }
}

class BackgroundWorkerBgHostApiImpl extends BackgroundWorkerBgHostApi {
  private TAG = "BackgroundWorker";
  private readonly runId: number;

  constructor(runId: number) {
    super();
    this.runId = runId;
  }

  /**
   * Called by the Flutter side when it has finished initialization and is ready to receive commands.
   * Routes the appropriate task type (refresh or processing) to the corresponding Flutter method.
   * This method acts as a bridge between the native Android background task system and Flutter.
   */
  override onInitialized() {
    if (!BackgroundWorker.isActiveRun(this.runId)) {
      BackgroundWorkerLog.warn(`Ignoring Dart initialization handshake for inactive runId=${this.runId}`);
      return;
    }
    BackgroundWorkerLog.info(`Received background Dart initialization handshake for runId=${this.runId}`);
    BackgroundWorker.clearStartupTimeout();
    try {
      const flutterApi = BackgroundWorker.flutterApi;
      if (flutterApi === undefined) {
        throw new Error("Background Flutter API is unavailable after initialization");
      }
      BackgroundWorkerLog.info(`Dispatching Dart background upload callback for runId=${this.runId}`);
      flutterApi.onAndroidUpload(20, new BackgroundWorkerUploadReply(this.runId));
    } catch (e) {
      BackgroundWorkerLog.error(`Failed to dispatch Dart background upload callback: ${String(e)}`);
      this.handleHostResult(false);
    }
  }

  showNotification(title: string, content: string): void {
    const request: notificationManager.NotificationRequest = {
      id: BackgroundWorker.NOTIFICATION_ID,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title ?? '',
          text: content ?? '',
        },
      },
      notificationSlotType: notificationManager.SlotType.OTHER_TYPES,
    };

    try {
      notificationManager.publish(request).then(() => {
        BackgroundWorkerLog.info('Background worker notification published');
      }).catch((e: Object) => {
        BackgroundWorkerLog.error(`Publishing background worker notification failed: ${String(e)}`);
      });
    } catch (e) {
      BackgroundWorkerLog.error(`Publishing background worker notification failed: ${String(e)}`);
    }
  }

  override close() {
    if (!BackgroundWorker.isActiveRun(this.runId)) {
      return;
    }
    BackgroundWorker.clearStartupTimeout();

    if (BackgroundWorker.flutterApi != null) {
      try {
        BackgroundWorker.flutterApi.cancel(new BackgroundWorkerReply(this.runId, false));
      } catch (e) {
        BackgroundWorkerLog.error(`Flutter cancel callback failed during close: ${String(e)}`);
        BackgroundWorker.completeRun(this.runId, false);
      }
    }

    setTimeout(() => {
      BackgroundWorkerLog.warn(`Close fallback expired for runId=${this.runId}`);
      BackgroundWorker.completeRun(this.runId, false);
    }, 5000);

  }

  /**
   * Handles the result from Flutter API calls and determines the success/failure status.
   * Converts Flutter's Result type to a simple boolean success indicator for task completion.
   *
   * - Parameter result: The result returned from a Flutter API call
   */
  private handleHostResult(result: boolean) {
    if (!BackgroundWorker.isActiveRun(this.runId)) {
      return;
    }
    if (result) {
      BackgroundWorkerLog.info(`Dart background runId=${this.runId} completed and requested success`);
      this.complete(true);
      return;
    }

    BackgroundWorkerLog.error(`Dart background runId=${this.runId} reported failure`);
    this.complete(false);
  }

  /**
   * Cleans up resources by destroying the Flutter engine context and invokes the completion handler.
   * This method ensures that the background task is marked as complete, releases the Flutter engine,
   * and notifies the caller of the task's success or failure. This is the final step in the
   * background task lifecycle and should only be called once per task instance.
   *
   * - Parameter success: Indicates whether the background task completed successfully
  */
  public complete(success: boolean) {
    if (!BackgroundWorker.isActiveRun(this.runId)) {
      return;
    }

    BackgroundWorkerLog.info(`Completing background runId=${this.runId}, success=${success}`);
    BackgroundWorker.isComplete = true;
    BackgroundWorker.clearStartupTimeout();
    const workerInfo = BackgroundWorker.workerInfo;
    if (workerInfo != undefined) {
      try {
        workScheduler.stopWork(workerInfo, false);
        BackgroundWorkerLog.info(`Stopped WorkScheduler workId=${workerInfo.workId}`);
      } catch (e) {
        BackgroundWorkerLog.warn(`Stopping WorkScheduler workId=${workerInfo.workId} failed: ${String(e)}`);
      }
      BackgroundWorker.workerInfo = undefined;
    }
    BackgroundWorker.activeWorkToken = undefined;
    BackgroundWorker.cancelPlugins();
    const engine = BackgroundWorker.engine;
    BackgroundWorker.engine = undefined;
    BackgroundWorker.flutterApi = undefined;
    try {
      engine?.destroy();
      BackgroundWorkerLog.info('Background FlutterEngine destroyed');
    } catch (e) {
      BackgroundWorkerLog.error(`Destroying background FlutterEngine failed: ${String(e)}`);
    }
    try {
      notificationManager.cancel(BackgroundWorker.NOTIFICATION_ID).then(() => {
        BackgroundWorkerLog.info('Background worker notification cancelled');
      }).catch((e: Object) => {
        BackgroundWorkerLog.warn(`Cancelling background worker notification failed: ${String(e)}`);
      });
    } catch (e) {
      BackgroundWorkerLog.warn(`Cancelling background worker notification failed: ${String(e)}`);
    }
    try {
      FlutterEngineCache.getInstance().remove(BackgroundWorkerApiImpl.ENGINE_CACHE_KEY);
      BackgroundWorkerLog.info('Background FlutterEngine cache entry removed');
    } catch (e) {
      BackgroundWorkerLog.warn(`Removing background FlutterEngine cache entry failed: ${String(e)}`);
    }

    BackgroundWorker.completionHandler.resolve(success);
    BackgroundWorker.backgroundWorkerBgHostApiImpl = undefined;
    BackgroundWorkerLog.info(`Background runId=${this.runId} cleanup completed`);
  }
}
