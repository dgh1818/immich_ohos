import { RemoteImageApiOhos, Result } from './RemoteImages.g';
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import nativeBuffer, { INITIAL_BUFFER_SIZE, NativeByteBuffer } from '../../utils/native_buffer';
import { URLSessionManager } from '../core/URLSessionManager';

const MAX_REMOTE_IMAGE_REQUESTS = 6;

interface RemoteRequestState {
  request: http.HttpRequest;
  cancelled: boolean;
  buffer?: NativeByteBuffer;
}

export class RemoteImagesImpl extends RemoteImageApiOhos {
  private requestMap = new Map<number, RemoteRequestState>();
  private activeRequests = 0;
  private pendingRequests: Array<() => void> = [];
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

    let slotAcquired = false;
    try {
      await this.acquireRequestSlot();
      slotAcquired = true;

      if (state.cancelled) {
        return result.success(new Map<string, Object>());
      }
      const encoded = this.usesMtlsFetcher()
        ? await this.requestEncodedInStream(url, state, options)
        : await this.requestEncoded(url, state, options);
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
      if (slotAcquired) {
        this.releaseRequestSlot();
      }
      request.destroy();
      this.requestMap.delete(requestId);
    }
  }

  private async requestEncoded(
    url: string,
    state: RemoteRequestState,
    options: http.HttpRequestOptions,
  ): Promise<Map<string, Object>> {
    let responseCode = 0;
    let resultBuffer: ArrayBuffer | undefined = undefined;
    try {
      const response = await state.request.request(url, options);
      responseCode = response.responseCode;
      URLSessionManager.updateFromResponse(this.ctx, url, response.header as Object | undefined);
      resultBuffer = response.result as ArrayBuffer;
    } catch (error) {
      throw error as Error;
    }

    if (responseCode < 200 || responseCode > 299) {
      throw new Error(RemoteImagesImpl.formatHttpError(responseCode, resultBuffer));
    }
    if (state.cancelled) {
      return new Map<string, Object>();
    }
    if (!resultBuffer || resultBuffer.byteLength <= 0) {
      throw new Error('HTTP result is empty/detached (byteLength == 0)');
    }

    const encoded = new Map<string, Object>();
    encoded.set('pointer', RemoteImagesImpl.toNativeBuffer(resultBuffer, 'encoded remote image'));
    encoded.set('length', resultBuffer.byteLength);
    return encoded;
  }

  // Mirror upstream Android's OkHttpImageFetcher path for mTLS, which reads
  // the response body incrementally instead of using the normal request().
  private async requestEncodedInStream(
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

      state.request.on('headersReceive', (headerObj: Object) => {
        if (settled || state.cancelled) {
          return;
        }
        URLSessionManager.updateFromResponse(this.ctx, url, headerObj);
      });

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
      throw new Error(RemoteImagesImpl.formatHttpError(responseCode));
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
    result.success(0);
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

  private acquireRequestSlot(): Promise<void> {
    if (this.activeRequests < MAX_REMOTE_IMAGE_REQUESTS) {
      this.activeRequests += 1;
      return Promise.resolve();
    }

    return new Promise<void>((resolve) => {
      this.pendingRequests.push(resolve);
    });
  }

  private releaseRequestSlot(): void {
    const resolve = this.pendingRequests.shift();
    if (resolve) {
      resolve();
      return;
    }
    this.activeRequests = Math.max(0, this.activeRequests - 1);
  }

  private usesMtlsFetcher(): boolean {
    const ctx = this.ctx;
    return ctx !== undefined && URLSessionManager.hasCertificate(ctx);
  }

  private static formatHttpError(statusCode: number, body?: ArrayBuffer): string {
    return `HTTP ${statusCode} ${RemoteImagesImpl.httpReason(statusCode)}${RemoteImagesImpl.httpBodyPreview(body)}`;
  }

  private static httpReason(statusCode: number): string {
    switch (statusCode) {
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found: image media is missing, not generated yet, or inaccessible';
      case 408:
        return 'Request Timeout';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        return 'Error';
    }
  }

  private static httpBodyPreview(body?: ArrayBuffer): string {
    if (!body || body.byteLength <= 0) {
      return '';
    }

    const bytes = new Uint8Array(body);
    const maxLength = Math.min(bytes.length, 512);
    let preview = '';
    for (let i = 0; i < maxLength; i++) {
      const byte = bytes[i];
      if (byte === 9 || byte === 10 || byte === 13) {
        preview += ' ';
      } else if (byte >= 32 && byte <= 126) {
        preview += String.fromCharCode(byte);
      } else {
        preview += '.';
      }
    }

    const trimmed = preview.trim();
    if (trimmed.length === 0) {
      return '';
    }
    return `, body=${trimmed}${bytes.length > maxLength ? '...' : ''}`;
  }
}
