import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { URLSessionManager } from '../../plugins/core/URLSessionManager';
import {
  delay,
  HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS,
  HYBRID_DEFERRED_REMOTE_WRITE_LIMIT,
  HYBRID_DEFERRED_REMOTE_WRITE_MAX_BYTES,
  HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES,
  HYBRID_REMOTE_THUMBNAIL_CACHE_DIR,
  HYBRID_REMOTE_THUMBNAIL_LEGACY_CACHE_DIR,
  HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES,
  HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_INTERVAL_MS,
  HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES,
  HybridDeferredRemoteWriteEntry,
  HybridRemoteCacheEntry,
  resolveHybridPrefetchConcurrency,
} from './HybridPhotoGridShared';

function hashString(input: string): string {
  let hash = 2166136261;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

function ensureRemoteThumbnailCacheDir(ctx: common.UIAbilityContext): string {
  const cacheDir = `${ctx.getApplicationContext().cacheDir}/${HYBRID_REMOTE_THUMBNAIL_CACHE_DIR}`;
  try {
    fs.mkdirSync(cacheDir);
  } catch (_) {
    // ignore if already exists
  }
  return cacheDir;
}

function legacyRemoteThumbnailCacheDir(ctx: common.UIAbilityContext): string {
  return `${ctx.getApplicationContext().cacheDir}/${HYBRID_REMOTE_THUMBNAIL_LEGACY_CACHE_DIR}`;
}

function remoteThumbnailCachePath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): string {
  const cacheDir = ensureRemoteThumbnailCacheDir(ctx);
  const cacheKey = `${requestSize}:${url}`;
  return `${cacheDir}/thumb_${hashString(cacheKey)}.img`;
}

function remoteThumbnailLegacyCachePath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): string {
  const cacheDir = legacyRemoteThumbnailCacheDir(ctx);
  const cacheKey = `${requestSize}:${url}`;
  return `${cacheDir}/thumb_${hashString(cacheKey)}.img`;
}

function remoteThumbnailTempPath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): string {
  return `${remoteThumbnailCachePath(ctx, url, requestSize)}.tmp`;
}

export class HybridScrollState {
  static isScrolling: boolean = false;
}

interface HybridRemoteCacheFileInfo {
  path: string;
  size: number;
  lastAccessAt: number;
}

function trackRemoteThumbnailCacheDir(
  cacheDir: string,
  files: Map<string, HybridRemoteCacheFileInfo>,
  now: number,
): number {
  let totalBytes = 0;
  try {
    const entries = fs.listFileSync(cacheDir);
    for (let index = 0; index < entries.length; index += 1) {
      const name = entries[index];
      const path = `${cacheDir}/${name}`;
      try {
        const stat = fs.statSync(path);
        if (!stat.isFile()) {
          continue;
        }

        if (name.endsWith('.tmp')) {
          deleteFileIfExists(path);
          continue;
        }

        files.set(path, {
          path: path,
          size: stat.size,
          lastAccessAt: stat.mtime > 0 ? stat.mtime : now,
        });
        totalBytes += stat.size;
      } catch (_) {
        // ignore individual stat failures
      }
    }
  } catch (_) {
    // ignore missing cache directory
  }

  return totalBytes;
}

function findExistingRemoteThumbnailCachePath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): string | undefined {
  const primaryPath = remoteThumbnailCachePath(ctx, url, requestSize);
  if (HybridRemoteThumbnailCacheIndex.hasCachePath(ctx, primaryPath)) {
    return primaryPath;
  }

  const legacyPath = remoteThumbnailLegacyCachePath(ctx, url, requestSize);
  if (HybridRemoteThumbnailCacheIndex.hasCachePath(ctx, legacyPath)) {
    return legacyPath;
  }

  return undefined;
}

export class HybridRemoteThumbnailCacheIndex {
  private static initialized: boolean = false;
  private static initializing: boolean = false;
  private static files: Map<string, HybridRemoteCacheFileInfo> = new Map();
  private static totalBytes: number = 0;

