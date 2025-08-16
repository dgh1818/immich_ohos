import { EnqueueItem } from "./HoldingQueue";
import { common } from "@kit.AbilityKit";
import { TaskWorker } from "./TaskWorker";
import { worker } from "@kit.ArkTS";
import { UpdateNotificationWorker } from "./UpdateNotificationWorker";
import { TaskStatus } from "./Models";

/**
 * Notification configuration object
 *
 * [running] is the notification used while the task is in progress
 * [complete] is the notification used when the task completed
 * [error] is the notification used when something went wrong,
 * including pause, failed and notFound status
 */
@Sendable
class TaskNotification {
  title: string;
  body: string;

  constructor(title: string, body: string) {
    this.title = title;
    this.body = body;
  }

  toString(): string {
    return `Notification(title='${this.title}', body='${this.body}')`;
  }
}


@Sendable
export class NotificationConfig {
  running?: TaskNotification;
  complete?: TaskNotification;
  error?: TaskNotification;
  paused?: TaskNotification;
  progressBar: boolean;
  tapOpensFile: boolean;
  groupNotificationId: string;

  constructor(
    running?: TaskNotification,
    complete?: TaskNotification,
    error?: TaskNotification,
    paused?: TaskNotification,
    progressBar: boolean = false,
    tapOpensFile: boolean = false,
    groupNotificationId: string = ""
  ) {
    this.running = running;
    this.complete = complete;
    this.error = error;
    this.paused = paused;
    this.progressBar = progressBar;
    this.tapOpensFile = tapOpensFile;
    this.groupNotificationId = groupNotificationId;
  }

  toString(): string {
    return `NotificationConfig(running=${this.running}, complete=${this.complete}, error=${this.error}, paused=${this.paused}, progressBar=${this.progressBar}, tapOpensFile=${this.tapOpensFile}, groupNotificationId=${this.groupNotificationId})`;
  }
}

export class NotificationService {
  static registerEnqueue(item: EnqueueItem, success: Boolean) {
    let notificationConfigJsonString = item.notificationConfigJsonString

    if (notificationConfigJsonString == undefined) {
      return;
    }
    let notificationConfig = JSON.parse(notificationConfigJsonString) as NotificationConfig
    let groupNotificationId = notificationConfig.groupNotificationId
    if (groupNotificationId.length != 0) {
      // update the notification status for this task (requires a worker because we are
      // not within a worker when this function is called)
      NotificationService.createUpdateNotificationWorker(
        item.context,
        JSON.stringify(item.task),
        notificationConfigJsonString,
        success ? TaskStatus.enqueued : TaskStatus.failed
      )
    }
  }

  static UpdateNotificationWorker: worker.ThreadWorker;

  static createUpdateNotificationWorker(
    context: common.UIAbilityContext,
    taskJson: string,
    notificationConfigJson?: string,
    taskStatusOrdinal?: number
  ) {
    // create dummy TaskWorker
    // dataBuilder = new Map<string,string>();
    let dataBuilder: Map<string, string | number | common.UIAbilityContext> =
      new Map<string, string | number | common.UIAbilityContext>();
    dataBuilder.set(TaskWorker.keyTask, taskJson)

    if (notificationConfigJson != undefined) {
      dataBuilder.set(TaskWorker.keyNotificationConfig, notificationConfigJson)
    }

    if (taskStatusOrdinal != undefined) {
      dataBuilder.set(UpdateNotificationWorker.keyTaskStatusOrdinal, taskStatusOrdinal)
    }

    if (context != undefined) {
      dataBuilder.set('uiContext', context)
    }


    NotificationService.UpdateNotificationWorker = new worker.ThreadWorker('./UpdateNotificationWorker');
    NotificationService.UpdateNotificationWorker.postMessageWithSharedSendable(dataBuilder);
  }
}

enum NotificationType {
    running,
    complete,
    error,
    paused,
    canceled
}
