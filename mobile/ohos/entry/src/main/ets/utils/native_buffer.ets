import nativeBuffer from 'libnative_buffer.so';
import { deviceInfo } from '@kit.BasicServicesKit';

export interface NativeBufferModule {
  alloc(size: number): number;
  free(ptr: number): void;
  allocCopy(buffer: ArrayBuffer): number;
}

const module = nativeBuffer as NativeBufferModule;
const isSupported = (() => {
  try {
    return deviceInfo.sdkApiVersion >= 10;
  } catch (_) {
    return false;
  }
})();

export function allocCopySafe(buffer: ArrayBuffer): number | undefined {
  if (!isSupported) {
    return undefined;
  }
  try {
    return module.allocCopy(buffer);
  } catch (_) {
    return undefined;
  }
}

export default module;