  static ensureInitialized(ctx: common.UIAbilityContext, force: boolean = false): void {
    if (HybridRemoteThumbnailCacheIndex.initialized || HybridRemoteThumbnailCacheIndex.initializing) {
      return;
    }

    if (!force && HybridScrollState.isScrolling) {
      return;
    }

    HybridRemoteThumbnailCacheIndex.initializing = true;
    try {
      const files: Map<string, HybridRemoteCacheFileInfo> = new Map();
      const now = Date.now();
      let totalBytes = trackRemoteThumbnailCacheDir(ensureRemoteThumbnailCacheDir(ctx), files, now);
      totalBytes += trackRemoteThumbnailCacheDir(legacyRemoteThumbnailCacheDir(ctx), files, now);

      HybridRemoteThumbnailCacheIndex.files = files;
      HybridRemoteThumbnailCacheIndex.totalBytes = totalBytes;
      HybridRemoteThumbnailCacheIndex.initialized = true;
    } catch (_) {
      // best-effort initialization
    } finally {
      HybridRemoteThumbnailCacheIndex.initializing = false;
    }
  }

  static hasCachePath(ctx: common.UIAbilityContext, path: string): boolean {
    const existing = HybridRemoteThumbnailCacheIndex.files.get(path);
    if (existing) {
      existing.lastAccessAt = Date.now();
      return true;
    }

    if (HybridRemoteThumbnailCacheIndex.initialized) {
      return false;
    }

    try {
      if (!fs.accessSync(path)) {
        return false;
      }

      const stat = fs.statSync(path);
      if (!stat.isFile()) {
        return false;
      }

      HybridRemoteThumbnailCacheIndex.files.set(path, {
        path: path,
        size: stat.size,
        lastAccessAt: Date.now(),
      });
      HybridRemoteThumbnailCacheIndex.totalBytes += stat.size;
      return true;
    } catch (_) {
      return false;
    }
  }

  static notePersisted(path: string, size: number): void {
    const previous = HybridRemoteThumbnailCacheIndex.files.get(path);
    if (previous) {
      HybridRemoteThumbnailCacheIndex.totalBytes -= previous.size;
    }

    HybridRemoteThumbnailCacheIndex.files.set(path, {
      path: path,
      size: size,
      lastAccessAt: Date.now(),
    });
    HybridRemoteThumbnailCacheIndex.totalBytes += size;
  }

  static noteRemoved(path: string): void {
    const previous = HybridRemoteThumbnailCacheIndex.files.get(path);
    if (!previous) {
      return;
    }

    HybridRemoteThumbnailCacheIndex.totalBytes = Math.max(0, HybridRemoteThumbnailCacheIndex.totalBytes - previous.size);
    HybridRemoteThumbnailCacheIndex.files.delete(path);
  }

  static markAccessed(path: string): void {
    const previous = HybridRemoteThumbnailCacheIndex.files.get(path);
    if (previous) {
      previous.lastAccessAt = Date.now();
    }
  }

  static totalTrackedBytes(ctx: common.UIAbilityContext, forceInit: boolean = false): number {
    HybridRemoteThumbnailCacheIndex.ensureInitialized(ctx, forceInit);
    return HybridRemoteThumbnailCacheIndex.totalBytes;
  }

  static sortedFilesByAccess(ctx: common.UIAbilityContext, forceInit: boolean = false): Array<HybridRemoteCacheFileInfo> {
    HybridRemoteThumbnailCacheIndex.ensureInitialized(ctx, forceInit);
    return Array.from(HybridRemoteThumbnailCacheIndex.files.values())
      .sort((left: HybridRemoteCacheFileInfo, right: HybridRemoteCacheFileInfo) => left.lastAccessAt - right.lastAccessAt);
  }
}

export class HybridRemoteThumbnailCachePruner {
  private static running: boolean = false;
  private static lastRunAt: number = 0;

