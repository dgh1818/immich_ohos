import { buffer } from '@kit.ArkTS';
import { sendableContextManager } from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileUri } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import nativeBuffer from '../../utils/native_buffer';
import { thumbHashToRGBA } from './Thumbhash';

export interface LocalBufferResult {
  buffer: ArrayBuffer;
  width: number;
  height: number;
  rowBytes: number;
  isHdr: boolean;
}

export interface LocalDecodeResult {
  pointer: number;
  width: number;
  height: number;
  rowBytes: number;
  isHdr: boolean;
}

@Concurrent
export async function decodeThumbhashTask(thumbhash: string): Promise<LocalBufferResult> {
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
export async function readEncodedLocalAssetTask(assetId: string): Promise<ArrayBuffer> {
  const file = fs.openSync(assetId, fs.OpenMode.READ_ONLY);
  try {
    const stat = fs.statSync(file.fd);
    if (stat.size <= 0) {
      throw new Error(`asset is empty: ${assetId}`);
    }

    const buffer = new ArrayBuffer(stat.size);
    const bytesRead = fs.readSync(file.fd, buffer);
    if (bytesRead <= 0) {
      throw new Error(`failed to read asset bytes: ${assetId}`);
    }

    return bytesRead === stat.size ? buffer : buffer.slice(0, bytesRead);
  } finally {
    fs.closeSync(file);
  }
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
  const makeAspectFitThumbnailSize = (
    requestWidth: number,
    requestHeight: number,
    assetWidth: number,
    assetHeight: number,
    orientation: number,
  ): Size => {
    const orientedWidth = orientation === 90 || orientation === 270
      ? (assetHeight > 0 ? assetHeight : 1)
      : (assetWidth > 0 ? assetWidth : 1);
    const orientedHeight = orientation === 90 || orientation === 270
      ? (assetWidth > 0 ? assetWidth : 1)
      : (assetHeight > 0 ? assetHeight : 1);

    let boundWidth = requestWidth > 0 ? requestWidth : 0;
    let boundHeight = requestHeight > 0 ? requestHeight : 0;
    if (boundWidth <= 0 && boundHeight <= 0) {
      boundWidth = orientedWidth;
      boundHeight = orientedHeight;
    } else if (boundWidth <= 0) {
      boundWidth = Math.round(boundHeight * orientedWidth / orientedHeight);
    } else if (boundHeight <= 0) {
      boundHeight = Math.round(boundWidth * orientedHeight / orientedWidth);
    }

    const scale = Math.min(boundWidth / orientedWidth, boundHeight / orientedHeight);
    return {
      width: Math.max(1, Math.round(orientedWidth * scale)),
      height: Math.max(1, Math.round(orientedHeight * scale)),
    };
  };
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
    const orientationKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.ORIENTATION;
    const photoAssetWidth = (photoAsset.get(widthKey.toString()) as number) || 0;
    const photoAssetHeight = (photoAsset.get(heightKey.toString()) as number) || 0;
    const photoAssetOrientation = (photoAsset.get(orientationKey.toString()) as number) || 0;
    const thumbnailSize = makeAspectFitThumbnailSize(
      width,
      height,
      photoAssetWidth,
      photoAssetHeight,
      photoAssetOrientation,
    );
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
      const widthKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.WIDTH;
      const heightKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.HEIGHT;
      const orientationKey: photoAccessHelper.PhotoKeys = photoAccessHelper.PhotoKeys.ORIENTATION;
      const photoAssetWidth = (photoAsset.get(widthKey.toString()) as number) || Math.round(imageInfo.size.width);
      const photoAssetHeight = (photoAsset.get(heightKey.toString()) as number) || Math.round(imageInfo.size.height);
      const photoAssetOrientation = (photoAsset.get(orientationKey.toString()) as number) || 0;
      const thumbnailSize = makeAspectFitThumbnailSize(
        width,
        height,
        photoAssetWidth,
        photoAssetHeight,
        photoAssetOrientation,
      );
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
    const length = buffer.byteLength;
    if (length <= 0) {
      throw new Error(`decoded local image (${actualWidth}x${actualHeight}, stride=${stride}) buffer is empty`);
    }

    const pointer = nativeBuffer.allocate(length);
    if (pointer === 0) {
      throw new Error(
        `decoded local image (${actualWidth}x${actualHeight}, stride=${stride}, bytes=${length}) native pointer allocation failed`,
      );
    }

    try {
      const copied = nativeBuffer.copy(buffer, pointer, 0, length);
      if (copied !== length) {
        throw new Error(
          `decoded local image (${actualWidth}x${actualHeight}, stride=${stride}, bytes=${length}) native copy failed`,
        );
      }
    } catch (error) {
      try {
        nativeBuffer.free(pointer);
      } catch (_) {}
      throw error as Error;
    }

    return {
      pointer,
      width: actualWidth,
      height: actualHeight,
      rowBytes: rowBytes,
      isHdr: pixelInfo.isHdr,
    };
  } finally {
    pixelMap.release();
  }
}
