import { ThreadWorkerGlobalScope } from '@kit.ArkTS'
import { Task } from './Models'
import { systemDateTime } from '@kit.BasicServicesKit'

export class QueueService {

  static scope?:ThreadWorkerGlobalScope

  static taskIdDeletionQueue = Channel<string>(capacity = Channel.UNLIMITED)
  static lastTaskIdAdditionTime: number = 0
  static readonly minTaskIdDeletionDelay: number = 2000  //ms

  static backgroundPostQueue = Channel<BackgroundPost>(capacity = Channel.UNLIMITED)

  /**
   * Post this [BackgroundPost] on the background channel
   */


  public static async postOnBackgroundChannel(bgPost: BackgroundPost) {
    QueueService.backgroundPostQueue.send(bgPost)
  }

  public static cleanupTaskId(taskId: String) {
    QueueService.lastTaskIdAdditionTime = systemDateTime.getTime(false);
    taskIdDeletionQueue.send(taskId)
  }
}

/**
 * BackgroundPost to be sent via backgroundChannel to Flutter, used in [QueueService]
 */
export class BackgroundPost{
  static task?: Task;
  static method?: string;
  static arg?: Array<number>
  static onFail?: () => Promise<void>;

  static backgroundPostQueue = Channel<BackgroundPost>(capacity = Channel.UNLIMITED);


  constructor(task?: Task,method?: string,arg?: Array<number>,onFail?: () => Promise<void>) {
    BackgroundPost.task = task;
    BackgroundPost.method = method;
    BackgroundPost.arg = arg;
    BackgroundPost.onFail = onFail;
  }

}