  static trimIfNeeded(ctx: common.UIAbilityContext, force: boolean = false): void {
    const now = Date.now();
    if (!force && now - HybridRemoteThumbnailCachePruner.lastRunAt < HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_INTERVAL_MS) {
      return;
    }

    if (HybridRemoteThumbnailCachePruner.running) {
      return;
    }

    if (!force && HybridScrollState.isScrolling) {
      return;
    }

    HybridRemoteThumbnailCachePruner.running = true;
    HybridRemoteThumbnailCachePruner.lastRunAt = now;
    try {
      let totalBytes = HybridRemoteThumbnailCacheIndex.totalTrackedBytes(ctx, true);
      if (totalBytes <= HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES) {
        return;
      }

      const files = HybridRemoteThumbnailCacheIndex.sortedFilesByAccess(ctx, true);
      for (let index = 0; index < files.length && totalBytes > HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES; index += 1) {
        const file = files[index];
        deleteFileIfExists(file.path);
        HybridRemoteThumbnailCacheIndex.noteRemoved(file.path);
        totalBytes -= file.size;
      }
    } catch (_) {
      // best-effort trim
    } finally {
      HybridRemoteThumbnailCachePruner.running = false;
    }
  }
}

function deleteFileIfExists(path: string): void {
  try {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  } catch (_) {
    // ignore delete errors
  }
}

function writeBufferToFile(path: string, buffer: ArrayBuffer): void {
  const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
  try {
    fs.truncateSync(file.fd, 0);
    let written = 0;
    while (written < buffer.byteLength) {
      const chunk = written === 0 ? buffer : buffer.slice(written);
      const bytesWritten = fs.writeSync(file.fd, chunk);
      if (bytesWritten <= 0) {
        throw new Error(`failed to write file: ${path}`);
      }
      written += bytesWritten;
    }
    fs.truncateSync(file.fd, buffer.byteLength);
  } finally {
    try {
      fs.closeSync(file);
    } catch (_) {
      // ignore close errors
    }
  }
}

function persistRemoteThumbnailBuffer(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  data: ArrayBuffer,
): string {
  const cachePath = remoteThumbnailCachePath(ctx, url, requestSize);
  if (HybridRemoteThumbnailCacheIndex.hasCachePath(ctx, cachePath)) {
    return cachePath;
  }

  const tempPath = remoteThumbnailTempPath(ctx, url, requestSize);
  deleteFileIfExists(tempPath);
  try {
    writeBufferToFile(tempPath, data);
    try {
      fs.renameSync(tempPath, cachePath);
    } catch (_) {
      deleteFileIfExists(cachePath);
      fs.renameSync(tempPath, cachePath);
    }
    HybridRemoteThumbnailCacheIndex.notePersisted(cachePath, data.byteLength);
  } catch (error) {
    deleteFileIfExists(tempPath);
    throw error as Error;
  }

  return cachePath;
}

class HybridDeferredRemoteThumbnailWriter {
  private static entries: Map<string, HybridDeferredRemoteWriteEntry> = new Map();
  private static running: boolean = false;
  private static lastCtx?: common.UIAbilityContext;
  private static totalBytes: number = 0;

  private static buildKey(url: string, requestSize: number): string {
    return `${requestSize}:${url}`;
  }

  private static touchKey(key: string): void {
    const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    if (!entry) {
      return;
    }

    HybridDeferredRemoteThumbnailWriter.entries.delete(key);
    HybridDeferredRemoteThumbnailWriter.entries.set(key, entry);
  }

  private static trimOverflow(): void {
    while (
      HybridDeferredRemoteThumbnailWriter.entries.size > HYBRID_DEFERRED_REMOTE_WRITE_LIMIT ||
      HybridDeferredRemoteThumbnailWriter.totalBytes > HYBRID_DEFERRED_REMOTE_WRITE_MAX_BYTES
    ) {
      const oldestKey = HybridDeferredRemoteThumbnailWriter.entries.keys().next().value as string | undefined;
      if (!oldestKey) {
        break;
      }

      const oldestEntry = HybridDeferredRemoteThumbnailWriter.entries.get(oldestKey);
      HybridDeferredRemoteThumbnailWriter.entries.delete(oldestKey);
      if (!oldestEntry) {
        continue;
      }
      HybridDeferredRemoteThumbnailWriter.totalBytes = Math.max(
        0,
        HybridDeferredRemoteThumbnailWriter.totalBytes - oldestEntry.data.byteLength,
      );
    }
  }

