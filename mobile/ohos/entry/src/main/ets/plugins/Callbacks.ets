import { MethodChannel } from '@ohos/flutter_ohos'
import { ArkTSUtils } from '@kit.ArkTS'
import { common } from '@kit.AbilityKit'
import { Task, TaskStatusUpdate } from './Models'

export interface Deferred<T> {
  promise: Promise<T>;
  resolve: (value: T | PromiseLike<T>) => void;
  reject: (reason?:string) => void;
}

export function createDeferred<T>(): Deferred<T> {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: string) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

export class Callbacks {

  static readonly TAG = "Callbacks"
  static callbackMethodChannel?: MethodChannel
  static methodChannelMutex:ArkTSUtils.locks.AsyncLock

  /**
   * Retrieves the [MethodChannel] used for communication with the Flutter background isolate.
   *
   * This method initializes the `MethodChannel` if it hasn't been created yet. It does so by:
   * 1. Obtaining the `callbackDispatcherRawHandle` from shared preferences.
   * 2. Creating a new [FlutterEngine] and executing the Dart callback dispatcher.
   * 3. Creating a [MethodChannel] using the engine's binary messenger.
   *
   * The initialization process happens on the UI thread to avoid potential issues.
   *
   * This method is thread-safe due to the use of a mutex.
   *
   * @param context The [Context] required for accessing resources and the UI thread.
   * @return The [MethodChannel] instance, or `null` if initialization fails.
   */
  private static async getMethodChannel(context: common.UIAbilityContext): Promise<MethodChannel> {
    Callbacks.methodChannelMutex.lockAsync<void>(async () => {
      if (Callbacks.callbackMethodChannel == undefined) {
        let methodChannelCompleter = createDeferred<MethodChannel>();
        Looper.getMainLooper()
      }

      // 执行某些操作
    });

/*



  try {
  val prefs = PreferenceManager.getDefaultSharedPreferences(context)
  val rawHandle =
    prefs.getLong(BDPlugin.keyCallbackDispatcherRawHandle, -1L)
  if (rawHandle == -1L) {
  Log.w(
  TAG,
  "getMethodChannel without registered callbackDispatcherRawHandle"
  )
  return@post
}
val flutterEngine = FlutterEngine(context, null, false)
val callbackDispatcherCallback =
  FlutterCallbackInformation.lookupCallbackInformation(rawHandle)
if (callbackDispatcherCallback == null) {
  Log.w(
    TAG,
    "invokeOnStartCallback failed to find callbackDispatcher"
  )
  return@post
}
val appBundlePath: String =
  FlutterInjector.instance().flutterLoader().findAppBundlePath()
val assets = context.assets
flutterEngine.dartExecutor.executeDartCallback(
  DartExecutor.DartCallback(
    assets,
    appBundlePath,
    callbackDispatcherCallback
  )
)
callbackMethodChannel = MethodChannel(
  flutterEngine.dartExecutor.binaryMessenger,
  "com.bbflight.background_downloader.callbacks"
)
methodChannelCompleter.complete(callbackMethodChannel)
} catch (e: Exception) {
  Log.e(TAG, "Error creating MethodChannel", e)
  methodChannelCompleter.complete(null)
}
}
return methodChannelCompleter.await() // Wait for the UI thread to finish
}
return callbackMethodChannel
}
}





  /**
   * Invokes a callback method on the Flutter side using the specified method channel.
   *
   * This function handles the asynchronous communication with Flutter, ensuring thread safety
   * and proper handling of the result. It serializes the given `task` object to JSON
   * and passes it as an argument to the Flutter method.
   *
   * @param context The Android context.
   * @param task The [Task] object to be passed to the Flutter callback, or null.
   * @param statusUpdate The [TaskStatusUpdate] object to be passed to the Flutter callback, or null.
   * @param methodName The name of the method to invoke on the Flutter side.
   * @return The updated object returned by the Flutter callback, or `null` if
   *         the task is unchanged, an error occurs, or the method channel is not available.
   */

    /*
  private async invokeCallback(
  context: common.UIAbilityContext,
  methodName: string,
  task?: Task,
  statusUpdate?: TaskStatusUpdate
  ): ESObject {
    let methodChannel = getMethodChannel(context) ?: return null
  methodChannelMutex.withLock {
  val resultingObjectAsJsonStringCompleter = CompletableDeferred<String?>()
  Handler(Looper.getMainLooper()).post {
  // Run on UI thread
  val arg = if (task != null) Json.encodeToString(task) else Json.encodeToString(
    statusUpdate
  )
  Log.i(
  TAG,
  "Invoking $methodName for taskId ${task?.taskId}"
  )
  methodChannel.invokeMethod(
  methodName,
  arg, // either task or update
  FlutterResultHandler(resultingObjectAsJsonStringCompleter)
  )
}
val objectAsJsonString = resultingObjectAsJsonStringCompleter.await()
return if (objectAsJsonString == null) null else
if (methodName == "beforeTaskStartCallback") Json.decodeFromString<TaskStatusUpdate>(
  objectAsJsonString
) else Json.decodeFromString<Task>(
  objectAsJsonString
)
}
}



  /**
   * Invoke the onTaskFinishedCallback
   */

    /*
   static async invokeOnTaskFinishedCallback(context: common.UIAbilityContext, statusUpdate: TaskStatusUpdate) {
    try {
      invokeCallback(
        context,
        "onTaskFinishedCallback",
        statusUpdate = statusUpdate
      ) as Task?
    } catch (e) {
      console.error(Callbacks.TAG, "Error in invokeOnTaskFinishedCallback", e)
    }
  }
}

*/
