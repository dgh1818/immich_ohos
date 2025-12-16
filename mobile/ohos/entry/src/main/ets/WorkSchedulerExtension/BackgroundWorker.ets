import { workScheduler, WorkSchedulerExtensionAbility } from "@kit.BackgroundTasksKit";
import {
  DartExecutor,
  FlutterCallbackInformation,
  FlutterEngine,
  FlutterEngineCache,
  FlutterInjector,
  FlutterLoader,
  Reply,
} from "@ohos/flutter_ohos";
import { BackgroundWorkerBgHostApi, BackgroundWorkerFlutterApi } from "./BackgroundWorker.g";
import dataPreferences from '@ohos.data.preferences'
import preferences from "@ohos.data.preferences";
import { BackgroundWorkerApiImpl } from "./BackgroundWorkerApiImpl";
import { notificationManager } from '@kit.NotificationKit';
import { DartEntrypoint } from '@ohos/flutter_ohos/src/main/ets/embedding/engine/dart/DartExecutor';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { BackgroundServicePlugin } from '../plugins/BackgroundServicePlugin';
import { NativeSyncApiOhos } from '../plugins/sync/Messages_ohos.g';
import { MessagesImplBase } from '../plugins/sync/MessagesImplBase';
import { MessagesImplBaseThumb } from '../plugins/Images/ThumbnailsImpl';
import { ThumbnailApi } from '../plugins/Images/Messages_ohos.g';
import { BackgroundWorkerFgHostApi } from './BackgroundWorker.g';
import { ConnectivityApi } from '../plugins/connectivity/Connectivity.g';
import { ConnectivityApiImpl } from '../plugins/connectivity/ConnectivityApiImpl';
import BackgroundEngineLock from '../plugins/Background/BackgroundEngineLock';
import { BackgroundWorkerLockApi } from '../plugins/Background/BackgroundWorkerLock.g';
import { BackgroundWorkerPreferences } from '../plugins/Background/BackgroundWorkerPreferences';
import { UIAbility } from "@kit.AbilityKit";
import { common } from '@kit.AbilityKit'

export class Deferred<T> {
  public promise: Promise<T>;
  public resolve!: (value: T | PromiseLike<T>) => void;
  public reject!: (reason?: object) => void;

