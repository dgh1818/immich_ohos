import { RemoteImageApiOhos, Result } from './RemoteImages.g';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import nativeBuffer, { INITIAL_BUFFER_SIZE, NativeByteBuffer } from '../../utils/native_buffer';
import { URLSessionManager } from '../core/URLSessionManager';

interface RemoteRequestState {
  request: http.HttpRequest;
  cancelled: boolean;
  buffer?: NativeByteBuffer;
}

export class RemoteImagesImpl extends RemoteImageApiOhos {
  private requestMap = new Map<number, RemoteRequestState>();
  private cache = new Map<string, ArrayBuffer>();
  private cacheBytes = 0;
  private readonly maxCacheBytes = 64 * 1024 * 1024;
  private ctx?: common.Context;

  private static toNativeBuffer(buffer: ArrayBuffer, label: string): number {
    const length = buffer.byteLength;
    if (length <= 0) {
      throw new Error(`${label} buffer is empty`);
    }

    const pointer = nativeBuffer.allocate(length);
    if (pointer === 0) {
      throw new Error(`${label} native pointer allocation failed`);
    }

    try {
      const copied = nativeBuffer.copy(buffer, pointer, 0, length);
      if (copied !== length) {
        throw new Error(`${label} native copy failed`);
      }
      return pointer;
    } catch (error) {
      try {
        nativeBuffer.free(pointer);
      } catch (_) {}
      throw error as Error;
    }
  }

  constructor(context?: common.Context) {
    super();
    this.ctx = context;
  }

  override async requestImage(
    url: string,
    requestId: number,
    preferEncoded: boolean,
    result: Result<Map<string, Object>>
  ) {
    // 1) Cache hit
    const cached = this.cache.get(url);
    if (cached) {
      if (cached.byteLength === 0) {
        this.cache.delete(url);
      } else {
        const encoded = new Map<string, Object>();
        const pointer = RemoteImagesImpl.toNativeBuffer(cached, 'cached encoded remote image');
        encoded.set('pointer', pointer);
        encoded.set('length', cached.byteLength);
        return result.success(encoded);
      }
    }

    // 2) HTTP request
    const request = http.createHttp();
    const state: RemoteRequestState = { request, cancelled: false };
    this.requestMap.set(requestId, state);

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      // allow responses larger than default 5MB limit
      maxLimit: 64 * 1024 * 1024,
    };
    URLSessionManager.applyToOptions(this.ctx, options, url);

    try {
      if (state.cancelled) {
        return result.success(new Map<string, Object>());
      }
      const encoded = await this.requestEncoded(url, state, options);
      if (state.cancelled) {
        const pointer = encoded.get('pointer') as number | undefined;
        if (pointer !== undefined && pointer !== 0) {
          try {
            nativeBuffer.free(pointer);
          } catch (_) {}
        }
        return result.success(new Map<string, Object>());
      }
      return result.success(encoded);
    } catch (e) {
      if (state.cancelled) {
        this.cleanupBuffer(state);
        return result.success(new Map<string, Object>());
      }
      return result.error(e as BusinessError);
    } finally {
      request.destroy();
      this.requestMap.delete(requestId);
    }
  }

  private async requestEncoded(
    url: string,
    state: RemoteRequestState,
    options: http.HttpRequestOptions,
  ): Promise<Map<string, Object>> {
    let settled = false;

    const streamDone = new Promise<void>((resolve, reject) => {
      const rejectStream = (error: Error) => {
        if (settled) {
          return;
        }
        settled = true;
        try {
          state.request.destroy();
        } catch (_) {}
        reject(error);
      };

      state.request.on('dataReceive', (chunk: ArrayBuffer) => {
        if (settled || state.cancelled) {
          return;
        }
        try {
          if (!chunk || chunk.byteLength === 0) {
            return;
          }
          if (!state.buffer) {
            state.buffer = new NativeByteBuffer(Math.max(chunk.byteLength, INITIAL_BUFFER_SIZE));
          }
          state.buffer.append(chunk, 'encoded remote image');
        } catch (e) {
          rejectStream(e as Error);
        }
      });

      state.request.on('dataEnd', () => {
        if (settled) {
          return;
        }
        settled = true;
        resolve();
      });
    });
    streamDone.catch(() => {});

    let responseCode = 0;
    try {
      responseCode = await state.request.requestInStream(url, options);
    } catch (error) {
      this.cleanupBuffer(state);
      throw error as Error;
    }

    if (responseCode < 200 || responseCode > 299) {
      this.cleanupBuffer(state);
      throw new Error(`HTTP ${responseCode}`);
    }

    try {
      await streamDone;
    } catch (error) {
      this.cleanupBuffer(state);
      throw error as Error;
    }
    if (state.cancelled) {
      this.cleanupBuffer(state);
      return new Map<string, Object>();
    }

    const buffer = state.buffer;
    state.buffer = undefined;
    if (!buffer || buffer.offset <= 0) {
      try {
        buffer?.free();
      } catch (_) {}
      throw new Error('HTTP result is empty/detached (byteLength == 0)');
    }

    const encoded = new Map<string, Object>();
    encoded.set('pointer', buffer.pointer);
    encoded.set('length', buffer.offset);
    buffer.pointer = 0;
    buffer.capacity = 0;
    buffer.offset = 0;
    return encoded;
  }

  override cancelRequest(requestId: number) {
    const state = this.requestMap.get(requestId);
    if (!state) {
      return;
    }
    state.cancelled = true;
    try {
      state.request.destroy();
    } catch (_) {}
    this.cleanupBuffer(state);
    this.requestMap.delete(requestId);
  }

  override clearCache(result: Result<number>) {
    const clearedBytes = this.cacheBytes;
    this.cache.clear();
    this.cacheBytes = 0;
    result.success(clearedBytes);
  }

  private cleanupBuffer(state: RemoteRequestState) {
    const buffer = state.buffer;
    state.buffer = undefined;
    if (!buffer) {
      return;
    }
    try {
      buffer.free();
    } catch (_) {}
  }

  private storeCache(url: string, data: ArrayBuffer) {
    const size = data.byteLength;
    if (size <= 0 || size > this.maxCacheBytes) {
      return;
    }
    while (this.cacheBytes + size > this.maxCacheBytes && this.cache.size > 0) {
      const oldestKey: string | undefined = this.cache.keys().next().value as string | undefined;
      if (oldestKey === undefined) {
        break;
      }
      const oldest = this.cache.get(oldestKey);
      if (oldest) {
        this.cacheBytes -= oldest.byteLength;
      }
      this.cache.delete(oldestKey);
    }
    const copy = data.slice(0);
    this.cache.set(url, copy);
    this.cacheBytes += copy.byteLength;
  }
}
