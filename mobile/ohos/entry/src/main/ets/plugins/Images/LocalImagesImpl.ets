import { LocalImageApiOhos, Result } from "./LocalImages.g";
import { taskpool } from "@kit.ArkTS";
import { common, sendableContextManager } from "@kit.AbilityKit";
import { BusinessError } from "@kit.BasicServicesKit";
import {
  decodeLocalImageTask,
  decodeThumbhashTask,
  LocalBufferResult,
  LocalDecodeResult,
  readEncodedLocalAssetTask,
} from "./LocalImageTask";
import nativeBuffer from "../../utils/native_buffer";

const GRID_THUMB_MAX_DIM = 320;

interface LocalRequestState {
  task: taskpool.Task;
  cancelled: boolean;
}

export class LocalImagesImpl extends LocalImageApiOhos {
  static ctx?: common.Context;
  private requestMap = new Map<number, LocalRequestState>();

  private static toNativeBuffer(buffer: ArrayBuffer, label: string): number {
    const length = buffer.byteLength;
    if (length <= 0) {
      throw new Error(`${label} buffer is empty`);
    }

    const pointer = nativeBuffer.allocate(length);
    if (pointer === 0) {
      throw new Error(`${label} native pointer allocation failed`);
    }

    try {
      const copied = nativeBuffer.copy(buffer, pointer, 0, length);
      if (copied !== length) {
        throw new Error(`${label} native copy failed`);
      }
      return pointer;
    } catch (error) {
      try {
        nativeBuffer.free(pointer);
      } catch (_) {}
      throw error as Error;
    }
  }

  constructor(context: common.Context) {
    super();
    LocalImagesImpl.ctx = context;
  }

  override async getThumbhash(thumbhash: string, result: Result<Map<string, Object>>) {
    const task: taskpool.Task = new taskpool.Task(decodeThumbhashTask, thumbhash);
    try {
      taskpool
        .execute(task, taskpool.Priority.MEDIUM)
        .then((d: object) => {
          const res = d as LocalBufferResult | undefined;
          if (res != undefined) {
            const finalResult = new Map<string, Object>();
            const pointer = LocalImagesImpl.toNativeBuffer(res.buffer, "thumbhash");
            finalResult.set("width", res.width);
            finalResult.set("height", res.height);
            finalResult.set("rowBytes", res.rowBytes);
            finalResult.set("isHdr", res.isHdr);
            finalResult.set("pointer", pointer);
            return result.success(finalResult);
          }
          return result.error(new Error("thumbhash result undefined"));
        })
        .catch((e: BusinessError) => {
          return result.error(e);
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
    preferEncoded: boolean,
    result: Result<Map<string, Object>>,
  ) {
    const sendableContext = sendableContextManager.convertFromContext(LocalImagesImpl.ctx!);
    const task: taskpool.Task = preferEncoded
      ? new taskpool.Task(readEncodedLocalAssetTask, assetId)
      : new taskpool.Task(decodeLocalImageTask, assetId, width, height, isVideo, sendableContext);
    const state: LocalRequestState = { task, cancelled: false };
    this.requestMap.set(requestId, state);

    const isFullSize = width <= 0 && height <= 0;
    const isGridThumb =
      !isFullSize && width > 0 && height > 0 && Math.max(width, height) <= GRID_THUMB_MAX_DIM;
    const priority =
      preferEncoded || isFullSize || isGridThumb
        ? taskpool.Priority.HIGH
        : taskpool.Priority.MEDIUM;
    const executor = taskpool.execute(task, priority);

    executor
      .then((d: object): void => {
        if (preferEncoded) {
          const encoded = d as ArrayBuffer | undefined;
          if (encoded != undefined) {
            if (state.cancelled) {
              this.finishCancelled(result);
              return;
            }
            const resOut = new Map<string, Object>();
            const pointer = LocalImagesImpl.toNativeBuffer(encoded, "encoded local image");
            if (state.cancelled) {
              try {
                nativeBuffer.free(pointer);
              } catch (_) {}
              this.finishCancelled(result);
              return;
            }
            resOut.set("pointer", pointer);
            resOut.set("length", encoded.byteLength);
            result.success(resOut);
            return;
          } else if (state.cancelled) {
            this.finishCancelled(result);
            return;
          } else {
            result.error(new Error("encoded asset result undefined"));
            return;
          }
        }

        const res = d as LocalDecodeResult | undefined;
        if (res != undefined) {
          if (state.cancelled) {
            this.freeDecodedResult(res);
            this.finishCancelled(result);
            return;
          }
          const resOut = new Map<string, Object>();
          resOut.set("width", res.width);
          resOut.set("height", res.height);
          resOut.set("rowBytes", res.rowBytes);
          resOut.set("isHdr", res.isHdr);
          resOut.set("pointer", res.pointer);
          result.success(resOut);
          return;
        } else if (state.cancelled) {
          this.finishCancelled(result);
          return;
        } else {
          result.error(new Error("res==undefined"));
          return;
        }
      })
      .catch((e: object): void => {
        if (state.cancelled) {
          this.finishCancelled(result);
          return;
        }
        result.error(e as BusinessError);
      })
      .finally((): void => {
        this.requestMap.delete(requestId);
      });
  }

  override cancelRequest(requestId: number) {
    const state = this.requestMap.get(requestId);
    if (!state) {
      return;
    }
    state.cancelled = true;
    try {
      taskpool.cancel(state.task);
    } catch (_) {
    } finally {
      this.requestMap.delete(requestId);
    }
  }

  private finishCancelled(result: Result<Map<string, Object>>) {
    result.success(new Map<string, Object>());
  }

  private freeDecodedResult(result: LocalDecodeResult) {
    if (result.pointer === 0) {
      return;
    }
    try {
      nativeBuffer.free(result.pointer);
    } catch (_) {}
  }
}