  constructor() {
    this.promise = new Promise<T>((res, rej) => {
      this.resolve = res;
      this.reject = rej;
    });
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
  private TAG = "BackgroundWorker";
  public static workerInfo?: workScheduler.WorkInfo;

  public static backgroundWorkerBgHostApiImpl?:BackgroundWorkerBgHostApiImpl;
  public static nativeSyncApiImpl?: MessagesImplBase;
  public static thumbApiImpl?: MessagesImplBaseThumb;
  public static backgroundEngineLock?: BackgroundEngineLock;


  constructor() {
    super();
    if (!this.loader.initialized) {
      this.loader.startInitialization(this.ctx);
    }
  }
  private registerPlugins(flutterEngine: FlutterEngine) {
    this.ctx.getApplicationContext()
    GeneratedPluginRegistrant.registerWith(flutterEngine);
    const messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    BackgroundWorker.nativeSyncApiImpl = new MessagesImplBase(this.ctx.getApplicationContext());   //??????ability?????????y?????????
    BackgroundWorker.thumbApiImpl = new MessagesImplBaseThumb(this.ctx.getApplicationContext());
    const backgroundWorkerApiImpl = new BackgroundWorkerApiImpl(this.ctx.getApplicationContext());
    const connectivityApiImpl = new ConnectivityApiImpl(this.ctx.getApplicationContext());
    BackgroundWorker.backgroundEngineLock = new BackgroundEngineLock(this.ctx);

    NativeSyncApiOhos.setup(messenger, BackgroundWorker.nativeSyncApiImpl);
    ThumbnailApi.setup(messenger, BackgroundWorker.thumbApiImpl);
    BackgroundWorkerFgHostApi.setup(messenger, backgroundWorkerApiImpl);
    ConnectivityApi.setup(messenger, connectivityApiImpl);
    BackgroundWorkerLockApi.setup(messenger, BackgroundWorker.backgroundEngineLock);
  }
  public static cancelPlugins() {
    try {
      BackgroundWorker.backgroundEngineLock?.detachFromEngine();
    } catch (_) {}
    BackgroundWorker.nativeSyncApiImpl = undefined;
    BackgroundWorker.thumbApiImpl = undefined;
    BackgroundWorker.backgroundEngineLock = undefined;
  }

  onWorkStart(workInfo: workScheduler.WorkInfo) {
    // Reset state for each run
    BackgroundWorker.isComplete = false;
    BackgroundWorker.completionHandler = new Deferred<boolean>();
    BackgroundWorker.backgroundWorkerBgHostApiImpl = new BackgroundWorkerBgHostApiImpl();
    BackgroundWorker.workerInfo = workInfo;
    console.info(`onWorkStart, workInfo = ${JSON.stringify(workInfo)}`);
    console.info(this.TAG, "Starting background upload worker")
    try {
      const notif = new BackgroundWorkerPreferences(this.ctx).getNotificationConfig();
      BackgroundWorker.backgroundWorkerBgHostApiImpl?.showNotification(notif.title, notif.message);
    } catch (e) {
      console.error(this.TAG, 'showNotification failed', e);
    }
    // Ensure Flutter runtime is ready before creating an engine
    this.loader.ensureInitializationComplete(null);
    BackgroundWorker.engine = new FlutterEngine(this.ctx, null, null, null);
    this.registerPlugins(BackgroundWorker.engine);

    BackgroundWorker.flutterApi =
      new BackgroundWorkerFlutterApi(BackgroundWorker.engine.dartExecutor.getBinaryMessenger())

    BackgroundWorkerBgHostApi.setup(
      BackgroundWorker.engine.dartExecutor.getBinaryMessenger(),
      BackgroundWorker.backgroundWorkerBgHostApiImpl,
    )

    // Cache the engine similar to Android, so we can detect running background worker if needed
    try {
      FlutterEngineCache.getInstance().put(BackgroundWorkerApiImpl.ENGINE_CACHE_KEY, BackgroundWorker.engine);
    } catch (_) {
      // ignore cache failures
    }

    // Kick off the Dart entrypoint that runs background sync
    const entrypoint = new DartEntrypoint(
      this.loader.findAppBundlePath(),
      "package:immich_mobile/domain/services/background_worker.service.dart",
      "backgroundSyncNativeEntrypoint"
    );
    BackgroundWorker.engine.dartExecutor.executeDartEntrypoint(entrypoint);
    return BackgroundWorker.completionHandler;
  }

  onWorkStop(workInfo: workScheduler.WorkInfo) {
    console.log("About to stop BackupWorker");
    if(BackgroundWorker.isComplete) {
      return;
    }

    // 尝试调用 FlutterApi cancel
    if (BackgroundWorker.flutterApi != null) {
      try {
        BackgroundWorker.flutterApi.cancel({
          reply: () => {
            // FlutterApi 回调完成，标记失败
            BackgroundWorker.backgroundWorkerBgHostApiImpl!.complete(false);
          }
        });
      } catch (e) {
        console.error("flutterApi.cancel error:", e);
        // 出错也保证失败
        BackgroundWorker.backgroundWorkerBgHostApiImpl!.complete(false);
      }
    }

    // 5 秒后 fallback，保证任务完成
    setTimeout(() => {
      BackgroundWorker.backgroundWorkerBgHostApiImpl!.complete(false);
    }, 5000);
  }
}

class BackgroundWorkerBgHostApiImpl extends BackgroundWorkerBgHostApi {
  private TAG = "BackgroundWorker";
  /**
   * Called by the Flutter side when it has finished initialization and is ready to receive commands.
   * Routes the appropriate task type (refresh or processing) to the corresponding Flutter method.
   * This method acts as a bridge between the native Android background task system and Flutter.
   */
  override onInitialized() {
    try {
      BackgroundWorker.flutterApi!.onAndroidUpload({
        reply: () => this.handleHostResult(true)
      });
    } catch (e) {
      this.handleHostResult(false);
    }
  }

  showNotification(title: string, content: string): void {
    const request: notificationManager.NotificationRequest = {
      id: 100,
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
      notificationManager.publish(request);
    } catch (e) {
      console.error(`${this.TAG} publish notification failed`, e);
    }
  }

  override close() {
    if(BackgroundWorker.isComplete) {
      return;
    }

    if (BackgroundWorker.flutterApi != null) {
      try {
        BackgroundWorker.flutterApi.cancel({
          reply: () => {
            BackgroundWorker.backgroundWorkerBgHostApiImpl!.complete(false);
          }
        });
      } catch (e) {
        console.error("flutterApi.cancel error:", e);
        BackgroundWorker.backgroundWorkerBgHostApiImpl!.complete(false);
      }
    }

    setTimeout(() => {
      BackgroundWorker.backgroundWorkerBgHostApiImpl!.complete(false);
    }, 5000);

  }

  /**
   * Handles the result from Flutter API calls and determines the success/failure status.
   * Converts Flutter's Result type to a simple boolean success indicator for task completion.
   *
   * - Parameter result: The result returned from a Flutter API call
   */
  private handleHostResult(result: boolean) {
    if (result) {
      workScheduler.stopWork(BackgroundWorker.workerInfo);
      console.log("Background Worker finished");
      this.complete(true);
      return;
    }

    console.error("Background Worker failed");
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
    console.info(this.TAG, "About to complete BackupWorker with result:" +success)
    BackgroundWorker.isComplete = true;
    BackgroundWorker.cancelPlugins();
    BackgroundWorker.engine?.destroy();
    BackgroundWorker.engine = undefined;
    BackgroundWorker.flutterApi = undefined;

    BackgroundWorker.completionHandler.resolve(success);
  }
}
