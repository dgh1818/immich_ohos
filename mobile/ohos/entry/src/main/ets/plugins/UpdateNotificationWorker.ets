import { common, sendableContextManager } from '@kit.AbilityKit'
import { collections, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { Task, TaskStatus } from './Models';
import { TaskWorker } from './TaskWorker';
import { hash } from '@kit.CoreFileKit';
import { notificationManager } from '@kit.NotificationKit';
import { NotificationConfig, NotificationService, NotificationType } from './Notifications';
import BDPlugin from './BDPlugin2';

/**
 * Worker that updates the notification for a task, given a
 * NotificationConfig and a TaskStatus.
 *
 * Used to update a task notification initiated from the Dart side, when
 * no actual TaskWorker is active for the task, e.g. when failing for the
 * last time on retry.  We need a [TaskWorker] in order to call the
 * [NotificationService] to update the associated notification.
 *
 * Note this implementation is only valid for two situations:
 * - taskStatus is null -> deletes the notification
 * - taskStatus is TaskStatus.failed -> displays error notification if needed
 */
export class UpdateNotificationWorker extends TaskWorker {
  // (applicationContext: common.UIAbilityContext, workerParams: WorkerParameters) :
  // TaskWorker(applicationContext, workerParams)
  // private applicationContext?:common.UIAbilityContext
  // private workerParams?:Map<string,ESObject>
  static readonly keyTaskStatusOrdinal = "taskStatusOrdinal"


  constructor(applicationContext: common.UIAbilityContext) {
    //constructor(applicationContext: common.UIAbilityContext,workerParams: Map<string,ESObject>) {
    super(applicationContext);

    this.applicationContext = applicationContext;

  }

  //@Concurrent
  // public updateNotification(task: Task, notificationType: NotificationType, notificationConfig?: NotificationConfig) {
  //

  //}


}

const workerPort = worker.workerPort;

let Worker_impl: UpdateNotificationWorker;
let uiContext: common.UIAbilityContext


workerPort.onmessage = (e: MessageEvents) => {
  let inputData: collections.Map<string, string> = e.data;

  console.info("sendable obj is: ");



  switch (e.data.command) {
    case 'do_work':
      uiContext = e.data.uiContext;
      Worker_impl = new UpdateNotificationWorker(uiContext)
      Worker_impl.task = JSON.parse(e.data.get('keyTask')) as Task
      Worker_impl.notificationConfigJsonString = e.data.get('keyNotificationConfig') as string
      uiContext = sendableContextManager.convertToUIAbilityContext(e.data.get('uiContext') as sendableContextManager.SendableContext)
      Worker_impl.notificationConfig = Worker_impl.notificationConfigJsonString != undefined ?
      JSON.parse(Worker_impl.notificationConfigJsonString) : undefined
      let taskStatusOrdinal: number = e.data.get('keyTaskStatusOrdinal') as number ?? -1;
      hash.hash(Worker_impl.task.taskId, 'sha1').then((hash_result: string) => {
        Worker_impl.notificationId = parseInt(hash_result);
      })

      if (taskStatusOrdinal == -1) {
        // delete notification
        notificationManager.cancel(Worker_impl.notificationId);
      } else {
        // update notification for this taskStatus
        let taskStatus = taskStatusOrdinal as TaskStatus
        Notifications.updateNotification(uiContext, taskStatus)
      }


  }


}
