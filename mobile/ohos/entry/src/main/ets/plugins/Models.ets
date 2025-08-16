import {Auth} from './Auth'
import { collections, lang, uri, url } from '@kit.ArkTS';
import { fileIo as fs } from '@kit.CoreFileKit';

export type ISendable = lang.ISendable;

@Sendable
class TaskOptions {
  beforeTaskStartRawHandle?: number;
  onTaskStartRawHandle?: number;
  onTaskFinishedRawHandle?: number;
  auth?: Auth;

  constructor(
    beforeTaskStartRawHandle?: number,
    onTaskStartRawHandle?: number,
    onTaskFinishedRawHandle?: number,
    auth?: Auth
  ) {
    this.beforeTaskStartRawHandle = beforeTaskStartRawHandle;
    this.onTaskStartRawHandle = onTaskStartRawHandle;
    this.onTaskFinishedRawHandle = onTaskFinishedRawHandle;
    this.auth = auth;
  }

  hasBeforeStartCallback(): boolean {
    return this.beforeTaskStartRawHandle != null;
  }

  hasOnStartCallback(): boolean {
    return this.onTaskStartRawHandle != null;
  }

  hasOnFinishCallback(): boolean {
    return this.onTaskFinishedRawHandle != null;
  }
}

interface Task_interface {
  taskId?: string;
  url?: string;
  urls?: collections.Array<string>;
  filename?: string;
  headers?: collections.Map<string, string>;
  httpRequestMethod?: string;
  chunks?: number;
  post?: string;
  fileField?: string;
  mimeType?: string;
  fields?: collections.Map<string, string>;
  directory?: string;
  baseDirectory?: string;
  group?: string;
  updates?: string;
  requiresWiFi?: boolean;
  retries?: number;
  retriesRemaining?: number;
  allowPause?: boolean;
  priority?: number;
  metaData?: string;
  displayName?: string;
  creationTime?: number;
  options?: TaskOptions;
  taskType?: string;
}

@Sendable
export class Task {
  taskId: string;
  url: string;
  filename: string;
  headers: collections.Map<string,string>;
  baseDirectory: string;
  group: string;
  updates: string;
  taskType: string;
  urls: collections.Array<string>;
  httpRequestMethod: string;
  chunks: number;
  post?: string;
  fileField: string;
  mimeType: string;
  fields: collections.Map<string,string>;
  directory: string;
  requiresWiFi: boolean;
  retries: number;
  retriesRemaining: number;
  allowPause: boolean;
  priority: number;
  metaData: string;
  displayName: string;
  creationTime: number;
  options?: TaskOptions;

  constructor(init?: Task_interface) {
    this.taskId = init?.taskId || Math.floor(Math.random() * 1000000).toString();
    this.url = init?.url || "";
    this.filename = init?.filename || "";
    this.headers = init?.headers || new collections.Map();
    this.baseDirectory = init?.baseDirectory || "";
    this.group = init?.group || "";
    this.updates = init?.updates || "";
    this.taskType = init?.taskType || "";
    this.urls = init?.urls || new collections.Array();
    this.httpRequestMethod = init?.httpRequestMethod || "GET";
    this.chunks = init?.chunks || 1;
    this.post = init?.post;
    this.fileField = init?.fileField || "";
    this.mimeType = init?.mimeType || "";
    this.fields = init?.fields || new collections.Map();
    this.directory = init?.directory || "";
    this.requiresWiFi = init?.requiresWiFi || false;
    this.retries = init?.retries || 0;
    this.retriesRemaining = init?.retriesRemaining || 0;
    this.allowPause = init?.allowPause || false;
    this.priority = init?.priority || 5;
    this.metaData = init?.metaData || "";
    this.displayName = init?.displayName || "";
    this.creationTime = init?.creationTime || Date.now();
    this.options = init?.options;
  }

