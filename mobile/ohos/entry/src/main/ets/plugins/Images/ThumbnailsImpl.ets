import { ThumbnailApi } from "./Messages_ohos.g";
import { Result } from "./Messages_ohos.g";
import { buffer, collections, taskpool } from "@kit.ArkTS";
import { thumbHashToRGBA } from './Thumbhash'
import { ThumbHashResult } from './Thumbhash'
import { MethodResult } from "@ohos/flutter_ohos";
import { common, ErrorCode, sendableContextManager } from "@kit.AbilityKit";
import { dataSharePredicates } from "@kit.ArkData";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { image } from "@kit.ImageKit";
import { BusinessError } from '@kit.BasicServicesKit';
import {getThumbhashTask,requestImageTask} from './ThumbTask'

import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import call from "@ohos.telephony.call";

let runner:taskpool.AsyncRunner = new taskpool.AsyncRunner("runner1", 5);

export class MessagesImplBaseThumb extends ThumbnailApi {
  static ctx?: common.UIAbilityContext;
  private requestMap = new Map<number, taskpool.Task>();

  constructor(context: common.UIAbilityContext) {
    super();
    MessagesImplBaseThumb.ctx = context;
  }

  override async getThumbhash(thumbhash: string, result: Result<Map<string, object>>) {
    const task: taskpool.Task = new taskpool.Task(getThumbhashTask, thumbhash);
    try {
      runner.execute(task).then((d: object) => {
        let res = d as ThumbHashResult|undefined;

        if(res!=undefined) {
          let finalResult = new Map<string, Object>();
          finalResult.set("width",res.width);
          finalResult.set("height",res.height);
          finalResult.set("pointer",Uint8Array.from(res.pointer));

          return result.success(finalResult);
        }

      }).catch((e: BusinessError) => {
        return result.error(e);
      }).finally(() => {
        ;
      })
    } catch (e) {
      return result.error(e);
    }
  }

  override async requestImage(
  assetId: string,
  requestId: number,
  width: number,
  height: number,
  isVideo: boolean,
  callback: (Result<Map<string, object>>)) {
  //let signal = CancellationSignal()
    let sendableContext = sendableContextManager.convertFromContext(MessagesImplBaseThumb.ctx!);
    let task: taskpool.Task = new taskpool.Task(requestImageTask, assetId, requestId, width, height, isVideo,sendableContext);
    this.requestMap.set(requestId,task);

    runner.execute(task).then((d: object) => {
      let res = d as ThumbHashResult|undefined;

      if(res!=undefined) {
        let resOut = new Map<string, Object>();
        resOut.set("width",res.width);
        resOut.set("height",res.height);
        resOut.set("pointer",Uint8Array.from(res.pointer));


        return callback.success(resOut);


      } else {
        callback.error(new Error("res==undefined"));
        return;
      }


      console.info(`task1 res is: ${d}`);
    }).catch((e: object) => {
      callback.error(e as BusinessError);
      return;
      console.error(`task1 catch e: ${e}`); // task1 catch e: Error: testPromise error
    }).finally(() => {
      this.requestMap.delete(requestId);
      taskpool.terminateTask(task);
    })
}

  override cancelImageRequest(requestId: number) {
    if(!this.requestMap.has(requestId)) {
      return;

    }
    let request = this.requestMap.get(requestId);
    taskpool.cancel(request);
    taskpool.terminateTask(request);
    this.requestMap.delete(requestId);
    return;
  }

  public static async getThumbnailBufferInternal(
    assetId: string,
    width: number,
    height: number,
    isVideo: boolean,
    ctx:common.UIAbilityContext,
    //callback: Result<Map<string, number>>,
    //signal: CancellationSignal
  ) :Promise<ThumbHashResult|undefined>{
    MessagesImplBaseThumb.ctx = ctx;
    //signal.throwIfCanceled()
    let targetWidth = width
    let targetHeight = height
    let id = assetId

    //signal.throwIfCanceled()
    let bitmap = isVideo ?
      //decodeVideoThumbnail(id, targetWidth, targetHeight, signal) :
      await MessagesImplBaseThumb.decodeVideoThumbnail(id, targetWidth, targetHeight) :
      //this.decodeImage(id, targetWidth, targetHeight, signal);
      await MessagesImplBaseThumb.decodeImage(id, targetWidth, targetHeight);

    let finalResult = MessagesImplBaseThumb.processBitmap(bitmap);
    bitmap.release();
    return finalResult;
  }

  public static processBitmap(
    bitmap: PixelMap
    //, callback: (Result<Map<String, object>>)
  ):ThumbHashResult
  {
    console.error("enter processBitmap");
    //signal.throwIfCanceled()
    let imageInfo = bitmap.getImageInfoSync();
    let actualWidth = imageInfo.size.width;
    let actualHeight = imageInfo.size.height;

    let size = actualWidth * actualHeight * 4
    //let pointer = allocateNative(size)

    try {
      const bufferSize = bitmap.getPixelBytesNumber();
      //console.error("enter processBitmap2" + bufferSize);
      let buffer: ArrayBuffer|undefined = new ArrayBuffer(bufferSize);
      //console.error("enter processBitmap3");

      bitmap.readPixelsToBufferSync(buffer);

      //console.error("enter processBitmap4");

      let uint8Array: Uint8Array|undefined = new Uint8Array(buffer);
      buffer = undefined;
      //console.error("enter processBitmap5");
      let collectionsUint8Array: collections.Uint8Array = new collections.Uint8Array(uint8Array);
      //uint8Array = undefined;
      //let collectionsUint8Array = new collections.Uint8Array(buffer);

      //console.error("enter processBitmap6" + collectionsUint8Array.byteLength);

      let finalResult = new ThumbHashResult(actualWidth,actualHeight,collectionsUint8Array);
      
      return finalResult;

    } catch (e) {
      //callback.error(e);
      console.error("processbitmap",e);
      throw new Error('getThumbhashTask error');
    } finally {
      bitmap.release();
    }
  }

  public static async decodeImage(
    id: string, targetWidth: number, targetHeight: number
    //, signal: CancellationSignal
  ): Promise<PixelMap> {
    //signal.throwIfCanceled()
    let filePath = id;

    const imageSource: image.ImageSource = image.createImageSource(id);


    // const color: ArrayBuffer =
    //   new ArrayBuffer(4 * targetWidth * targetHeight); // 96为需要创建的像素buffer大小，取值为：height * width *4。
    let opts: image.DecodingOptions = { editable: false, desiredPixelFormat: image.PixelMapFormat.RGBA_8888, desiredSize: { height: 256, width: 256 } }
    let imageOut = await imageSource.createPixelMapUsingAllocator(opts, image.AllocatorType.AUTO);

    return imageOut;
  }

  public static async decodeVideoThumbnail(
    //id: number, targetWidth: number, targetHeight: number, signal: CancellationSignal
    id: string, targetWidth: number, targetHeight: number
  ): Promise<PixelMap> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(MessagesImplBaseThumb.ctx);
    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();

    let uri= fileUri.getUriFromPath(id)
    predicates.equalTo('uri', uri);
    let videoFetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
      await phAccessHelper.getAssets({
        fetchColumns: ['width', 'height', 'orientation'],
        predicates: predicates
      });
    let photoAsset: photoAccessHelper.PhotoAsset = await videoFetchResult.getFirstObject();

    let thumbnailSize: Size = { width: 0, height: 0 };
    thumbnailSize.width = targetWidth;
    thumbnailSize.height = targetHeight;

    let videoThumb = await photoAsset.getThumbnail(thumbnailSize);
    return videoThumb;
  }
}
