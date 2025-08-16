import { common } from "@kit.AbilityKit";
import BDPlugin from "./BDPlugin2";
import { ResumeData, Task, TaskStatus } from "./Models";
import { TaskWorker } from "./TaskWorker";
import { preferences } from "@kit.ArkData";
import { Queue } from "@kit.ArkTS";
import { NotificationService } from "./Notifications";

/**
 * Queue that holds [EnqueueItem] items before they are actually enqueued as a WorkManager job
 *
 * Configure [maxConcurrent], [maxConcurrentByHost] and [maxConcurrentByGroup] to limit which items
 * can be enqueued simultaneously.
 *
 * Call:
 * [add] to add an [EnqueueItem]
 * [taskFinished] for all tasks that finish, so we may start a new one
 * [cancelAllTasks] to empty the queue (sends status updates)
 * [cancelTasksWithIds] to remove specific tasks (sends status updates)
 * [allTasks] for a list of [Task] matching a group
 * [taskForId] to get the task for a specific taskId
 */
export class HoldingQueue {
  public maxConcurrent: number = 1 << 20;
  public maxConcurrentByHost: number = 1 << 20;
  public maxConcurrentByGroup: number = 1 << 20;
  public hostByTaskId:Map<string, string> = new Map<string, string>()
  public enqueuedTaskIds = new Array<String>()

  private concurrent:number = 0;
  private concurrentByHost = new Map<string, number>();
  private concurrentByGroup = new Map<string, number>();

  static taskFinishedQueue = new Queue<Task>();

  public static taskFinished(task: Task) {
    HoldingQueue.taskFinishedQueue.add(task);

  }

  //private queue = PriorityBlockingQueue<EnqueueItem>()
  //private val taskFinishedQueue = Channel<Task>(capacity = Channel.UNLIMITED)


  // private var job: Job? = null // timer job
  // private val scope = CoroutineScope(Dispatchers.Default)
  // private val processSignal = Channel<Unit>(Channel.UNLIMITED)
  // val stateMutex = Mutex()
}

/**
 * Holds data related to enqueueing a task
 *
 * Used in the context of changing the RequireWiFi setting (where tasks need to be re-enqueued)
 * and in the context of the [HoldingQueue]
 */
export class EnqueueItem {
  context: common.UIAbilityContext;
  task: Task;
  notificationConfigJsonString?: string;
  resumeData?: ResumeData;
  plugin?: BDPlugin;
  created: Date;

  constructor(
    context: common.UIAbilityContext,
    task: Task,
    notificationConfigJsonString?: string,
    resumeData?: ResumeData,
    plugin?: BDPlugin,
    created: Date = new Date()
  ) {
    this.context = context;
    this.task = task;
    this.notificationConfigJsonString = notificationConfigJsonString;
    this.resumeData = resumeData;
    this.plugin = plugin;
    this.created = created;
  }


  /**
   * Execute the re-enqueue after an appropriate delay
   * @param afterDelayMillis minimal延迟（ms）
   */
  async enqueue(afterDelayMillis: number = 1000): Promise<void> {
    try {
      const timeSinceCreatedMillis = Date.now() - this.created.getTime();
      // if (timeSinceCreatedMillis < afterDelayMillis) {
      //   await sleep(afterDelayMillis - timeSinceCreatedMillis);
      // }

      // 假定 BDPlugin.doEnqueue 在 arkts 中也是个 async 函数并返回 boolean
      const success = await BDPlugin.doEnqueue(
        this.context,
        this.task,
        this.notificationConfigJsonString,
        this.resumeData,
        afterDelayMillis,
        this.plugin,
      );

      if (!success) {
        console.warn(
          `Delayed or retried enqueue failed for taskId ${this.task.taskId}`
        );

        // 按原 Kotlin 逻辑调用 TaskWorker.processStatusUpdate
        // 这里假定 TaskWorker.processStatusUpdate 在 ArkTS 中也存在并接受类似参数

        let options: preferences.Options = { name: 'DEFAULT' };
        let defaultPref = preferences.getPreferencesSync(this.context,options);
        //(BDPlugin.uiContext!, options);

        TaskWorker.processStatusUpdate(
          this.task,
          TaskStatus.failed, // 假定 TaskStatus 在 arkts 中有对应值
          defaultPref, // 占位
          // taskException: {
          //   type: ExceptionType.general,
          //   description: "Delayed or retried enqueue failed",
          //   httpResponseCode: -1,
          // },
          this.context,
        ); //需要改成后台

        // 如果有持有队列，通知其任务完成（占位调用）
        if (BDPlugin.holdingQueue) {
          HoldingQueue.taskFinished(this.task);

        }

        NotificationService.registerEnqueue

        // 通知注册重试失败（占位）
        if (typeof NotificationService?.registerEnqueue === "function") {
          NotificationService.registerEnqueue(this, false);
        }
      }

      // 等一点点，模拟 Kotlin 里的 delay(20)
      //await sleep(20);
    } catch (err) {
      // 这里捕获并记录异常，避免未捕获的 promise 错误
      console.error("enqueue error:", err);
    }
  }

  /**
   * 比较函数：先按 priority，随后按 creationTime
   * 返回负数表示 this 优先级更高（排在前面）
   */
  compareTo(other: EnqueueItem): number {
    if (this.task.priority !== other.task.priority) {
      // 假设 priority 是数字，较小或较大取决于你的优先级定义
      return this.task.priority - other.task.priority;
    }
    return (this.task.creationTime ?? 0) - (other.task.creationTime ?? 0);
  }
}