  copyWith(params?: Task_interface): Task {
    return new Task({
      taskId: params?.taskId || this.taskId,
      url: params?.url || this.url,
      filename: params?.filename || this.filename,
      headers: params?.headers || this.headers,
      baseDirectory: params?.baseDirectory || this.baseDirectory,
      group: params?.group || this.group,
      updates: params?.updates || this.updates,
      taskType: params?.taskType || this.taskType,
      urls: params?.urls || this.urls,
      httpRequestMethod: params?.httpRequestMethod || this.httpRequestMethod,
      chunks: params?.chunks || this.chunks,
      post: params?.post || this.post,
      fileField: params?.fileField || this.fileField,
      mimeType: params?.mimeType || this.mimeType,
      fields: params?.fields || this.fields,
      directory: params?.directory || this.directory,
      requiresWiFi: params?.requiresWiFi || this.requiresWiFi,
      retries: params?.retries || this.retries,
      retriesRemaining: params?.retriesRemaining || this.retriesRemaining,
      allowPause: params?.allowPause || this.allowPause,
      priority: params?.priority || this.priority,
      metaData: params?.metaData || this.metaData,
      displayName: params?.displayName || this.displayName,
      creationTime: params?.creationTime || this.creationTime,
      options: params?.options || this.options,
    });
  }



  public providesProgressUpdates(): boolean {
    return this.updates === "progress" || this.updates === "statusAndProgress";
  }

  providesStatusUpdates(): boolean {
    return this.updates === "status" || this.updates === "statusAndProgress";
  }

  isDownloadTask(): boolean {
    return this.taskType == "DownloadTask" || this.taskType == "UriDownloadTask" ||
      this.taskType == "ParallelDownloadTask"
  }

  isUploadTask(): boolean {
    return this.taskType == "UploadTask" || this.taskType == "UriUploadTask" || this.taskType == "MultiUploadTask"
  }

  isParallelDownloadTask(): boolean {
    return this.taskType === "ParallelDownloadTask";
  }

  private isMultiUploadTask(): boolean {
    return this.taskType === "MultiUploadTask";
  }

  isDataTask(): boolean {
    return this.taskType === "DataTask";
  }

  // fileExists(path: string): boolean {
  //   // TODO: 在鸿蒙/ArkTS 平台上用合适的 API 检查文件是否存在
  //   // 这里暂时返回 false，以便使用 filePath(...) 构造路径
  //
  //   return fs.accessSync(path);
  // }

  host():string {
    try {
      let url_result = new uri.URI(this.url).host
      return url_result;
    } catch (e) {
      console.error('model:'+ "get host error");
      return "";
    }
  }


  // fs.accessSync(path);
  //
  // uri.URI('https://username:password@host:8080');

  // filePath(withFilename?: string): string {
  //   if (this.isMultiUploadTask() && !withFilename) return "";
  //   const filenameToUse = withFilename || this.filename;
  //   return `${this.baseDirectory}/${this.directory ? this.directory + "/" : ""}${filenameToUse}`;
  // }

  // withSuggestedFilename(suggestedName: string, unique: boolean = false): Task {
  //   if (!unique) {
  //     return this.copyWith({ filename: suggestedName || this.filename });
  //   }
  //   // 模拟生成唯一文件名逻辑
  //   let name = suggestedName || this.filename;
  //   let counter = 1;
  //   while (false) { /* 可以插入判断文件是否存在的逻辑 */ counter++; }
  //   return this.copyWith({ filename: name });
  // }
}

export interface ResumeDataInterface {
  task: Task;
  data: string;
  requiredStartByte: number;
  eTag?: string;
}

@Sendable
export class ResumeData {
  task: Task;
  data: string;
  requiredStartByte: number;
  eTag?: string;

  constructor(init: ResumeDataInterface) {
    this.task = init.task;
    this.data = init.data;
    this.requiredStartByte = init.requiredStartByte;
    this.eTag = init.eTag;
  }

  // 可选：实现一个 copyWith 方法，类似 Kotlin data class 的 copy
  copyWith(init: Partial<ResumeDataInterface>): ResumeData {
    return new ResumeData({
      task: init.task || this.task,
      data: init.data || this.data,
      requiredStartByte: init.requiredStartByte || this.requiredStartByte,
      eTag: init.eTag !== undefined ? init.eTag : this.eTag,
    });
  }
}

export enum RequireWiFi {
  asSetByTask,
  forAllTasks,
  forNoTasks
}


export enum TaskStatus {
  enqueued,
  running,
  complete,
  notFound,
  failed,
  canceled,
  waitingToRetry,
  paused


}

export class TaskStatus_fun {
  static nonFinal = new Set<TaskStatus>([
    TaskStatus.enqueued,
    TaskStatus.running,
    TaskStatus.waitingToRetry,
    TaskStatus.paused,
  ]);

  public static isNotFinalState(s: TaskStatus | string | null | undefined): boolean {
    if (!s) return false;
    // 如果传入的是字符串，也尝试按字符串比较
    return TaskStatus_fun.nonFinal.has(s as TaskStatus);
  }

