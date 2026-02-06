import { RemoteImageApiOhos, Result } from './RemoteImages.g';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { taskpool } from '@kit.ArkTS';
import { decodeRemoteImageTask, RemoteDecodeResult } from './RemoteImageTask';
import nativeBuffer, { allocCopySafe } from '../../utils/native_buffer';
import { common } from '@kit.AbilityKit';
import { URLSessionManager } from '../core/URLSessionManager';

interface RemoteRequestState {
  request: http.HttpRequest;
  cancelled: boolean;
}

export class RemoteImagesImpl extends RemoteImageApiOhos {
  private requestMap = new Map<number, RemoteRequestState>();
  private cache = new Map<string, ArrayBuffer>();
  private cacheBytes = 0;
  private readonly maxCacheBytes = 64 * 1024 * 1024;
  private ctx?: common.Context;

  constructor(context?: common.Context) {
    super();
    this.ctx = context;
  }

  override async requestImage(
  url: string,
  headers: Map<string, string>,
  requestId: number,
  result: Result<Map<string, Object>>
) {
  const sizeKind = this.getRemoteSizeKind(url);
  // 1) Cache hit
  const cached = this.cache.get(url);
  if (cached) {
    // 防历史“毒化缓存”（旧版本曾 transfer 过）
    if (cached.byteLength === 0) {
      this.cache.delete(url);
    } else {
      if (sizeKind === 'thumbnail') {
        const encoded = new Map<string, Object>();
        const pointer = allocCopySafe(cached);
        if (pointer) {
          encoded.set('pointer', pointer);
        } else {
          encoded.set('pointer', new Uint8Array(cached));
        }
        encoded.set('length', cached.byteLength);
        return result.success(encoded);
      }
      try {
        const decoded = await this.decodeBuffer(cached, sizeKind);
        return result.success(decoded);
      } catch (_) {
        // 这里不需要额外拷贝：decodeBuffer 已经隔离 transfer，cached 不会�?detach
        const fallback = new Map<string, Object>();
        const pointer = allocCopySafe(cached);
        if (pointer) {
          fallback.set('pointer', pointer);
        } else {
          fallback.set('pointer', new Uint8Array(cached));
        }
        fallback.set('length', cached.byteLength);
        return result.success(fallback);
      }
    }
  }

  // 2) HTTP request
  const request = http.createHttp();
  const state: RemoteRequestState = { request, cancelled: false };
  this.requestMap.set(requestId, state);

  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    header: this.toHeaderRecord(headers),
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    // allow responses larger than default 5MB limit
    maxLimit: 64 * 1024 * 1024,
  };
  URLSessionManager.applyToOptions(this.ctx, options);

  try {
    const response = await request.request(url, options);

    if (state.cancelled) {
      return result.success(new Map<string, Object>());
    }
    if (response.responseCode < 200 || response.responseCode > 299) {
      return result.error(new Error(`HTTP ${response.responseCode}`));
    }

    const data = response.result as ArrayBuffer;

    if (state.cancelled) {
      return result.success(new Map<string, Object>());
    }
    if (!data || data.byteLength === 0) {
      return result.error(new Error('HTTP result is empty/detached (byteLength == 0)'));
    }

    //this.storeCache(url, data);

    // 4) Decode (or return encoded bytes for thumbnails)
    try {
      if (sizeKind === 'thumbnail') {
        const encoded = new Map<string, Object>();
        const pointer = allocCopySafe(data);
        if (pointer) {
          encoded.set('pointer', pointer);
        } else {
          encoded.set('pointer', new Uint8Array(data));
        }
        encoded.set('length', data.byteLength);
        return result.success(encoded);
      }
      const decoded = await this.decodeBuffer(data, sizeKind);

      if (state.cancelled) {
        return result.success(new Map<string, Object>());
      }
      return result.success(decoded);
    } catch (_) {
      if (state.cancelled) {
        return result.success(new Map<string, Object>());
      }

      const fallback = new Map<string, Object>();
      const pointer = allocCopySafe(data);
      if (pointer) {
        fallback.set('pointer', pointer);
      } else {
        fallback.set('pointer', new Uint8Array(data));
      }
      fallback.set('length', data.byteLength);
      return result.success(fallback);
    }
  } catch (e) {
    if (state.cancelled) {
      return result.success(new Map<string, Object>());
    }
    return result.error(e as BusinessError);
  } finally {
    request.destroy();
    this.requestMap.delete(requestId);
  }
}

  private async decodeBuffer(data: ArrayBuffer, sizeKind: string): Promise<Map<string, Object>> {
  if (!data || data.byteLength === 0) {
    throw new Error('detached buffer (input byteLength == 0)');
  }

  const input = data.slice(0);

  const allowHdr = sizeKind === 'full';
  const task: taskpool.Task = new taskpool.Task(decodeRemoteImageTask, input, allowHdr);
  try {
    const priority = sizeKind === 'preview' ? taskpool.Priority.MEDIUM : taskpool.Priority.HIGH;
    const executor = taskpool.execute(task, priority);

    const processed = (await executor) as RemoteDecodeResult;

    const resOut = new Map<string, Object>();
    const pointer = allocCopySafe(processed.buffer);
    if (pointer) {
      resOut.set('pointer', pointer);
    } else {
      resOut.set('pointer', new Uint8Array(processed.buffer));
    }
    resOut.set('width', processed.width);
    resOut.set('height', processed.height);
    resOut.set('rowBytes', processed.rowBytes);
    resOut.set('isHdr', processed.isHdr);
    return resOut;
  } finally {
    taskpool.terminateTask(task);
  }
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
    this.requestMap.delete(requestId);
  }

  override clearCache(result: Result<number>) {
    const clearedBytes = this.cacheBytes;
    this.cache.clear();
    this.cacheBytes = 0;
    result.success(clearedBytes);
  }

  private getRemoteSizeKind(url: string): string {
    if (url.includes('size=thumbnail')) {
      return 'thumbnail';
    }
    if (url.includes('size=preview')) {
      return 'preview';
    }
    return 'full';
  }

  private toHeaderRecord(headers: Map<string, string>): Record<string, string> {
    const out: Record<string, string> = {};
    headers.forEach((value, key) => {
      out[key] = value;
    });
    return out;
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
