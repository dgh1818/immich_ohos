import { Queue, taskpool } from "@kit.ArkTS";
import { Task } from "./Models";
import { workScheduler } from "@kit.BackgroundTasksKit";
import { EnqueueItem } from "./HoldingQueue";

export class WiFi  {

  static requireWifi:boolean =  true;
  static requireWiFiQueue:Queue<EnqueueItem> = new Queue<EnqueueItem>();
  static reEnqueueQueue:Queue<EnqueueItem> = new Queue<EnqueueItem>();
  //static requireWiFiLock = Mutex()

  //reEnqueue

  static reEnqueue(enqueueItem?: EnqueueItem) {
    WiFi.reEnqueueQueue.add(enqueueItem);
}


}
