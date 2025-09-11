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
import call from "@ohos.telephony.call";

@Concurrent
function getThumbhashTask(thumbhash: string): ThumbHashResult | undefined {
  try {
    let inputBuffer = buffer.from(thumbhash, 'base64');
    let bytes = new Uint8Array(inputBuffer.buffer, inputBuffer.byteOffset, inputBuffer.length);
    let image = thumbHashToRGBA(bytes)
    return new ThumbHashResult(image.width, image.height, image.pointer);

  } catch (e) {

    //callback(Result.failure(e))
    return undefined;
  }
}

export class MessagesImplBase extends ThumbnailApi {
  private ctx?: common.UIAbilityContext;

  //let phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.uiContext);

  constructor(context: common.UIAbilityContext) {
    super();
    this.ctx = context;
  }

  override async getThumbhash(thumbhash: string, result: Result<Map<string, object>>) {
    const task: taskpool.Task = new taskpool.Task(getThumbhashTask, thumbhash);
    try {
      const outcome = await taskpool.execute(task) as ThumbHashResult|undefined;

      if(outcome!=undefined) {
        return result.success(new Map<string, Object>([
          ["width", outcome.width],
          ["height", outcome.height],
          ["pointer", outcome.pointer]
        ]));
      }
      
    } catch (e) {
      return result.error(e);
    }
  }

  private async getThumbnailBufferInternal(
    assetId: string,
    width: number,
    height: number,
    isVideo: boolean,
    callback: Result<Map<string, object>>,
    //signal: CancellationSignal
  ) {
    //signal.throwIfCanceled()
    let targetWidth = width
    let targetHeight = height
    let id = assetId

    //signal.throwIfCanceled()
    let bitmap = isVideo ?
      //decodeVideoThumbnail(id, targetWidth, targetHeight, signal) :
      await this.decodeVideoThumbnail(id, targetWidth, targetHeight) :
      //this.decodeImage(id, targetWidth, targetHeight, signal);
      await this.decodeImage(id, targetWidth, targetHeight);

    //this.processBitmap(bitmap, callback, signal);
    this.processBitmap(bitmap, callback);
  }

  private processBitmap(
    bitmap: PixelMap, callback: (Result<Map<String, object>>)) {
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

      // Result.success
      // val res = mapOf(
      //   "pointer" to pointer,
      // "width" to actualWidth.toLong(),
      // "height" to actualHeight.toLong()
      // )
      return callback.success(new Map<string, Object>([
        ["width", actualWidth],
        ["height", actualHeight],
        ["pointer", buffer]
      ]));

    } catch (e) {
      callback.error(e);
    }
  }

  private async decodeImage(
    id: string, targetWidth: number, targetHeight: number
    //, signal: CancellationSignal
  ): Promise<PixelMap> {
    //signal.throwIfCanceled()
    let uri = id;
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);
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

  private async decodeVideoThumbnail(
    //id: number, targetWidth: number, targetHeight: number, signal: CancellationSignal
    id: string, targetWidth: number, targetHeight: number
  ): Promise<PixelMap> {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.ctx);
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
