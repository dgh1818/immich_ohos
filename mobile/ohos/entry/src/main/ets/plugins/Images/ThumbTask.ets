import { ThumbnailApi } from "./Messages_ohos.g";
import { Result } from "./Messages_ohos.g";
import { buffer, taskpool } from "@kit.ArkTS";
import { thumbHashToRGBA } from './Thumbhash'
import { ThumbHashResult } from './Thumbhash'
import { MethodResult } from "@ohos/flutter_ohos";
import { common, ErrorCode } from "@kit.AbilityKit";
import { dataSharePredicates } from "@kit.ArkData";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { image } from "@kit.ImageKit";
import { BusinessError } from '@kit.BasicServicesKit';

import {MessagesImplBase} from './ThumbnailsImpl'

@Concurrent
export async function getThumbhashTask(thumbhash: string) {
  await new Promise<ThumbHashResult|undefined>((resolve, reject) => {
    try {
      let inputBuffer = buffer.from(thumbhash, 'base64');
      let bytes = new Uint8Array(inputBuffer.buffer, inputBuffer.byteOffset, inputBuffer.length);
      let image = thumbHashToRGBA(bytes)
      resolve (new ThumbHashResult(image.width, image.height, image.pointer));
    } catch (e) {
      // is OperationCanceledException -> callback(CANCELLED)
      // is CancellationException -> callback(CANCELLED)
      // else -> callback(Result.failure(e))

      resolve (undefined);

    } finally {
      //requestMap.remove(requestId)
    }

  }).then(() => {
    throw new Error('getThumbhashTask error');
  })
}

@Concurrent
export async function requestImageTask(assetId: string,
  requestId: number,
  width: number,
  height: number,
  isVideo: boolean) {
  await new Promise<Map<string,object>|undefined>((resolve, reject) => {
    try {
      resolve (MessagesImplBase.getThumbnailBufferInternal(assetId, width, height, isVideo));
    } catch (e) {
      // is OperationCanceledException -> callback(CANCELLED)
      // is CancellationException -> callback(CANCELLED)
      // else -> callback(Result.failure(e))

      resolve (undefined);

    } finally {
      //requestMap.remove(requestId)
    }

  }).then(() => {
    throw new Error('requestImageTask error');
  })
}
