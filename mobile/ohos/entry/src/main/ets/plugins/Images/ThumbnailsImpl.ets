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
import { getThumbhashTask, requestImageTask } from './ThumbTask'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { colorSpaceManager } from '@kit.ArkGraphics2D';


let runner: taskpool.AsyncRunner | undefined = undefined;

if (canIUse('api.version >= 18')) {
  runner = new taskpool.AsyncRunner("runner1", 5);
}

//let runner:taskpool.AsyncRunner = new taskpool.AsyncRunner("runner1", 5);

export class MessagesImplBaseThumb extends ThumbnailApi {
  static ctx?: common.Context;
  private requestMap = new Map<number, taskpool.Task>();

  constructor(context: common.Context) {
    super();
    MessagesImplBaseThumb.ctx = context;
  }

  override async getThumbhash(thumbhash: string, result: Result<Map<string, object>>) {
    const task: taskpool.Task = new taskpool.Task(getThumbhashTask, thumbhash);
    try {
      taskpool.execute(task).then((d: object) => {
        //runner.execute(task).then((d: object) => {
        let res = d as ThumbHashResult | undefined;

        if (res != undefined) {
          let finalResult = new Map<string, Object>();
          finalResult.set("width", res.width);
          finalResult.set("height", res.height);
          finalResult.set("pointer", new Uint8Array(res.pointer));
          finalResult.set("isHdr", res.isHdr);
          finalResult.set("stride", res.stride);

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
    let task: taskpool.Task =
      new taskpool.Task(requestImageTask, assetId, requestId, width, height, isVideo, sendableContext);
    this.requestMap.set(requestId, task);

    if (canIUse('api.version >= 18')) {
      runner!.execute(task).then((d: object) => {
        let res = d as ThumbHashResult | undefined;

        if (res != undefined) {
          let resOut = new Map<string, Object>();
          resOut.set("width", res.width);
          resOut.set("height", res.height);
          resOut.set("pointer", new Uint8Array(res.pointer));
          resOut.set("isHdr", res.isHdr);

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
    } else {
      taskpool.execute(task).then((d: object) => {
        let res = d as ThumbHashResult | undefined;

        if (res != undefined) {
          let resOut = new Map<string, Object>();
          resOut.set("width", res.width);
          resOut.set("height", res.height);
          resOut.set("pointer", new Uint8Array(res.pointer));
          resOut.set("isHdr", res.isHdr);
          resOut.set("stride", res.stride);


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
  }

  override cancelImageRequest(requestId: number) {
    if (!this.requestMap.has(requestId)) {
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
    ctx: common.Context,
    //callback: Result<Map<string, number>>,
    //signal: CancellationSignal
  ): Promise<ThumbHashResult | undefined> {
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
  ): ThumbHashResult {
    console.error("enter processBitmap");
    //signal.throwIfCanceled()
    let imageInfo = bitmap.getImageInfoSync();
    let actualWidth = imageInfo.size.width;
    let actualHeight = imageInfo.size.height;
    let stride = imageInfo.stride;

    try {
      const bufferSize = bitmap.getPixelBytesNumber();
      let buffer: ArrayBuffer = new ArrayBuffer(stride * actualHeight);
      bitmap.readPixelsToBufferSync(buffer);

      const bytesPerPixel = 4;
      const rowBytes = actualWidth * bytesPerPixel;
      const expectedSize = rowBytes * actualHeight;
      let outStride = stride ?? rowBytes;

      if (bufferSize > expectedSize && stride != undefined && stride > rowBytes) {
        const raw = new Uint8Array(buffer);
        const packed = new Uint8Array(rowBytes * actualHeight);
        for (let y = 0; y < actualHeight; y++) {
          const srcStart = y * stride;
          const srcEnd = srcStart + rowBytes;
          packed.set(raw.subarray(srcStart, srcEnd), y * rowBytes);
        }
        const packedBuffer: ArrayBuffer = new ArrayBuffer(packed.byteLength);
        new Uint8Array(packedBuffer).set(packed);
        buffer = packedBuffer;
        outStride = rowBytes;
      } else if (bufferSize < expectedSize) {
        console.warn(`Unexpected pixel buffer size: ${bufferSize} < ${expectedSize}`);
      }

      let bitmapInfo = bitmap.getImageInfoSync();
      let isHdr = bitmapInfo.isHdr;

      let finalResult = new ThumbHashResult(actualWidth, actualHeight, buffer, isHdr, outStride);

      return finalResult;

    } catch (e) {
      //callback.error(e);
      console.error("processbitmap", e);
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
    let filePath = new fileUri.FileUri(id).path;

    let opts: image.DecodingOptions;

    const imageSource: image.ImageSource = image.createImageSource(filePath);

    const imageInfo = await imageSource.getImageInfo();

    let colorManager = colorSpaceManager.create(colorSpaceManager.ColorSpace.DISPLAY_P3);


    if (targetHeight == 0 && targetWidth == 0) {
      opts = { editable: true, desiredDynamicRange: image.DecodingDynamicRange.AUTO};
      let imageOut = await imageSource.createPixelMap(opts);
      return imageOut;
    } else {
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(MessagesImplBaseThumb.ctx);
      let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();

      let uri = id;
      predicates.equalTo('uri', uri);
      let videoFetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
        await phAccessHelper.getAssets({
          fetchColumns: ['width', 'height', 'orientation'],
          predicates: predicates
        });
      let thumbnailSize: Size = { height: targetHeight, width: imageInfo.size.width * targetHeight / imageInfo.size.height }
      let photoAsset: photoAccessHelper.PhotoAsset = await videoFetchResult.getFirstObject();
      let imageOut = await photoAsset.getThumbnail(thumbnailSize);

      opts = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredSize: { height: targetHeight, width: imageInfo.size.width * targetHeight / imageInfo.size.height
        },
        desiredDynamicRange: image.DecodingDynamicRange.SDR
      };
      return imageOut;
    }

    //let imageOut = await imageSource.createPixelMap(opts);
  }

  public static async decodeVideoThumbnail(
    //id: number, targetWidth: number, targetHeight: number, signal: CancellationSignal
    id: string, targetWidth: number, targetHeight: number
  ): Promise<PixelMap> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(MessagesImplBaseThumb.ctx);
    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();

    let uri = id;
    predicates.equalTo('uri', uri);
    let videoFetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
      await phAccessHelper.getAssets({
        fetchColumns: ['width', 'height', 'orientation'],
        predicates: predicates
      });
    let photoAsset: photoAccessHelper.PhotoAsset = await videoFetchResult.getFirstObject();
    let widthKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.WIDTH
    let heightKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.HEIGHT
    let photoAssetwidth: number = photoAsset.get(widthKey.toString()) as number;
    let photoAssetheight: number = photoAsset.get(heightKey.toString()) as number;

    let thumbnailSize: Size = { height: targetHeight, width: photoAssetwidth * targetHeight / photoAssetheight }
    let videoThumb = await photoAsset.getThumbnail(thumbnailSize);
    return videoThumb;
  }

  override async getHdr(assetId: string, result: Result<Map<string, boolean>>) {
    let filePath = new fileUri.FileUri(assetId).path;;
    const imageSource: image.ImageSource = image.createImageSource(filePath);
    const imageInfo = await imageSource.getImageInfo();
    const isHdr = imageInfo.isHdr;
    let resOut = new Map<string, boolean>();
    resOut.set("isHdr", isHdr);
    result.success(resOut);
  }
}
