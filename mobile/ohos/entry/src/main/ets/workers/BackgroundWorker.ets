import { workScheduler, WorkSchedulerExtensionAbility } from "@kit.BackgroundTasksKit";
import {
  DartExecutor,
  FlutterCallbackInformation,
  FlutterEngine,
  FlutterInjector,
  FlutterLoader,
  Reply,
} from "@ohos/flutter_ohos";
import { BackgroundWorkerBgHostApi, BackgroundWorkerFlutterApi } from "./BackgroundWorker.g";
import dataPreferences from '@ohos.data.preferences'
import preferences from "@ohos.data.preferences";
import { BackgroundWorkerApiImpl } from "./BackgroundWorkerApiImpl";
import EntryAbility from "../entryability/EntryAbility";

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
  public static mainAbility?:EntryAbility;

  public static backgroundWorkerBgHostApiImpl?:BackgroundWorkerBgHostApiImpl;


  constructor() {
    super();
    if (!this.loader.initialized) {
      this.loader.startInitialization(this.ctx);
    }
  }

  onWorkStart(workInfo: workScheduler.WorkInfo) {
    BackgroundWorker.backgroundWorkerBgHostApiImpl = new BackgroundWorkerBgHostApiImpl();
    this.context.getApplicationContext();
    BackgroundWorker.workerInfo = workInfo;
    console.info(`onWorkStart, workInfo = ${JSON.stringify(workInfo)}`);
    console.info(this.TAG, "Starting background upload worker")
    BackgroundWorker.mainAbility = new EntryAbility();

    this.loader.ensureInitializationComplete;
    BackgroundWorker.engine = new FlutterEngine(this.ctx, null, null, null);
    BackgroundWorker.mainAbility.registerPlugins(BackgroundWorker.mainAbility.getAbility().context,BackgroundWorker.engine)

    BackgroundWorker.flutterApi =
      new BackgroundWorkerFlutterApi(BackgroundWorker.engine.dartExecutor.getBinaryMessenger())

    BackgroundWorkerBgHostApi.setup(
      BackgroundWorker.engine.dartExecutor.getBinaryMessenger(),
      BackgroundWorker.backgroundWorkerBgHostApiImpl,
    )

    return BackgroundWorker.completionHandler;

    //BackgroundWorker.engine.dartExecutor.executeDartEntrypoint(new DartEntrypoint(this.loader.findAppBundlePath(),"package:immich_mobile/domain/services/background_worker.service.dart","backgroundSyncNativeEntrypoint"));
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

  override showNotification(title: string, content: string): void {
    ;
  }

  override close() {
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

  /**
   * Handles the result from Flutter API calls and determines the success/failure status.
   * Converts Flutter's Result type to a simple boolean success indicator for task completion.
   *
   * - Parameter result: The result returned from a Flutter API call
   */
  private handleHostResult(result: boolean) {
    workScheduler.stopWork(BackgroundWorker.workerInfo);

    if (result) {
      console.log("Background Worker finished");
    } else {
      console.error("Background Worker failed");
      throw new Error("Background Worker failed");
    }

    this.complete(result);
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
    BackgroundWorker.engine?.destroy();
    BackgroundWorker.engine=undefined;
    BackgroundWorker.flutterApi = undefined;

    // 通知完成
    BackgroundWorker.completionHandler.resolve(success);
  }
}