  static hasPending(
    url: string,
    requestSize: number,
  ): boolean {
    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const hasEntry = HybridDeferredRemoteThumbnailWriter.entries.has(key);
    if (hasEntry) {
      HybridDeferredRemoteThumbnailWriter.touchKey(key);
    }
    return hasEntry;
  }

  static peekData(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    if (!entry) {
      return undefined;
    }

    HybridDeferredRemoteThumbnailWriter.touchKey(key);
    return entry.data;
  }

  static takeData(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    if (!entry) {
      return undefined;
    }

    HybridDeferredRemoteThumbnailWriter.entries.delete(key);
    HybridDeferredRemoteThumbnailWriter.totalBytes = Math.max(
      0,
      HybridDeferredRemoteThumbnailWriter.totalBytes - entry.data.byteLength,
    );
    return entry.data;
  }

  static enqueue(
    ctx: common.UIAbilityContext,
    url: string,
    requestSize: number,
    data: ArrayBuffer,
  ): void {
    const cachePath = remoteThumbnailCachePath(ctx, url, requestSize);
    if (HybridRemoteThumbnailCacheIndex.hasCachePath(ctx, cachePath)) {
      return;
    }

    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const previous = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    HybridDeferredRemoteThumbnailWriter.lastCtx = ctx;
    if (previous) {
      HybridDeferredRemoteThumbnailWriter.totalBytes = Math.max(
        0,
        HybridDeferredRemoteThumbnailWriter.totalBytes - previous.data.byteLength,
      );
      HybridDeferredRemoteThumbnailWriter.entries.delete(key);
    }
    HybridDeferredRemoteThumbnailWriter.entries.set(key, {
      ctx: ctx,
      url: url,
      requestSize: requestSize,
      data: data,
    });
    HybridDeferredRemoteThumbnailWriter.totalBytes += data.byteLength;
    HybridDeferredRemoteThumbnailWriter.trimOverflow();
  }

  static flushIfIdle(): void {
    if (HybridScrollState.isScrolling || HybridDeferredRemoteThumbnailWriter.running) {
      return;
    }

    if (HybridDeferredRemoteThumbnailWriter.entries.size === 0) {
      return;
    }

    HybridDeferredRemoteThumbnailWriter.running = true;
    void HybridDeferredRemoteThumbnailWriter.run().finally(() => {
      HybridDeferredRemoteThumbnailWriter.running = false;
    });
  }

