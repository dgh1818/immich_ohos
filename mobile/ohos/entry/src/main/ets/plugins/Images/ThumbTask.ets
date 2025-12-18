import { ThumbnailApi } from "./Messages_ohos.g";
import { Result } from "./Messages_ohos.g";
import { buffer, taskpool } from "@kit.ArkTS";
import { thumbHashToRGBA } from './Thumbhash'
import { ThumbHashResult } from './Thumbhash'
import { MethodResult } from "@ohos/flutter_ohos";
import { common, ErrorCode, sendableContextManager } from "@kit.AbilityKit";
import { dataSharePredicates } from "@kit.ArkData";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { image } from "@kit.ImageKit";
import { BusinessError} from '@kit.BasicServicesKit';

import {MessagesImplBaseThumb} from './ThumbnailsImpl'

@Concurrent
export async function getThumbhashTask(thumbhash: string) {
  await new Promise<ThumbHashResult|undefined>((resolve, reject) => {
    try {
      let inputBuffer = buffer.from(thumbhash, 'base64');
      let bytes = new Uint8Array(inputBuffer.buffer);
      let image = thumbHashToRGBA(bytes)
      resolve (new ThumbHashResult(image.width, image.height, image.pointer,false,image.width * 4));
    } catch (e) {
      // is OperationCanceledException -> callback(CANCELLED)
      // is CancellationException -> callback(CANCELLED)
      // else -> callback(Result.failure(e))
      throw new Error('getThumbhashTask error');
      reject("getThumbhashTask error");

    }
  }).then(() => {
    //throw new Error('getThumbhashTask error');
  })
}

@Concurrent
export async function requestImageTask(assetId: string,
  requestId: number,
  width: number,
  height: number,
  isVideo: boolean,
  sendableUiContext:sendableContextManager.SendableContext) {
  let ctx = sendableContextManager.convertToUIAbilityContext(sendableUiContext);
  //let res = await MessagesImplBaseThumb.getThumbnailBufferInternal(assetId, width, height, isVideo, ctx)
  return await new Promise<ThumbHashResult|undefined>((resolve, reject) => {
    MessagesImplBaseThumb.getThumbnailBufferInternal(assetId, width, height, isVideo, ctx)
      .then((res) => resolve(res))
      .catch((err: BusinessError) => {
        console.error(err.message);
        // 根据错误类型分类处理
        // if (isOperationCanceled(err)) {
        //   // 取消类错误 -> 解析为 undefined（或按业务返回 CANCELLED）
        //   resolve(undefined);
        // } else {
          // 其它错误 -> 拒绝 Promise
          reject(err);
        //}
      });

  }).finally(() => {
    //requestMap.remove(requestId);
  });
}
