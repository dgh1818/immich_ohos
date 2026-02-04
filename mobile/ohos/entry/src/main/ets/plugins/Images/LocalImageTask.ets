import { buffer } from '@kit.ArkTS';
import { sendableContextManager } from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileUri } from '@kit.CoreFileKit';
import { thumbHashToRGBA } from './Thumbhash';

export interface LocalDecodeResult {
  buffer: ArrayBuffer;
  width: number;
  height: number;
  rowBytes: number;
  isHdr: boolean;
}

@Concurrent
export async function decodeThumbhashTask(thumbhash: string): Promise<LocalDecodeResult> {
  const inputBuffer = buffer.from(thumbhash, 'base64');
  const bytes = new Uint8Array(inputBuffer.buffer);
  const imageOut = thumbHashToRGBA(bytes);
  return {
    buffer: imageOut.pointer,
    width: imageOut.width,
    height: imageOut.height,
    rowBytes: imageOut.stride,
    isHdr: imageOut.isHdr,
  };
}

@Concurrent
export async function decodeLocalImageTask(
  assetId: string,
  width: number,
  height: number,
  isVideo: boolean,
  sendableUiContext: sendableContextManager.SendableContext
): Promise<LocalDecodeResult> {
  const ctx = sendableContextManager.convertToUIAbilityContext(sendableUiContext);
  let pixelMap: PixelMap;

  if (isVideo) {
    const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
    const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
    predicates.equalTo('uri', assetId);
    const videoFetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
      await phAccessHelper.getAssets({
        fetchColumns: ['width', 'height', 'orientation'],
        predicates: predicates
      });
    const photoAsset: photoAccessHelper.PhotoAsset = await videoFetchResult.getFirstObject();
    const widthKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.WIDTH;
    const heightKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.HEIGHT;
    const photoAssetWidth = (photoAsset.get(widthKey.toString()) as number) || 0;
    const photoAssetHeight = (photoAsset.get(heightKey.toString()) as number) || 0;

    let targetHeight = height;
    if (targetHeight <= 0) {
      if (width > 0 && photoAssetWidth > 0) {
        targetHeight = Math.round(width * photoAssetHeight / photoAssetWidth);
      } else {
        targetHeight = photoAssetHeight;
      }
    }
    if (targetHeight <= 0) {
      targetHeight = 1;
    }
    let targetWidth = photoAssetHeight > 0
      ? Math.round(photoAssetWidth * targetHeight / photoAssetHeight)
      : width;
    if (targetWidth <= 0) {
      targetWidth = 1;
    }

    const thumbnailSize: Size = { height: targetHeight, width: targetWidth };
    pixelMap = await photoAsset.getThumbnail(thumbnailSize);
  } else {
    const filePath = new fileUri.FileUri(assetId).path;
    const imageSource: image.ImageSource = image.createImageSource(filePath);
    const imageInfo = await imageSource.getImageInfo();

    if (width == 0 && height == 0) {
      try {
        pixelMap = await imageSource.createPixelMap({
          editable: true,
          desiredPixelFormat: imageInfo.isHdr
            ? image.PixelMapFormat.RGBA_1010102
            : image.PixelMapFormat.RGBA_8888,
          desiredDynamicRange: image.DecodingDynamicRange.AUTO,
        });
      } catch (_) {
        pixelMap = await imageSource.createPixelMap({
          editable: true,
          desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
          desiredDynamicRange: image.DecodingDynamicRange.AUTO,
        });
      }
    } else {
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
      const predicates: dataSharePredicates.DataSharePredicates = new dataSharePredicates.DataSharePredicates();
      predicates.equalTo('uri', assetId);
      const fetchResult: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> =
        await phAccessHelper.getAssets({
          fetchColumns: ['width', 'height', 'orientation'],
          predicates: predicates
        });
      const photoAsset: photoAccessHelper.PhotoAsset = await fetchResult.getFirstObject();

      let targetHeight = height;
      if (targetHeight <= 0) {
        if (width > 0 && imageInfo.size.width > 0) {
          targetHeight = Math.round(width * imageInfo.size.height / imageInfo.size.width);
        } else {
          targetHeight = Math.round(imageInfo.size.height);
        }
      }
      if (targetHeight <= 0) {
        targetHeight = 1;
      }
      let targetWidth = imageInfo.size.height > 0
        ? Math.round(imageInfo.size.width * targetHeight / imageInfo.size.height)
        : width;
      if (targetWidth <= 0) {
        targetWidth = 1;
      }

      const thumbnailSize: Size = { height: targetHeight, width: targetWidth };
      pixelMap = await photoAsset.getThumbnail(thumbnailSize);
    }
  }

  try {
    const pixelInfo = pixelMap.getImageInfoSync();
    const actualWidth = pixelInfo.size.width;
    const actualHeight = pixelInfo.size.height;
    const bytesPerPixel = 4;
    const rowBytes = actualWidth * bytesPerPixel;
    let stride = pixelInfo.stride ?? rowBytes;
    if (stride > 0 && stride < rowBytes) {
      // Some devices may report stride in pixels; normalize to bytes.
      stride = stride >= actualWidth ? stride * bytesPerPixel : rowBytes;
    }
    if (stride <= 0) {
      stride = rowBytes;
    }

    console.info(
      `LocalImageTask stride debug: reqW=${width} reqH=${height} w=${actualWidth} h=${actualHeight} rowBytes=${rowBytes} stride=${stride} rawStride=${pixelInfo.stride}`
    );

    if (stride < rowBytes) {
      stride = rowBytes;
    }
    let buffer: ArrayBuffer = new ArrayBuffer(stride * actualHeight);
    pixelMap.readPixelsToBufferSync(buffer);

    // Force tight rows (width * 4) without repacking.
    const outBuffer = buffer;
    const outStride = rowBytes;

    return {
      buffer: outBuffer,
      width: actualWidth,
      height: actualHeight,
      rowBytes: outStride,
      isHdr: pixelInfo.isHdr,
    };
  } finally {
    pixelMap.release();
  }
}
