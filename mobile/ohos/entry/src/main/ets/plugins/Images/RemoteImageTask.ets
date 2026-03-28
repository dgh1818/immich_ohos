import { image } from '@kit.ImageKit';
import nativeBuffer from '../../utils/native_buffer';

export interface RemoteDecodeResult {
  pointer: number;
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
    const length = buffer.byteLength;
    if (length <= 0) {
      throw new Error(`decoded remote image (${actualWidth}x${actualHeight}, stride=${outStride}) buffer is empty`);
    }

    const pointer = nativeBuffer.allocate(length);
    if (pointer === 0) {
      throw new Error(
        `decoded remote image (${actualWidth}x${actualHeight}, stride=${outStride}, bytes=${length}) native pointer allocation failed`,
      );
    }

    try {
      const copied = nativeBuffer.copy(buffer, pointer, 0, length);
      if (copied !== length) {
        throw new Error(
          `decoded remote image (${actualWidth}x${actualHeight}, stride=${outStride}, bytes=${length}) native copy failed`,
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
      rowBytes: outStride,
      isHdr: allowHdr ? pixelInfo.isHdr : false,
    };
  } finally {
    try { pixelMap?.release(); } catch (_) {}
    try { imageSource.release(); } catch (_) {}
  }
}
