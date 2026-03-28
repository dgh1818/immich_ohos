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

export class LocalImagesImpl extends LocalImageApiOhos {
  static ctx?: common.Context;
  private requestMap = new Map<number, taskpool.Task>();

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
    this.requestMap.set(requestId, task);

    const isFullSize = width <= 0 && height <= 0;
    const isGridThumb =
      !isFullSize && width > 0 && height > 0 && Math.max(width, height) <= GRID_THUMB_MAX_DIM;
    const priority =
      preferEncoded || isFullSize || isGridThumb
        ? taskpool.Priority.HIGH
        : taskpool.Priority.MEDIUM;
    const executor = taskpool.execute(task, priority);

    executor
      .then((d: object) => {
        if (preferEncoded) {
          const encoded = d as ArrayBuffer | undefined;
          if (encoded != undefined) {
            const resOut = new Map<string, Object>();
            const pointer = LocalImagesImpl.toNativeBuffer(encoded, "encoded local image");
            resOut.set("pointer", pointer);
            resOut.set("length", encoded.byteLength);
            return result.success(resOut);
          } else {
            return result.error(new Error("encoded asset result undefined"));
          }
        }

        const res = d as LocalDecodeResult | undefined;
        if (res != undefined) {
          const resOut = new Map<string, Object>();
          resOut.set("width", res.width);
          resOut.set("height", res.height);
          resOut.set("rowBytes", res.rowBytes);
          resOut.set("isHdr", res.isHdr);
          resOut.set("pointer", res.pointer);
          return result.success(resOut);
        } else {
          return result.error(new Error("res==undefined"));
        }
      })
      .catch((e: object) => {
        result.error(e as BusinessError);
      })
      .finally(() => {
        this.requestMap.delete(requestId);
      });
  }

  override cancelRequest(requestId: number) {
    if (!this.requestMap.has(requestId)) {
      return;
    }
    const request = this.requestMap.get(requestId);
    if (!request) {
      return;
    }
    try {
      taskpool.cancel(request);
    } catch (_) {
    } finally {
      this.requestMap.delete(requestId);
    }
  }
}
