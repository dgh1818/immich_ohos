import { LocalImageApiOhos, Result } from './LocalImages.g';
import { taskpool } from '@kit.ArkTS';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { decodeLocalImageTask, decodeThumbhashTask, LocalDecodeResult } from './LocalImageTask';
import nativeBuffer, { allocCopySafe } from '../../utils/native_buffer';

let runner: taskpool.AsyncRunner | undefined = undefined;

if (canIUse('api.version >= 18')) {
  runner = new taskpool.AsyncRunner('localImageRunner', 5);
}

export class LocalImagesImpl extends LocalImageApiOhos {
  static ctx?: common.Context;
  private requestMap = new Map<number, taskpool.Task>();

  constructor(context: common.Context) {
    super();
    LocalImagesImpl.ctx = context;
  }

  override async getThumbhash(thumbhash: string, result: Result<Map<string, Object>>) {
    const task: taskpool.Task = new taskpool.Task(decodeThumbhashTask, thumbhash);
    try {
      taskpool
        .execute(task)
        .then((d: object) => {
          const res = d as LocalDecodeResult | undefined;
          if (res != undefined) {
            const finalResult = new Map<string, Object>();
            const pointer = allocCopySafe(res.buffer);
            finalResult.set('width', res.width);
            finalResult.set('height', res.height);
            finalResult.set('rowBytes', res.rowBytes);
            finalResult.set('isHdr', res.isHdr);
            if (pointer) {
              finalResult.set('pointer', pointer);
            } else {
              finalResult.set('pointer', new Uint8Array(res.buffer));
            }
            return result.success(finalResult);
          }
          return result.error(new Error('thumbhash result undefined'));
        })
        .catch((e: BusinessError) => {
          return result.error(e);
        })
        .finally(() => {
          taskpool.terminateTask(task);
        });
    } catch (e) {
      return result.error(e as Error);
    }
  }

  override async requestImage(
    assetId: string,
    requestId: number,
    width: number,
    height: number,
    isVideo: boolean,
    result: Result<Map<string, Object>>
  ) {
    const sendableContext = sendableContextManager.convertFromContext(LocalImagesImpl.ctx!);
    const task: taskpool.Task = new taskpool.Task(
      decodeLocalImageTask,
      assetId,
      width,
      height,
      isVideo,
      sendableContext
    );
    this.requestMap.set(requestId, task);

    const isFullSize = width <= 0 && height <= 0;
    const executor =
      isFullSize ? taskpool.execute(task, taskpool.Priority.HIGH)
        : (canIUse('api.version >= 18') ? runner!.execute(task) : taskpool.execute(task));

    executor
      .then((d: object) => {
        const res = d as LocalDecodeResult | undefined;
        if (res != undefined) {
          const resOut = new Map<string, Object>();
          const pointer = allocCopySafe(res.buffer);
          resOut.set('width', res.width);
          resOut.set('height', res.height);
          resOut.set('rowBytes', res.rowBytes);
          resOut.set('isHdr', res.isHdr);
          if (pointer) {
            resOut.set('pointer', pointer);
          } else {
            resOut.set('pointer', new Uint8Array(res.buffer));
          }
          return result.success(resOut);
        } else {
          return result.error(new Error('res==undefined'));
        }
      })
      .catch((e: object) => {
        result.error(e as BusinessError);
      })
      .finally(() => {
        this.requestMap.delete(requestId);
        taskpool.terminateTask(task);
      });
  }

  override cancelRequest(requestId: number) {
    if (!this.requestMap.has(requestId)) {
      return;
    }
    const request = this.requestMap.get(requestId);
    try {
      taskpool.cancel(request);
      taskpool.terminateTask(request);
    } catch (e) {
      const error = e as BusinessError;
      console.error('image request task cancel error:' + error.message);
    } finally {
      this.requestMap.delete(requestId);
    }
  }
}
