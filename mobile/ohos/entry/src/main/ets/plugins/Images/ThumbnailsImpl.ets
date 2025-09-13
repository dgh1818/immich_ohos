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
import {getThumbhashTask,requestImageTask} from './ThumbTask'

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
      taskpool.execute(task).then((d: object) => {
        let res = d as ThumbHashResult|undefined;
        if(res!=undefined) {
          return result.success(new Map<string, Object>([
            ["width", res.width],
            ["height", res.height],
            ["pointer", res.pointer]
          ]));
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
    let task: taskpool.Task = new taskpool.Task(requestImageTask, assetId, requestId, width, height, isVideo);

    taskpool.execute(task).then((d: object) => {
      let res = d as Map<string, object>;
      callback.success(res);
      console.info(`task1 res is: ${d}`);
    }).catch((e: object) => {
      callback.error(e as BusinessError);
      console.error(`task1 catch e: ${e}`); // task1 catch e: Error: testPromise error
    }).finally(() => {
      this.requestMap.delete(requestId);
    })

    this.requestMap.set(requestId,task);
}

  override cancelImageRequest(requestId: number) {
    if(!this.requestMap.has(requestId)) {
      return;

    }
    let request = this.requestMap.get(requestId);
    taskpool.cancel(request);
    return;
  }

  public static async getThumbnailBufferInternal(
    assetId: string,
    width: number,
    height: number,
    isVideo: boolean,
    //callback: Result<Map<string, number>>,
    //signal: CancellationSignal
  ) :Promise<Map<string,object>|undefined>{
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

    //this.processBitmap(bitmap, callback, signal);
    let finalResult = MessagesImplBaseThumb.processBitmap(bitmap);
    return finalResult;
  }

  public static processBitmap(
    bitmap: PixelMap
    //, callback: (Result<Map<String, object>>)
  ):Map<string,object>|undefined
  {
    //signal.throwIfCanceled()
    let imageInfo = bitmap.getImageInfoSync();
    let actualWidth = imageInfo.size.width;
    let actualHeight = imageInfo.size.height;

    let size = actualWidth * actualHeight * 4
    //let pointer = allocateNative(size)

    try {
      let buffer: ArrayBuffer = new ArrayBuffer(size);

      bitmap.readPixelsToBufferSync(buffer);
      bitmap.release();

      let finalResult = new Map<string, Object>([
        ["width", actualWidth],
        ["height", actualHeight],
        ["pointer", buffer]
      ]);
      return finalResult;

    } catch (e) {
      //callback.error(e);
      return undefined;
    }
  }

  public static async decodeImage(
    id: string, targetWidth: number, targetHeight: number
    //, signal: CancellationSignal
  ): Promise<PixelMap> {
    //signal.throwIfCanceled()
    let uri = id;
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(MessagesImplBaseThumb.ctx);
    const imageSource: image.ImageSource = image.createImageSource(uri);

    const color: ArrayBuffer =
      new ArrayBuffer(4 * targetWidth * targetHeight); // 96为需要创建的像素buffer大小，取值为：height * width *4。
    let opts: image.InitializationOptions = {
      editable: true,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      size: { height: targetHeight, width: targetHeight }
    }
    let imageOut = image.createPixelMapSync(color, opts);

    return imageOut;
  }

  public static async decodeVideoThumbnail(
    //id: number, targetWidth: number, targetHeight: number, signal: CancellationSignal
    id: string, targetWidth: number, targetHeight: number
  ): Promise<PixelMap> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(MessagesImplBaseThumb.ctx);
    let uri = id;
    let predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo('uri', id);
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
