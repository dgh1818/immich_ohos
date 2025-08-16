import { collections, MessageEvents, taskpool, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS'
import { SendableObject } from './BackgroundServicePlugin'
import { ExceptionType, Task, TaskException, TaskProgressUpdate, TaskStatus, TaskStatus_fun } from './Models'
import dataPreferences from '@ohos.data.preferences'
import { common } from '@kit.AbilityKit'
import BDPlugin from './BDPlugin2'
import { WiFi } from './WIFI'
import { EnqueueItem, HoldingQueue } from './HoldingQueue'
import { NotificationConfig } from './Notifications'
import {BackgroundPost, QueueService} from './QueueService'
import { systemDateTime } from '@kit.BasicServicesKit'
import {TaskStatusUpdate,TaskStatusUpdatePara} from './Models'
import { workScheduler } from '@kit.BackgroundTasksKit'
import { Callbacks } from './Callbacks'

async function getTaskMap(prefs: dataPreferences.Preferences): Promise<Map<string, Task>> {
  await BDPlugin.prefsLock.lockAsync<Map<string,Task>>(() => {
  let tasksMapJson:string = prefs.getSync(BDPlugin.keyTasksMap, "{}") as string?? "{}" as string
  return JSON.parse(tasksMapJson) as Map<string,Task>


  // 执行某些操作
});
return new Map<string,Task>();
}

export class TaskWorker {
  static readonly TAG = "TaskWorker"
  readonly chunkGroup = "chunk"
  readonly keyTask = "Task"
  readonly keyNotificationConfig = "notificationConfig"
  readonly keyResumeDataData = "tempFilename"
  readonly keyStartByte = "startByte"
  readonly keyETag = "eTag"
  readonly bufferSize = 2 << 12;
  readonly taskTimeoutMillis: number = 9 * 60 * 1000 // 9 minutes
  static keyTask: string
  static keyNotificationConfig: string
  static keyResumeDataData: string
  static keyStartByte: string
  static keyETag: string
  public task?: Task
  public applicationContext?: common.UIAbilityContext
  public notificationConfigJsonString?: string
  public notificationConfig?: NotificationConfig
  public notificationId: number = 0
  static taskException?: TaskException
  static keyTasksMap = "com.bbflight.background_downloader.taskMap.v2"

  //public workerParams?:Map<string,ESObject>

  constructor(applicationContext?: common.UIAbilityContext) {
    //constructor(applicationContext?:common.UIAbilityContext,workerParams?:Map<string,ESObject>) {
    this.applicationContext = applicationContext
    //this.workerParams = workerParams
  }

  /**
   * Processes a progress update for the [task]
   *
   * Sends progress update via the background channel to Flutter, if requested
   */
  // public processProgressUpdate(
  //   task: Task, progress: number, prefs: dataPreferences.Preferences, expectedFileSize: number = -1,
  //   downloadSpeed: number = -1.0, timeRemaining: number = -1000
  // ) {
  //   if (task.providesProgressUpdates()) {
  //     postOnBackgroundChannel(new BackgroundPost(
  //       "progressUpdate", task,
  //       Map<string,string>(progress, expectedFileSize, downloadSpeed, timeRemaining),
  //       onFail =
  //         {
  //           // unsuccessful post, so store in local prefs
  //           Log.d(TAG, "Could not post progress update -> storing locally")
  //           storeLocally(
  //           BDPlugin.keyProgressUpdateMap,
  //           task.taskId,
  //           Json.encodeToString(
  //           TaskProgressUpdate(
  //             task,
  //             progress,
  //             expectedFileSize
  //           )
  //           ),
  //           prefs
  //           )
  //         })
  //   }
  // }
  static postOnBackgroundChannel(
    method: string, task: Task, arg: ESObject, onFail?: () => Promise<void>
  ) {
    let bgPost = new BackgroundPost(task, method, arg, onFail)
    QueueService.postOnBackgroundChannel(bgPost)
  }

  /**
   * Processes a progress update for the [task]
   *
   * Sends progress update via the background channel to Flutter, if requested
   */
  public static processProgressUpdate(
    task: Task, progress: number, prefs: dataPreferences.Preferences, expectedFileSize: number = -1,
    downloadSpeed: number = -1.0, timeRemaining: number = -1000
  ) {
    if (task.providesProgressUpdates()) {
      TaskWorker.postOnBackgroundChannel(
        "progressUpdate", task,
        [progress, expectedFileSize, downloadSpeed, timeRemaining],
        async () => {
          // unsuccessful post, so store in local prefs
          console.error(TaskWorker.TAG, "Could not post progress update -> storing locally")
          this.storeLocally(
            BDPlugin.keyProgressUpdateMap,
            task.taskId,
            JSON.stringify(new TaskProgressUpdate(
              task,
              progress,
              expectedFileSize
            )),
            prefs
          )
        })
    }
  }

  static storeLocally(
    prefsKey: string,
    taskId: string,
    item: string,
    prefs: dataPreferences.Preferences
  ) {
    BDPlugin.prefsLock.lockAsync(() => {
      let jsonString = prefs.getSync(prefsKey, "") as string
      let mapByTaskId = JSON.parse(jsonString) as Map<string, string>
      mapByTaskId[taskId] = item
      prefs.putSync(prefsKey, JSON.stringify(mapByTaskId));

    })

  }

  /** Return true if we can send a cancellation for this task
   *
   * Cancellation can only be sent if it wasn't already sent by the [BDPlugin]
   *  in the cancelTasksWithId method.  Side effect is to clean out older cancellation entries
   * from the [BDPlugin.cancelUpdateSentForTaskId]
   */
  static canSendCancellation(task: Task): boolean {
    let now = systemDateTime.getTime(false)
    let filtered: Map<string, number> = new Map();
    BDPlugin.cancelUpdateSentForTaskId.forEach((value, key) => {
      if (now - value < 3000) {
        filtered.set(key, value);
      }
    });
    BDPlugin.cancelUpdateSentForTaskId = filtered;

    return !BDPlugin.cancelUpdateSentForTaskId.has(task.taskId)
  }

  /** Return the map of tasks stored in preferences */


  static async processStatusUpdate(
    task: Task,
    status: TaskStatus,
    prefs: dataPreferences.Preferences,
    taskException?: TaskException,
    responseBody?: string,
    responseHeaders?: Map<string, string>,
    responseStatusCode?: number,
    mimeType?: string,
    charSet?: string,
    context?: common.UIAbilityContext) {

    if (BDPlugin.tasksToReEnqueue.delete(task)) {
      if (status == TaskStatus.paused || status == TaskStatus.canceled || status == TaskStatus.failed) {
        WiFi.reEnqueue(
          new EnqueueItem(
            context,
            task,
            BDPlugin.notificationConfigJsonStrings.get(task.taskId),
            BDPlugin.localResumeData.get(task.taskId)
          )
        )
        if (BDPlugin.tasksToReEnqueue.size == 0) {
          WiFi.reEnqueue(undefined) // signal end of batch
        }
        return
      }

      // Normal status update

      // Check if the task was 'programmatically' canceled, in which case a TaskStatus.failed may be
      // incorrectly generated by the WorkManager, so we change it to 'canceled'
      let modifiedStatus: TaskStatus =
        BDPlugin.canceledTaskIds.has(task.taskId) ? TaskStatus.canceled : status
      //TaskStatus.failed
      let retryNeeded = modifiedStatus as number == TaskStatus.failed && task.retriesRemaining > 0
      let canSendStatusUpdate = true

      switch (modifiedStatus) {
        case TaskStatus.complete:
          TaskWorker.processProgressUpdate(task, 1.0, prefs);
          break;
        case TaskStatus.failed as number:
          if (!retryNeeded) {
            TaskWorker.processProgressUpdate(task, -1.0, prefs)
          }
          break;
        case TaskStatus.canceled:
          canSendStatusUpdate = TaskWorker.canSendCancellation(task)
          if (canSendStatusUpdate) {
            BDPlugin.cancelUpdateSentForTaskId[task.taskId] = systemDateTime.getTime(false)
            TaskWorker.processProgressUpdate(task, -2.0, prefs)
          }
          break;
        case TaskStatus.notFound:
          TaskWorker.processProgressUpdate(task, -3.0, prefs)
          break;
        case TaskStatus.paused as number:
          TaskWorker.processProgressUpdate(task, -5.0, prefs)
          break;
        default:
          break;
      }


      let para1: TaskStatusUpdatePara = {
        task: task,
        taskStatus: modifiedStatus,
        exception: modifiedStatus == TaskStatus.failed as number ?
          TaskWorker.taskException ?? new TaskException(ExceptionType.general) : undefined,
        responseBody: responseBody,
        responseHeaders: new Map<string, string>(Array.from(responseHeaders.entries())
          .filter(([_, v]) => v !== undefined)),
        mimeType: mimeType,
        charSet: charSet
      }
      let para2: TaskStatusUpdatePara = {
        task: task,
        taskStatus: modifiedStatus,
        exception: undefined,
        responseBody: undefined,
        responseHeaders: undefined,
        mimeType: undefined,
        charSet: undefined
      }
      let taskStatusUpdate =
        TaskStatus_fun.isFinalState(modifiedStatus) ? new TaskStatusUpdate(para1) : new TaskStatusUpdate(para2)

      if (canSendStatusUpdate && (task.providesStatusUpdates() || retryNeeded)) {
        let arg = taskStatusUpdate.argList
        TaskWorker.postOnBackgroundChannel("statusUpdate", task, arg, async () => {
          // unsuccessful post, so store in local prefs
          console.error(TaskWorker.TAG, "Could not post status update -> storing locally")
          TaskWorker.storeLocally(
            BDPlugin.keyStatusUpdateMap,
            task.taskId,
            JSON.stringify(taskStatusUpdate),
            prefs
          )
        })
      }

      // if task is in final state, cancel the WorkManager job (if failed),
      // remove task from persistent storage, clean up references to taskId
      // and invoke the onTaskFinishedCallback if necessary
      if (TaskStatus_fun.isFinalState(modifiedStatus)) {
        if (modifiedStatus == TaskStatus.failed as number) {
          // Cancel the WorkManager job.
          // This is to avoid the WorkManager restarting a job that was
          // canceled because job constraints are violated (e.g. network unavailable)
          // We want to manage cancellation ourselves, so we cancel the job

          let workManager = await workScheduler.obtainAllWorks();

          for (let i = 0; i < workManager.length; i++) {
            if (workManager[i].workId == parseInt(task.taskId)) {
              try {
                workScheduler.stopWork(workManager[i], false);
              } catch (e) {
                console.error(
                  BDPlugin.TAG,
                  "Could not kill task wih id ${task.taskId} in operation: $operation"
                )
              }
            }
          }
        }
        BDPlugin.prefsLock.lockAsync<void>(async () => {
          let tasksMap = await getTaskMap(prefs)
          tasksMap.delete(task.taskId)
          prefs.putSync(BDPlugin.keyTasksMap, JSON.stringify(tasksMap))

          // 执行某些操作
        });

        QueueService.cleanupTaskId(task.taskId)
        if (task.options?.hasOnFinishCallback() == true) {
          Callbacks.invokeOnTaskFinishedCallback(context, taskStatusUpdate)
        }
      }
    }
  }
}

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

workerPort.onmessage = (e: MessageEvents) => {
  let obj: collections.Map<string, string> = e.data;
  console.info("sendable obj is: ");


}