  private static async run(): Promise<void> {
    while (!HybridScrollState.isScrolling && HybridDeferredRemoteThumbnailWriter.entries.size > 0) {
      const oldestKey = HybridDeferredRemoteThumbnailWriter.entries.keys().next().value as string | undefined;
      if (!oldestKey) {
        break;
      }

      const entry = HybridDeferredRemoteThumbnailWriter.entries.get(oldestKey);
      HybridDeferredRemoteThumbnailWriter.entries.delete(oldestKey);
      if (!entry) {
        continue;
      }

      try {
        persistRemoteThumbnailBuffer(entry.ctx, entry.url, entry.requestSize, entry.data);
      } catch (_) {
        // best-effort deferred write
      }

      await delay(HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
    }

    const ctx = HybridDeferredRemoteThumbnailWriter.lastCtx;
    if (ctx && !HybridScrollState.isScrolling) {
      HybridRemoteThumbnailCachePruner.trimIfNeeded(ctx);
    }
    HybridDeferredRemoteThumbnailWriter.lastCtx = undefined;
  }
}

async function decodeRemoteThumbnailFromFile(
  filePath: string,
  requestSize: number,
): Promise<PixelMap> {
  HybridRemoteThumbnailCacheIndex.markAccessed(filePath);
  const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
  let buffer: ArrayBuffer | undefined = undefined;
  try {
    const stat = fs.statSync(file.fd);
    if (stat.size <= 0) {
      throw new Error(`cached thumbnail is empty: ${filePath}`);
    }

    buffer = new ArrayBuffer(stat.size);
    const bytesRead = fs.readSync(file.fd, buffer);
    if (bytesRead <= 0) {
      throw new Error(`failed to read cached thumbnail: ${filePath}`);
    }

    return await decodeRemoteThumbnailFromBuffer(
      bytesRead === stat.size ? buffer : buffer.slice(0, bytesRead),
      requestSize,
    );
  } finally {
    try {
      fs.closeSync(file);
    } catch (_) {}
  }
}

async function decodeRemoteThumbnailFromBuffer(
  data: ArrayBuffer,
  requestSize: number,
): Promise<PixelMap> {
  const source = image.createImageSource(data);
  try {
    const imageInfo = await source.getImageInfo();
    const sourceWidth = Math.max(1, Math.round(imageInfo.size.width));
    const sourceHeight = Math.max(1, Math.round(imageInfo.size.height));
    const scale = Math.min(requestSize / sourceWidth, requestSize / sourceHeight);
    const desiredWidth = Math.max(1, Math.round(sourceWidth * scale));
    const desiredHeight = Math.max(1, Math.round(sourceHeight * scale));

    return await source.createPixelMap({
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      desiredSize: {
        width: desiredWidth,
        height: desiredHeight,
      },
    });
  } finally {
    try {
      source.release();
    } catch (_) {}
  }
}

export function hasRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): boolean {
  return findExistingRemoteThumbnailCachePath(ctx, url, requestSize) !== undefined ||
    HybridDeferredRemoteThumbnailWriter.hasPending(url, requestSize);
}

export async function loadRemoteThumbnail(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): Promise<PixelMap> {
  const cachePath = findExistingRemoteThumbnailCachePath(ctx, url, requestSize);
  if (cachePath) {
    try {
      return await decodeRemoteThumbnailFromFile(cachePath, requestSize);
    } catch (_) {
      deleteFileIfExists(cachePath);
      HybridRemoteThumbnailCacheIndex.noteRemoved(cachePath);
    }
  }

  const pendingData = HybridDeferredRemoteThumbnailWriter.peekData(url, requestSize);
  if (pendingData) {
    return await decodeRemoteThumbnailFromBuffer(pendingData, requestSize);
  }

  const request = http.createHttp();
  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    maxLimit: 8 * 1024 * 1024,
  };
  URLSessionManager.applyToOptions(ctx.getApplicationContext(), options, url);

  try {
    const response = await request.request(url, options);
    URLSessionManager.updateFromResponse(
      ctx.getApplicationContext(),
      url,
      response.header as Object | undefined,
    );

    if (response.responseCode < 200 || response.responseCode > 299) {
      throw new Error(`HTTP ${response.responseCode}`);
    }

    const data = response.result as ArrayBuffer;
    if (!data || data.byteLength === 0) {
      throw new Error('Remote thumbnail response is empty');
    }

    if (HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      HybridDeferredRemoteThumbnailWriter.enqueue(ctx, url, requestSize, data);
    }

    return await decodeRemoteThumbnailFromBuffer(data, requestSize);
  } finally {
    request.destroy();
  }
}