  public static isFinalState(s: TaskStatus | string | null | undefined): boolean {
    return !TaskStatus_fun.isNotFinalState(s);
  }

  public static ordinal(s: TaskStatus): number {
    // 依据 enum 声明顺序返回 0-based 索引，等价于 Kotlin.ordinal()
    const values = s as number
    return values;
  }

  // 序列化：enum 已经是字符串了，但提供显式函数以便未来集中处
}
export interface TaskStatusUpdatePara {
  readonly task: Task;
  readonly taskStatus: TaskStatus;
  readonly exception?: TaskException | undefined;
  readonly responseBody?: string | undefined;
  readonly responseStatusCode?: number | undefined;
  readonly responseHeaders?: Map<string, string> | undefined;
  readonly mimeType?: string | undefined;
  readonly charSet?: string | undefined;
}

export class TaskStatusUpdate {
  readonly task: Task;
  readonly taskStatus: TaskStatus;
  readonly exception?: TaskException | undefined;
  readonly responseBody?: string | undefined;
  readonly responseStatusCode?: number | undefined;
  readonly responseHeaders?: Map<string, string> | undefined;
  readonly mimeType?: string | undefined;
  readonly charSet?: string | undefined;

  constructor(params: TaskStatusUpdatePara) {
    this.task = params.task;
    this.taskStatus = params.taskStatus;
    this.exception = params.exception ?? undefined;
    this.responseBody = params.responseBody ?? undefined;
    this.responseStatusCode = params.responseStatusCode ?? undefined;
    this.responseHeaders = params.responseHeaders ?? undefined;
    this.mimeType = params.mimeType ?? undefined;
    this.charSet = params.charSet ?? undefined;
  }

  /**
   * 返回用于在 backgroundChannel 上 post "statusUpdate" 的参数数组
   * 与 Kotlin 版本保持一致：failed 分支返回不同字段列表，其他分支按 isFinalState/complete/notFound 判定。
   */
  get argList(): ESObject[] {
    const ordinal = TaskStatus_fun.ordinal(this.taskStatus);

    if (this.taskStatus === TaskStatus.failed) {
      return [
        ordinal,
        this.exception?.type?.toString ?? null,
        this.exception?.description ?? null,
        this.exception?.httpResponseCode ?? null,
        this.responseBody ?? null,
      ];
    } else {
      const isFinal = TaskStatus_fun.isFinalState(this.taskStatus);
      const statusIsCompleteOrNotFound =
        this.taskStatus === TaskStatus.complete || this.taskStatus === TaskStatus.notFound;

      return [
        ordinal,
        isFinal ? this.responseBody ?? null : null,
        isFinal ? this.responseHeaders ?? null : null,
        statusIsCompleteOrNotFound ? this.responseStatusCode ?? null : null,
        isFinal ? this.mimeType ?? null : null,
        isFinal ? this.charSet ?? null : null,
      ];
    }
  }

  toString(): string {
    return `TaskStatusUpdate(task=${JSON.stringify(this.task)}, taskStatus=${this.taskStatus}, exception=${JSON.stringify(
      this.exception,
    )}, responseBody=${this.responseBody}, responseStatusCode=${this.responseStatusCode}, responseHeaders=${JSON.stringify(
      this.responseHeaders,
    )}, mimeType=${this.mimeType}, charSet=${this.charSet})`;
  }
}

@Sendable
export class TaskException {
  //public type: ExceptionType,
  public  type: string;
  public  httpResponseCode?: number = -1;
  public description?: string = "";

  constructor(type: string,httpResponseCode?: number,description?: string) {
    this.type = type;
    this.httpResponseCode = httpResponseCode;
    this.description = description;
  }
}

export enum ExceptionType {
  general = "TaskException",
  fileSystem = "TaskFileSystemException",
  url = "TaskUrlException",
  connection = "TaskConnectionException",
  resume = "TaskResumeException",
  httpResponse = "TaskHttpException",
}

export enum Updates {
  none,  // no status or progress updates
  status, // only calls upon change in DownloadTaskStatus
  progress, // only calls for progress
  statusAndProgress // calls also for progress along the way
}

/** Holds data associated with a task progress update, for local storage */
@Sendable
export class TaskProgressUpdate {
  public task?: Task
  public progress?:number
  public expectedFileSize?: number

  constructor(task?: Task,progress?:number,expectedFileSize?: number) {
    this.task = task;
    this.progress = this.progress;
    this.expectedFileSize = this.expectedFileSize
  }
}
