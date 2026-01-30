import { image } from '@kit.ImageKit';

export interface RemoteDecodeResult {
  buffer: ArrayBuffer;
  width: number;
  height: number;
  rowBytes: number;
  isHdr: boolean;
}

@Concurrent
export async function decodeRemoteImageTask(data: ArrayBuffer, allowHdr: boolean): Promise<RemoteDecodeResult> {
  if (!data || data.byteLength === 0) {
    throw new Error('srcData is detached/empty');
  }

  const imageSource: image.ImageSource = image.createImageSource(data);
  let pixelMap: PixelMap | undefined;

  try {
    if (allowHdr) {
      const imageInfo = await imageSource.getImageInfo();
      const isHdr = imageInfo.isHdr;

      // ?????? HDR ???????????????? 8888
      try {
        pixelMap = await imageSource.createPixelMap({
          editable: true,
          desiredPixelFormat: isHdr ? image.PixelMapFormat.RGBA_1010102 : image.PixelMapFormat.RGBA_8888,
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
      pixelMap = await imageSource.createPixelMap({
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
        desiredDynamicRange: image.DecodingDynamicRange.AUTO,
      });
    }

    const pixelInfo = pixelMap.getImageInfoSync();
    const actualWidth = pixelInfo.size.width;
    const actualHeight = pixelInfo.size.height;

    // stride 可能比 rowBytes 大（行对齐填充）
    const bytesPerPixel = 4; // RGBA_8888 / RGBA_1010102
    const rowBytes = actualWidth * bytesPerPixel;
    const stride = pixelInfo.stride ?? rowBytes;

    let buffer: ArrayBuffer = new ArrayBuffer(stride * actualHeight);
    pixelMap.readPixelsToBufferSync(buffer);
    const outStride = stride;
    return {
      buffer,
      width: actualWidth,
      height: actualHeight,
      rowBytes: outStride,
      isHdr: allowHdr ? pixelInfo.isHdr : false,
    };
  } finally {
    try { pixelMap?.release(); } catch (_) {}
    try { imageSource.release(); } catch (_) {}
  }
}