export async function ensureRemoteThumbnailCached(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): Promise<string> {
  if (!HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
    return '';
  }

  const existingCachePath = findExistingRemoteThumbnailCachePath(ctx, url, requestSize);
  if (existingCachePath) {
    return existingCachePath;
  }

  const cachePath = remoteThumbnailCachePath(ctx, url, requestSize);
  const pendingData = HybridDeferredRemoteThumbnailWriter.peekData(url, requestSize);
  if (pendingData) {
    if (HybridScrollState.isScrolling) {
      return cachePath;
    }

    const persistData = HybridDeferredRemoteThumbnailWriter.takeData(url, requestSize) ?? pendingData;
    return persistRemoteThumbnailBuffer(ctx, url, requestSize, persistData);
  }

  const request = http.createHttp();
  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    maxLimit: 8 * 1024 * 1024,
  };
  URLSessionManager.applyToOptions(ctx.getApplicationContext(), options, url);

  try {
    const response = await request.request(url, options);
    URLSessionManager.updateFromResponse(
      ctx.getApplicationContext(),
      url,
      response.header as Object | undefined,
    );

    if (response.responseCode < 200 || response.responseCode > 299) {
      throw new Error(`HTTP ${response.responseCode}`);
    }

    const data = response.result as ArrayBuffer;
    if (!data || data.byteLength === 0) {
      throw new Error('Remote thumbnail response is empty');
    }
    if (HybridScrollState.isScrolling) {
      HybridDeferredRemoteThumbnailWriter.enqueue(ctx, url, requestSize, data);
      return cachePath;
    }
    return persistRemoteThumbnailBuffer(ctx, url, requestSize, data);
  } finally {
    request.destroy();
  }
}

export class HybridRemoteThumbnailBackgroundPredownload {
  private static entries: Map<string, HybridRemoteCacheEntry> = new Map();

  static async predownload(
    ctx: common.UIAbilityContext,
    url: string,
    requestSize: number,
  ): Promise<void> {
    if (!HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return;
    }

    if (hasRemoteThumbnailCache(ctx, url, requestSize)) {
      return;
    }

    const key = `${requestSize}:${url}`;
    const existing = HybridRemoteThumbnailBackgroundPredownload.entries.get(key);
    if (existing?.downloadingPromise) {
      await existing.downloadingPromise;
      return;
    }

    const entry: HybridRemoteCacheEntry = existing ?? {};
    entry.downloadingPromise = HybridBackgroundPredownloadLimiter.run(() =>
      ensureRemoteThumbnailCached(ctx, url, requestSize)
    )
      .then(() => {})
      .catch(() => {})
      .finally(() => {
        const current = HybridRemoteThumbnailBackgroundPredownload.entries.get(key);
        if (current) {
          current.downloadingPromise = undefined;
          HybridRemoteThumbnailBackgroundPredownload.entries.delete(key);
        }
      });

    HybridRemoteThumbnailBackgroundPredownload.entries.set(key, entry);
    await entry.downloadingPromise;
  }
}

class HybridBackgroundPredownloadLimiter {
  private static activeCount: number = 0;
  private static waiters: Array<() => void> = [];

  static async run<T>(task: () => Promise<T>): Promise<T> {
    await HybridBackgroundPredownloadLimiter.acquire();
    try {
      return await task();
    } finally {
      HybridBackgroundPredownloadLimiter.release();
    }
  }

  private static async acquire(): Promise<void> {
    if (HybridBackgroundPredownloadLimiter.tryAcquire()) {
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      HybridBackgroundPredownloadLimiter.waiters.push(resolve);
    });
  }

  private static tryAcquire(): boolean {
    if (HybridBackgroundPredownloadLimiter.activeCount >= resolveHybridPrefetchConcurrency()) {
      return false;
    }

    HybridBackgroundPredownloadLimiter.activeCount += 1;
    return true;
  }

  private static release(): void {
    if (HybridBackgroundPredownloadLimiter.activeCount > 0) {
      HybridBackgroundPredownloadLimiter.activeCount -= 1;
    }

    if (
      HybridBackgroundPredownloadLimiter.waiters.length > 0 &&
      HybridBackgroundPredownloadLimiter.tryAcquire()
    ) {
      const waiter = HybridBackgroundPredownloadLimiter.waiters.shift();
      waiter?.();
    }
  }
}

export function flushDeferredThumbnailWritesIfIdle(): void {
  HybridDeferredRemoteThumbnailWriter.flushIfIdle();
}
