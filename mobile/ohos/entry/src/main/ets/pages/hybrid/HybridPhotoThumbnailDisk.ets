import { taskpool } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { image, sendableImage } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { URLSessionManager } from '../../plugins/core/URLSessionManager';
import {
  delay,
  HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS,
  HYBRID_COMPRESSED_BUFFER_CACHE_MAX_BYTES,
  HYBRID_COMPRESSED_BUFFER_CACHE_IDLE_TARGET_BYTES,
  HYBRID_MAX_CONCURRENT_BACKGROUND_PREDOWNLOADS,
  HYBRID_MAX_CONCURRENT_INITIAL_REMOTE_PREDOWNLOADS,
  HYBRID_MAX_CONCURRENT_NEARBY_REMOTE_PREDOWNLOADS,
  HYBRID_DEFERRED_REMOTE_WRITE_LIMIT,
  HYBRID_DEFERRED_REMOTE_WRITE_MAX_BYTES,
  HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES,
  HYBRID_REMOTE_THUMBNAIL_CACHE_DIR,
  HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES,
  HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_INTERVAL_MS,
  HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES,
  HybridDeferredRemoteWriteEntry,
  HybridRemoteCacheEntry,
} from './HybridPhotoGridShared';

let remoteThumbnailCacheDirPath: string | undefined = undefined;
let remoteThumbnailCacheDirEnsured: boolean = false;
const remoteThumbnailPathCache: Map<string, string> = new Map();
const HYBRID_DEFERRED_REMOTE_WRITE_HIGH_WATER_PERCENT: number = 75;
const HYBRID_ENABLE_ASTC_REMOTE_THUMBNAILS: boolean = true;
const HYBRID_ASTC_REMOTE_THUMBNAIL_MAX_REQUEST_SIZE: number = 256;
const HYBRID_REMOTE_THUMBNAIL_REQUEST_SIZES: Array<number> = [96, 128, 160, 192, 224];

function hashString(input: string): string {
  let hash = 2166136261;
  for (let index = 0; index < input.length; index += 1) {
    hash ^= input.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(16).padStart(8, '0');
}

function buildRemoteThumbnailCacheKey(url: string, requestSize: number): string {
  return `${requestSize}:${url}`;
}

function resolveCanonicalRemoteThumbnailRequestSize(): number {
  return HYBRID_REMOTE_THUMBNAIL_REQUEST_SIZES[HYBRID_REMOTE_THUMBNAIL_REQUEST_SIZES.length - 1];
}

function buildPersistedRemoteThumbnailCacheKey(url: string): string {
  return buildRemoteThumbnailCacheKey(url, resolveCanonicalRemoteThumbnailRequestSize());
}

function resolveAlternateRemoteThumbnailRequestSizes(requestSize: number): Array<number> {
  const largerSizes: Array<number> = [];
  const smallerSizes: Array<number> = [];
  for (let index = 0; index < HYBRID_REMOTE_THUMBNAIL_REQUEST_SIZES.length; index += 1) {
    const size = HYBRID_REMOTE_THUMBNAIL_REQUEST_SIZES[index];
    if (size === requestSize) {
      continue;
    }
    if (size > requestSize) {
      largerSizes.push(size);
      continue;
    }
    smallerSizes.unshift(size);
  }
  return largerSizes.concat(smallerSizes);
}

function formatRemoteThumbnailRequestSizeFamily(requestSize: number): string {
  return [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize)).join(',');
}

function describeRemoteThumbnailSourceKind(sourceKind: HybridRemoteThumbnailSourceKind): string {
  if (sourceKind === HybridRemoteThumbnailSourceKind.PERSISTED_FILE) {
    return 'persisted-file';
  }
  if (sourceKind === HybridRemoteThumbnailSourceKind.PENDING_WRITE) {
    return 'pending-write';
  }
  if (sourceKind === HybridRemoteThumbnailSourceKind.NETWORK_MISS) {
    return 'network-miss';
  }
  return 'none';
}

function describeRemoteThumbnailLoadKind(loadKind: HybridRemoteThumbnailLoadKind): string {
  if (loadKind === HybridRemoteThumbnailLoadKind.VISIBLE) {
    return 'visible';
  }
  return 'prefetch';
}

function ensureRemoteThumbnailCacheDir(ctx: common.UIAbilityContext): string {
  if (!remoteThumbnailCacheDirPath) {
    remoteThumbnailCacheDirPath = `${ctx.getApplicationContext().cacheDir}/${HYBRID_REMOTE_THUMBNAIL_CACHE_DIR}`;
  }

  if (!remoteThumbnailCacheDirEnsured) {
    try {
      fs.mkdirSync(remoteThumbnailCacheDirPath);
    } catch (_) {
      // ignore if already exists
    }
    remoteThumbnailCacheDirEnsured = true;
  }

  return remoteThumbnailCacheDirPath;
}

function remoteThumbnailCachePath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): string {
  void requestSize;
  const cacheKey = buildPersistedRemoteThumbnailCacheKey(url);
  const cachedPath = remoteThumbnailPathCache.get(cacheKey);
  if (cachedPath) {
    return cachedPath;
  }

  const resolvedPath = `${ensureRemoteThumbnailCacheDir(ctx)}/thumb_${hashString(cacheKey)}.img`;
  remoteThumbnailPathCache.set(cacheKey, resolvedPath);
  return resolvedPath;
}

function remoteThumbnailTempPath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): string {
  return `${remoteThumbnailCachePath(ctx, url, requestSize)}.tmp`;
}

function cloneRemoteThumbnailBuffer(data: ArrayBuffer): ArrayBuffer {
  return data.slice(0);
}

export class HybridScrollState {
  static isScrolling: boolean = false;
}

export enum HybridRemoteThumbnailLoadKind {
  VISIBLE = 0,
  PREFETCH = 1,
}

export enum HybridRemoteThumbnailSourceKind {
  NONE = 0,
  PERSISTED_FILE = 1,
  PENDING_WRITE = 2,
  NETWORK_MISS = 3,
}

export enum HybridRemoteThumbnailLoadPath {
  NONE = 0,
  COMPRESSED_BUFFER = 1,
  DEFERRED_WRITE = 2,
  PERSISTED_FILE = 3,
  NETWORK = 4,
}

export enum HybridRemotePredownloadPriorityHint {
  NEARBY = 0,
  INITIAL = 1,
  BACKGROUND = 2,
}

export interface HybridRemoteThumbnailLoadResult {
  pixelMap: PixelMap;
  sourceKind: HybridRemoteThumbnailSourceKind;
  loadPath: HybridRemoteThumbnailLoadPath;
}

interface HybridCompressedRemoteThumbnailBufferEntry {
  data: ArrayBuffer;
  dataByteLength: number;
  sourceKind: HybridRemoteThumbnailSourceKind;
}

interface HybridCompressedRemoteThumbnailBufferHit {
  data: ArrayBuffer;
  sourceKind: HybridRemoteThumbnailSourceKind;
}

export interface HybridRemoteThumbnailStatsSnapshot {
  remoteFileHitCount: number;
  remotePendingHitCount: number;
  remoteNetworkFetchCount: number;
  remotePersistedCount: number;
  remotePersistSkipCount: number;
  remoteAstcDecodeCount: number;
  remoteAstcFallbackCount: number;
  deferredWriteDropCount: number;
  highWaterWaitCount: number;
  highWaterResumeCount: number;
  highWaterWaitTotalMs: number;
  highWaterLastWaitMs: number;
  highWaterMaxWaitMs: number;
  deferredWriteQueueSize: number;
  deferredWriteQueueBytes: number;
  compressedBufferCacheEntryCount: number;
  compressedBufferCacheBytes: number;
}

interface HybridBackgroundPredownloadWaiter {
  resolve: () => void;
  priorityHint: HybridRemotePredownloadPriorityHint;
}

class HybridCompressedRemoteThumbnailBufferCache {
  private static entries: Map<string, HybridCompressedRemoteThumbnailBufferEntry> = new Map();
  private static totalBytes: number = 0;

  private static touch(
    key: string,
    entry: HybridCompressedRemoteThumbnailBufferEntry,
  ): HybridCompressedRemoteThumbnailBufferEntry {
    HybridCompressedRemoteThumbnailBufferCache.entries.delete(key);
    HybridCompressedRemoteThumbnailBufferCache.entries.set(key, entry);
    return entry;
  }

  private static dropEntry(key: string, entry: HybridCompressedRemoteThumbnailBufferEntry): void {
    HybridCompressedRemoteThumbnailBufferCache.entries.delete(key);
    HybridCompressedRemoteThumbnailBufferCache.totalBytes = Math.max(
      0,
      HybridCompressedRemoteThumbnailBufferCache.totalBytes - entry.dataByteLength,
    );
  }

  private static resolveEntry(
    url: string,
    requestSize: number,
  ): HybridCompressedRemoteThumbnailBufferEntry | undefined {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const key = buildRemoteThumbnailCacheKey(url, candidateSize);
      const entry = HybridCompressedRemoteThumbnailBufferCache.entries.get(key);
      if (!entry) {
        continue;
      }
      if (entry.data.byteLength <= 0) {
        HybridCompressedRemoteThumbnailBufferCache.dropEntry(key, entry);
        continue;
      }
      return HybridCompressedRemoteThumbnailBufferCache.touch(key, entry);
    }
    return undefined;
  }

  private static resolveExactEntry(
    url: string,
    requestSize: number,
  ): HybridCompressedRemoteThumbnailBufferEntry | undefined {
    const key = buildRemoteThumbnailCacheKey(url, requestSize);
    const entry = HybridCompressedRemoteThumbnailBufferCache.entries.get(key);
    if (!entry) {
      return undefined;
    }
    if (entry.data.byteLength <= 0) {
      HybridCompressedRemoteThumbnailBufferCache.dropEntry(key, entry);
      return undefined;
    }
    return HybridCompressedRemoteThumbnailBufferCache.touch(key, entry);
  }

  private static trimOverflow(): void {
    while (HybridCompressedRemoteThumbnailBufferCache.totalBytes > HYBRID_COMPRESSED_BUFFER_CACHE_MAX_BYTES) {
      const oldestKey = HybridCompressedRemoteThumbnailBufferCache.entries.keys().next().value as string | undefined;
      if (!oldestKey) {
        return;
      }
      const oldestEntry = HybridCompressedRemoteThumbnailBufferCache.entries.get(oldestKey);
      if (!oldestEntry) {
        HybridCompressedRemoteThumbnailBufferCache.entries.delete(oldestKey);
        continue;
      }
      HybridCompressedRemoteThumbnailBufferCache.dropEntry(oldestKey, oldestEntry);
    }
  }

  private static trimToTarget(targetBytes: number): void {
    const safeTargetBytes = Math.max(0, targetBytes);
    while (HybridCompressedRemoteThumbnailBufferCache.totalBytes > safeTargetBytes) {
      const oldestKey = HybridCompressedRemoteThumbnailBufferCache.entries.keys().next().value as string | undefined;
      if (!oldestKey) {
        return;
      }
      const oldestEntry = HybridCompressedRemoteThumbnailBufferCache.entries.get(oldestKey);
      if (!oldestEntry) {
        HybridCompressedRemoteThumbnailBufferCache.entries.delete(oldestKey);
        continue;
      }
      HybridCompressedRemoteThumbnailBufferCache.dropEntry(oldestKey, oldestEntry);
    }
  }

  static store(
    url: string,
    requestSize: number,
    data: ArrayBuffer,
    sourceKind: HybridRemoteThumbnailSourceKind,
  ): void {
    if (data.byteLength <= 0) {
      return;
    }

    const key = buildRemoteThumbnailCacheKey(url, requestSize);
    const previous = HybridCompressedRemoteThumbnailBufferCache.entries.get(key);
    if (previous) {
      HybridCompressedRemoteThumbnailBufferCache.totalBytes = Math.max(
        0,
        HybridCompressedRemoteThumbnailBufferCache.totalBytes - previous.dataByteLength,
      );
      HybridCompressedRemoteThumbnailBufferCache.entries.delete(key);
    }

    const storedData = cloneRemoteThumbnailBuffer(data);
    HybridCompressedRemoteThumbnailBufferCache.entries.set(key, {
      data: storedData,
      dataByteLength: storedData.byteLength,
      sourceKind: sourceKind,
    });
    HybridCompressedRemoteThumbnailBufferCache.totalBytes += storedData.byteLength;
    HybridCompressedRemoteThumbnailBufferCache.trimOverflow();
  }

  static get(
    url: string,
    requestSize: number,
  ): HybridCompressedRemoteThumbnailBufferHit | undefined {
    const entry = HybridCompressedRemoteThumbnailBufferCache.resolveEntry(url, requestSize);
    if (!entry) {
      return undefined;
    }
    return {
      data: cloneRemoteThumbnailBuffer(entry.data),
      sourceKind: entry.sourceKind,
    };
  }

  static has(url: string, requestSize: number): boolean {
    return HybridCompressedRemoteThumbnailBufferCache.resolveEntry(url, requestSize) !== undefined;
  }

  static hasExact(url: string, requestSize: number): boolean {
    return HybridCompressedRemoteThumbnailBufferCache.resolveExactEntry(url, requestSize) !== undefined;
  }

  static copyForPersist(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const entry = HybridCompressedRemoteThumbnailBufferCache.resolveEntry(url, requestSize);
    if (!entry) {
      return undefined;
    }
    return cloneRemoteThumbnailBuffer(entry.data);
  }

  static copyExactForPersist(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const entry = HybridCompressedRemoteThumbnailBufferCache.resolveExactEntry(url, requestSize);
    if (!entry) {
      return undefined;
    }
    return cloneRemoteThumbnailBuffer(entry.data);
  }

  static promoteToPersisted(url: string, requestSize: number): void {
    const entry = HybridCompressedRemoteThumbnailBufferCache.resolveEntry(url, requestSize);
    if (!entry) {
      return;
    }
    entry.sourceKind = HybridRemoteThumbnailSourceKind.PERSISTED_FILE;
  }

  static describeLookup(url: string, requestSize: number): string {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    const invalidSizes: Array<number> = [];
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const key = buildRemoteThumbnailCacheKey(url, candidateSize);
      const entry = HybridCompressedRemoteThumbnailBufferCache.entries.get(key);
      if (!entry) {
        continue;
      }
      if (entry.data.byteLength <= 0) {
        invalidSizes.push(candidateSize);
        continue;
      }
      return `hit-unexpected matchedSize=${candidateSize} bytes=${entry.dataByteLength} sourceKind=${describeRemoteThumbnailSourceKind(entry.sourceKind)}`;
    }
    return `miss family=[${formatRemoteThumbnailRequestSizeFamily(requestSize)}] ` +
      `invalidSizes=[${invalidSizes.join(',')}] cacheEntries=${HybridCompressedRemoteThumbnailBufferCache.entries.size} ` +
      `cacheBytes=${HybridCompressedRemoteThumbnailBufferCache.totalBytes}`;
  }

  static entryCount(): number {
    return HybridCompressedRemoteThumbnailBufferCache.entries.size;
  }

  static bytes(): number {
    return HybridCompressedRemoteThumbnailBufferCache.totalBytes;
  }

  static trimIfNeeded(targetBytes: number = HYBRID_COMPRESSED_BUFFER_CACHE_IDLE_TARGET_BYTES): void {
    if (HybridCompressedRemoteThumbnailBufferCache.totalBytes <= targetBytes) {
      return;
    }
    HybridCompressedRemoteThumbnailBufferCache.trimToTarget(targetBytes);
  }
}

class HybridRemoteThumbnailStats {
  private static remoteFileHitCount: number = 0;
  private static remotePendingHitCount: number = 0;
  private static remoteNetworkFetchCount: number = 0;
  private static remotePersistedCount: number = 0;
  private static remotePersistSkipCount: number = 0;
  private static remoteAstcDecodeCount: number = 0;
  private static remoteAstcFallbackCount: number = 0;
  private static deferredWriteDropCount: number = 0;
  private static highWaterWaitCount: number = 0;
  private static highWaterResumeCount: number = 0;
  private static highWaterWaitTotalMs: number = 0;
  private static highWaterLastWaitMs: number = 0;
  private static highWaterMaxWaitMs: number = 0;

  static noteSourceKind(sourceKind: HybridRemoteThumbnailSourceKind): void {
    if (sourceKind === HybridRemoteThumbnailSourceKind.PERSISTED_FILE) {
      HybridRemoteThumbnailStats.remoteFileHitCount += 1;
      return;
    }
    if (sourceKind === HybridRemoteThumbnailSourceKind.PENDING_WRITE) {
      HybridRemoteThumbnailStats.remotePendingHitCount += 1;
    }
  }

  static noteNetworkFetch(): void {
    HybridRemoteThumbnailStats.remoteNetworkFetchCount += 1;
  }

  static notePersisted(): void {
    HybridRemoteThumbnailStats.remotePersistedCount += 1;
  }

  static notePersistSkip(): void {
    HybridRemoteThumbnailStats.remotePersistSkipCount += 1;
  }

  static noteAstcDecodeUsed(): void {
    HybridRemoteThumbnailStats.remoteAstcDecodeCount += 1;
  }

  static noteAstcDecodeFallback(): void {
    HybridRemoteThumbnailStats.remoteAstcFallbackCount += 1;
  }

  static noteDeferredWriteDrop(): void {
    HybridRemoteThumbnailStats.deferredWriteDropCount += 1;
  }

  static noteHighWaterWaitStart(): HybridRemoteThumbnailStatsSnapshot {
    HybridRemoteThumbnailStats.highWaterWaitCount += 1;
    return HybridRemoteThumbnailStats.snapshot();
  }

  static noteHighWaterResume(waitDurationMs: number): HybridRemoteThumbnailStatsSnapshot {
    const clampedWaitDurationMs = Math.max(0, waitDurationMs);
    HybridRemoteThumbnailStats.highWaterResumeCount += 1;
    HybridRemoteThumbnailStats.highWaterWaitTotalMs += clampedWaitDurationMs;
    HybridRemoteThumbnailStats.highWaterLastWaitMs = clampedWaitDurationMs;
    HybridRemoteThumbnailStats.highWaterMaxWaitMs = Math.max(
      HybridRemoteThumbnailStats.highWaterMaxWaitMs,
      clampedWaitDurationMs,
    );
    return HybridRemoteThumbnailStats.snapshot();
  }

  static snapshot(): HybridRemoteThumbnailStatsSnapshot {
    return {
      remoteFileHitCount: HybridRemoteThumbnailStats.remoteFileHitCount,
      remotePendingHitCount: HybridRemoteThumbnailStats.remotePendingHitCount,
      remoteNetworkFetchCount: HybridRemoteThumbnailStats.remoteNetworkFetchCount,
      remotePersistedCount: HybridRemoteThumbnailStats.remotePersistedCount,
      remotePersistSkipCount: HybridRemoteThumbnailStats.remotePersistSkipCount,
      remoteAstcDecodeCount: HybridRemoteThumbnailStats.remoteAstcDecodeCount,
      remoteAstcFallbackCount: HybridRemoteThumbnailStats.remoteAstcFallbackCount,
      deferredWriteDropCount: HybridRemoteThumbnailStats.deferredWriteDropCount,
      highWaterWaitCount: HybridRemoteThumbnailStats.highWaterWaitCount,
      highWaterResumeCount: HybridRemoteThumbnailStats.highWaterResumeCount,
      highWaterWaitTotalMs: HybridRemoteThumbnailStats.highWaterWaitTotalMs,
      highWaterLastWaitMs: HybridRemoteThumbnailStats.highWaterLastWaitMs,
      highWaterMaxWaitMs: HybridRemoteThumbnailStats.highWaterMaxWaitMs,
      deferredWriteQueueSize: HybridDeferredRemoteThumbnailWriter.size(),
      deferredWriteQueueBytes: HybridDeferredRemoteThumbnailWriter.bytes(),
      compressedBufferCacheEntryCount: HybridCompressedRemoteThumbnailBufferCache.entryCount(),
      compressedBufferCacheBytes: HybridCompressedRemoteThumbnailBufferCache.bytes(),
    };
  }
}

let visibleRemoteThumbnailDiskTimingLogged: boolean = false;

function resolveRemoteThumbnailTaskPriority(loadKind: HybridRemoteThumbnailLoadKind): taskpool.Priority {
  if (loadKind === HybridRemoteThumbnailLoadKind.VISIBLE) {
    return taskpool.Priority.MEDIUM;
  }
  if (HybridScrollState.isScrolling) {
    return taskpool.Priority.MEDIUM;
  }
  return taskpool.Priority.LOW;
}

function shouldPersistRemoteThumbnailImmediately(): boolean {
  return true;
}

async function waitForDeferredWriteCapacity(): Promise<void> {
  let waitLoopCount: number = 0;
  let waitStartedAt: number = 0;
  let initialQueueSize: number = 0;
  let initialQueueBytes: number = 0;
  while (HybridDeferredRemoteThumbnailWriter.isHighWater()) {
    if (waitLoopCount === 0) {
      waitStartedAt = Date.now();
      initialQueueSize = HybridDeferredRemoteThumbnailWriter.size();
      initialQueueBytes = HybridDeferredRemoteThumbnailWriter.bytes();
      const waitStartStats = HybridRemoteThumbnailStats.noteHighWaterWaitStart();
      console.info(
        `[HybridPhotoThumbnailDisk] background high-water wait: ` +
          `queueSize=${initialQueueSize} queueBytes=${initialQueueBytes} ` +
          `highWaterWaitCount=${waitStartStats.highWaterWaitCount} ` +
          `highWaterResumeCount=${waitStartStats.highWaterResumeCount} ` +
          `highWaterWaitTotalMs=${waitStartStats.highWaterWaitTotalMs}`,
      );
    }
    waitLoopCount += 1;
    HybridDeferredRemoteThumbnailWriter.flushIfIdle();
    await delay(HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 2);
  }

  if (waitLoopCount > 0) {
    const waitDurationMs = Math.max(0, Date.now() - waitStartedAt);
    const resumeStats = HybridRemoteThumbnailStats.noteHighWaterResume(waitDurationMs);
    console.info(
      `[HybridPhotoThumbnailDisk] background high-water resume: ` +
        `waitMs=${waitDurationMs} waitLoops=${waitLoopCount} ` +
        `startQueueSize=${initialQueueSize} startQueueBytes=${initialQueueBytes} ` +
        `queueSize=${HybridDeferredRemoteThumbnailWriter.size()} ` +
        `queueBytes=${HybridDeferredRemoteThumbnailWriter.bytes()} ` +
        `highWaterWaitCount=${resumeStats.highWaterWaitCount} ` +
        `highWaterResumeCount=${resumeStats.highWaterResumeCount} ` +
        `highWaterWaitTotalMs=${resumeStats.highWaterWaitTotalMs} ` +
        `highWaterLastWaitMs=${resumeStats.highWaterLastWaitMs} ` +
        `highWaterMaxWaitMs=${resumeStats.highWaterMaxWaitMs}`,
    );
  }
}

function resolveBackgroundPredownloadConcurrencyLimit(
  priorityHint: HybridRemotePredownloadPriorityHint,
): number {
  if (priorityHint === HybridRemotePredownloadPriorityHint.NEARBY) {
    return HYBRID_MAX_CONCURRENT_NEARBY_REMOTE_PREDOWNLOADS;
  }
  if (priorityHint === HybridRemotePredownloadPriorityHint.INITIAL) {
    return HYBRID_MAX_CONCURRENT_INITIAL_REMOTE_PREDOWNLOADS;
  }
  return HYBRID_MAX_CONCURRENT_BACKGROUND_PREDOWNLOADS;
}

function shouldPreferAstcRemoteThumbnail(requestSize: number): boolean {
  return HYBRID_ENABLE_ASTC_REMOTE_THUMBNAILS &&
    requestSize > 0 &&
    requestSize <= HYBRID_ASTC_REMOTE_THUMBNAIL_MAX_REQUEST_SIZE;
}

@Concurrent
async function readRemoteThumbnailBufferTask(filePath: string): Promise<ArrayBuffer> {
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

    return bytesRead === stat.size ? buffer : buffer.slice(0, bytesRead);
  } finally {
    try {
      fs.closeSync(file);
    } catch (_) {}
  }
}

async function readRemoteThumbnailBufferFromFile(
  filePath: string,
  loadKind: HybridRemoteThumbnailLoadKind,
): Promise<ArrayBuffer> {
  const priority = resolveRemoteThumbnailTaskPriority(loadKind);
  const task: taskpool.Task = new taskpool.Task(readRemoteThumbnailBufferTask, filePath);
  const result = await taskpool.execute(task, priority) as ArrayBuffer | undefined;
  if (!result) {
    throw new Error(`failed to load cached thumbnail buffer: ${filePath}`);
  }
  return cloneRemoteThumbnailBuffer(result);
}

function logVisibleRemoteThumbnailDiskTimingOnce(
  filePath: string,
  requestSize: number,
  bufferByteLength: number,
  readStartedAt: number,
  decodeStartedAt: number,
  finishedAt: number,
): void {
  if (visibleRemoteThumbnailDiskTimingLogged) {
    return;
  }

  visibleRemoteThumbnailDiskTimingLogged = true;
  console.info(
    `[HybridPhotoThumbnailDisk] visible cached thumbnail timing requestSize=${requestSize} bytes=${bufferByteLength} readMs=${decodeStartedAt - readStartedAt} decodeMs=${finishedAt - decodeStartedAt} totalMs=${finishedAt - readStartedAt} path=${filePath}`,
  );
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
  allowSyncFs: boolean = true,
): string | undefined {
  const candidatePath = remoteThumbnailCachePath(ctx, url, requestSize);
  if (HybridRemoteThumbnailCacheIndex.hasCachePath(ctx, candidatePath, allowSyncFs)) {
    return candidatePath;
  }
  return undefined;
}

function findExactRemoteThumbnailCachePath(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): string | undefined {
  const candidatePath = remoteThumbnailCachePath(ctx, url, requestSize);
  if (!HybridRemoteThumbnailCacheIndex.hasCachePath(ctx, candidatePath, allowSyncFs)) {
    return undefined;
  }
  return candidatePath;
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
      const totalBytes = trackRemoteThumbnailCacheDir(ensureRemoteThumbnailCacheDir(ctx), files, now);

      HybridRemoteThumbnailCacheIndex.files = files;
      HybridRemoteThumbnailCacheIndex.totalBytes = totalBytes;
      HybridRemoteThumbnailCacheIndex.initialized = true;
    } catch (_) {
      // best-effort initialization
    } finally {
      HybridRemoteThumbnailCacheIndex.initializing = false;
    }
  }

  static hasCachePath(_ctx: common.UIAbilityContext, path: string, allowSyncFs: boolean = true): boolean {
    const existing = HybridRemoteThumbnailCacheIndex.files.get(path);
    if (existing) {
      existing.lastAccessAt = Date.now();
      return true;
    }

    if (HybridRemoteThumbnailCacheIndex.initialized || !allowSyncFs || HybridScrollState.isScrolling) {
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

  static describeLookup(
    ctx: common.UIAbilityContext,
    url: string,
    requestSize: number,
    allowSyncFs: boolean = true,
  ): string {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    const matchedSizes: Array<number> = [];
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const candidatePath = remoteThumbnailCachePath(ctx, url, candidateSize);
      if (HybridRemoteThumbnailCacheIndex.files.get(candidatePath)) {
        matchedSizes.push(candidateSize);
      }
    }
    if (matchedSizes.length > 0) {
      return `hit-unexpected matchedSizes=[${matchedSizes.join(',')}]`;
    }
    return `miss family=[${formatRemoteThumbnailRequestSizeFamily(requestSize)}] ` +
      `indexInitialized=${HybridRemoteThumbnailCacheIndex.initialized ? 1 : 0} ` +
      `indexInitializing=${HybridRemoteThumbnailCacheIndex.initializing ? 1 : 0} ` +
      `allowSyncFs=${allowSyncFs ? 1 : 0} scrolling=${HybridScrollState.isScrolling ? 1 : 0}`;
  }
}

export function primeRemoteThumbnailCacheIndex(ctx: common.UIAbilityContext): void {
  HybridRemoteThumbnailCacheIndex.ensureInitialized(ctx);
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
      const initialTotalBytes = totalBytes;
      let removedCount = 0;
      let removedBytes = 0;
      let firstRemovedPath = '';
      let lastRemovedPath = '';
      console.info(
        `[HybridPhotoThumbnailDisk] cache trim start: force=${force ? 1 : 0} ` +
          `initialBytes=${initialTotalBytes} fileCount=${files.length} ` +
          `maxBytes=${HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES} ` +
          `targetBytes=${HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES}`,
      );
      for (let index = 0; index < files.length && totalBytes > HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES; index += 1) {
        const file = files[index];
        if (removedCount <= 0) {
          firstRemovedPath = file.path;
        }
        lastRemovedPath = file.path;
        deleteFileIfExists(file.path);
        HybridRemoteThumbnailCacheIndex.noteRemoved(file.path);
        totalBytes -= file.size;
        removedBytes += file.size;
        removedCount += 1;
      }
      if (removedCount > 0) {
        console.info(
          `[HybridPhotoThumbnailDisk] cache trim complete: force=${force ? 1 : 0} ` +
            `initialBytes=${initialTotalBytes} removedBytes=${removedBytes} removedCount=${removedCount} ` +
            `finalBytes=${totalBytes} maxBytes=${HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES} ` +
            `targetBytes=${HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES} ` +
            `firstRemovedPath=${firstRemovedPath} lastRemovedPath=${lastRemovedPath}`,
        );
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
    HybridCompressedRemoteThumbnailBufferCache.promoteToPersisted(url, requestSize);
    HybridRemoteThumbnailStats.notePersistSkip();
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
    HybridCompressedRemoteThumbnailBufferCache.store(
      url,
      requestSize,
      data,
      HybridRemoteThumbnailSourceKind.PERSISTED_FILE,
    );
    HybridRemoteThumbnailCacheIndex.notePersisted(cachePath, data.byteLength);
    HybridRemoteThumbnailStats.notePersisted();
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

  private static dropEntry(key: string, entry: HybridDeferredRemoteWriteEntry): void {
    HybridDeferredRemoteThumbnailWriter.entries.delete(key);
    HybridDeferredRemoteThumbnailWriter.totalBytes = Math.max(
      0,
      HybridDeferredRemoteThumbnailWriter.totalBytes - entry.dataByteLength,
    );
  }

  private static isEntryDataUsable(entry: HybridDeferredRemoteWriteEntry): boolean {
    return entry.data.byteLength > 0;
  }

  private static resolveExactEntry(
    url: string,
    requestSize: number,
  ): HybridDeferredRemoteWriteEntry | undefined {
    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    if (!entry) {
      return undefined;
    }
    if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
      HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
      HybridRemoteThumbnailStats.noteDeferredWriteDrop();
      return undefined;
    }
    HybridDeferredRemoteThumbnailWriter.touchKey(key);
    return entry;
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
      if (!oldestEntry) {
        HybridDeferredRemoteThumbnailWriter.entries.delete(oldestKey);
        continue;
      }
      HybridDeferredRemoteThumbnailWriter.dropEntry(oldestKey, oldestEntry);
      HybridRemoteThumbnailStats.noteDeferredWriteDrop();
    }
  }

  static size(): number {
    return HybridDeferredRemoteThumbnailWriter.entries.size;
  }

  static bytes(): number {
    return HybridDeferredRemoteThumbnailWriter.totalBytes;
  }

  static isHighWater(): boolean {
    return (HybridDeferredRemoteThumbnailWriter.entries.size * 100) >=
      (HYBRID_DEFERRED_REMOTE_WRITE_LIMIT * HYBRID_DEFERRED_REMOTE_WRITE_HIGH_WATER_PERCENT) ||
      (HybridDeferredRemoteThumbnailWriter.totalBytes * 100) >=
      (HYBRID_DEFERRED_REMOTE_WRITE_MAX_BYTES * HYBRID_DEFERRED_REMOTE_WRITE_HIGH_WATER_PERCENT);
  }

  static hasPending(
    url: string,
    requestSize: number,
  ): boolean {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, candidateSize);
      const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
      if (!entry) {
        continue;
      }
      if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
        HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
        HybridRemoteThumbnailStats.noteDeferredWriteDrop();
        continue;
      }
      HybridDeferredRemoteThumbnailWriter.touchKey(key);
      return true;
    }
    return false;
  }

  static hasPendingExact(
    url: string,
    requestSize: number,
  ): boolean {
    return HybridDeferredRemoteThumbnailWriter.resolveExactEntry(url, requestSize) !== undefined;
  }

  static peekData(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, candidateSize);
      const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
      if (!entry) {
        continue;
      }
      if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
        HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
        HybridRemoteThumbnailStats.noteDeferredWriteDrop();
        continue;
      }

      HybridDeferredRemoteThumbnailWriter.touchKey(key);
      return entry.data;
    }
    return undefined;
  }

  static peekExactData(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const entry = HybridDeferredRemoteThumbnailWriter.resolveExactEntry(url, requestSize);
    if (!entry) {
      return undefined;
    }
    return entry.data;
  }

  static takeData(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, candidateSize);
      const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
      if (!entry) {
        continue;
      }
      if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
        HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
        HybridRemoteThumbnailStats.noteDeferredWriteDrop();
        continue;
      }

      HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
      return entry.data;
    }
    return undefined;
  }

  static takeExactData(
    url: string,
    requestSize: number,
  ): ArrayBuffer | undefined {
    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    if (!entry) {
      return undefined;
    }
    if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
      HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
      HybridRemoteThumbnailStats.noteDeferredWriteDrop();
      return undefined;
    }

    HybridDeferredRemoteThumbnailWriter.dropEntry(key, entry);
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
      HybridRemoteThumbnailStats.notePersistSkip();
      return;
    }

    const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, requestSize);
    const previous = HybridDeferredRemoteThumbnailWriter.entries.get(key);
    HybridDeferredRemoteThumbnailWriter.lastCtx = ctx;
    if (previous) {
      HybridDeferredRemoteThumbnailWriter.totalBytes = Math.max(
        0,
        HybridDeferredRemoteThumbnailWriter.totalBytes - previous.dataByteLength,
      );
      HybridDeferredRemoteThumbnailWriter.entries.delete(key);
    }
    HybridDeferredRemoteThumbnailWriter.entries.set(key, {
      ctx: ctx,
      url: url,
      requestSize: requestSize,
      data: data,
      dataByteLength: data.byteLength,
    });
    HybridDeferredRemoteThumbnailWriter.totalBytes += data.byteLength;
    HybridDeferredRemoteThumbnailWriter.trimOverflow();
  }

  static describeLookup(url: string, requestSize: number): string {
    const requestSizes: Array<number> = [requestSize].concat(resolveAlternateRemoteThumbnailRequestSizes(requestSize));
    const invalidSizes: Array<number> = [];
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateSize = requestSizes[index];
      const key = HybridDeferredRemoteThumbnailWriter.buildKey(url, candidateSize);
      const entry = HybridDeferredRemoteThumbnailWriter.entries.get(key);
      if (!entry) {
        continue;
      }
      if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
        invalidSizes.push(candidateSize);
        continue;
      }
      return `hit-unexpected matchedSize=${candidateSize} bytes=${entry.dataByteLength}`;
    }
    return `miss family=[${formatRemoteThumbnailRequestSizeFamily(requestSize)}] ` +
      `invalidSizes=[${invalidSizes.join(',')}] queueSize=${HybridDeferredRemoteThumbnailWriter.entries.size} ` +
      `queueBytes=${HybridDeferredRemoteThumbnailWriter.totalBytes}`;
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
      if (!entry) {
        HybridDeferredRemoteThumbnailWriter.entries.delete(oldestKey);
        continue;
      }
      HybridDeferredRemoteThumbnailWriter.dropEntry(oldestKey, entry);
      if (!HybridDeferredRemoteThumbnailWriter.isEntryDataUsable(entry)) {
        HybridRemoteThumbnailStats.noteDeferredWriteDrop();
        await delay(HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
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
  url: string,
  filePath: string,
  requestSize: number,
  loadKind: HybridRemoteThumbnailLoadKind,
): Promise<PixelMap> {
  HybridRemoteThumbnailCacheIndex.markAccessed(filePath);
  const readStartedAt = Date.now();
  const buffer = await readRemoteThumbnailBufferFromFile(filePath, loadKind);
  const decodeBuffer = cloneRemoteThumbnailBuffer(buffer);
  const decodeStartedAt = Date.now();
  const pixelMap = await decodeRemoteThumbnailFromBuffer(decodeBuffer, requestSize, loadKind);
  HybridCompressedRemoteThumbnailBufferCache.store(
    url,
    requestSize,
    buffer,
    HybridRemoteThumbnailSourceKind.PERSISTED_FILE,
  );
  if (loadKind === HybridRemoteThumbnailLoadKind.VISIBLE) {
    logVisibleRemoteThumbnailDiskTimingOnce(
      filePath,
      requestSize,
      buffer.byteLength,
      readStartedAt,
      decodeStartedAt,
      Date.now(),
    );
  }
  return pixelMap;
}

@Concurrent
async function decodeRemoteThumbnailBufferTask(
  data: ArrayBuffer,
  requestSize: number,
  preferAstc: boolean,
): Promise<sendableImage.PixelMap> {
  const source = image.createImageSource(data);
  try {
    const imageInfo = await source.getImageInfo();
    const sourceWidth = Math.max(1, Math.round(imageInfo.size.width));
    const sourceHeight = Math.max(1, Math.round(imageInfo.size.height));
    const scale = Math.min(requestSize / sourceWidth, requestSize / sourceHeight);
    const desiredWidth = Math.max(1, Math.round(sourceWidth * scale));
    const desiredHeight = Math.max(1, Math.round(sourceHeight * scale));
    if (preferAstc) {
      try {
        const astcPixelMap = await source.createPixelMap({
          editable: false,
          desiredPixelFormat: image.PixelMapFormat.ASTC_4x4,
          desiredSize: {
            width: desiredWidth,
            height: desiredHeight,
          },
        });
        try {
          return sendableImage.convertFromPixelMap(astcPixelMap);
        } finally {
          try {
            astcPixelMap.release();
          } catch (_) {}
        }
      } catch (_) {}
    }

    const rgbaPixelMap = await source.createPixelMap({
      editable: false,
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      desiredSize: {
        width: desiredWidth,
        height: desiredHeight,
      },
    });
    try {
      return sendableImage.convertFromPixelMap(rgbaPixelMap);
    } finally {
      try {
        rgbaPixelMap.release();
      } catch (_) {}
    }
  } finally {
    try {
      source.release();
    } catch (_) {}
  }
}

async function decodeRemoteThumbnailFromBuffer(
  data: ArrayBuffer,
  requestSize: number,
  loadKind: HybridRemoteThumbnailLoadKind,
): Promise<PixelMap> {
  const priority = resolveRemoteThumbnailTaskPriority(loadKind);
  const preferAstc = shouldPreferAstcRemoteThumbnail(requestSize);
  const task: taskpool.Task = new taskpool.Task(
    decodeRemoteThumbnailBufferTask,
    data,
    requestSize,
    preferAstc,
  );
  const result = await taskpool.execute(task, priority) as sendableImage.PixelMap | undefined;
  if (!result) {
    throw new Error('failed to decode remote thumbnail buffer');
  }
  const pixelMap = sendableImage.convertToPixelMap(result);
  try {
    const imageInfo = pixelMap.getImageInfoSync();
    if (imageInfo.pixelFormat === image.PixelMapFormat.ASTC_4x4) {
      HybridRemoteThumbnailStats.noteAstcDecodeUsed();
    } else if (preferAstc) {
      HybridRemoteThumbnailStats.noteAstcDecodeFallback();
    }
  } catch (_) {
    if (preferAstc) {
      HybridRemoteThumbnailStats.noteAstcDecodeFallback();
    }
  }
  return pixelMap;
}

export function hasRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  if (HybridCompressedRemoteThumbnailBufferCache.has(url, requestSize)) {
    return true;
  }
  return findExistingRemoteThumbnailCachePath(ctx, url, requestSize, allowSyncFs) !== undefined ||
    HybridDeferredRemoteThumbnailWriter.hasPending(url, requestSize);
}

export function hasRemoteThumbnailCompressedData(
  url: string,
  requestSize: number,
): boolean {
  return HybridCompressedRemoteThumbnailBufferCache.has(url, requestSize) ||
    HybridDeferredRemoteThumbnailWriter.hasPending(url, requestSize);
}

export function hasExactRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  if (HybridCompressedRemoteThumbnailBufferCache.hasExact(url, requestSize)) {
    return true;
  }
  return findExactRemoteThumbnailCachePath(ctx, url, requestSize, allowSyncFs) !== undefined ||
    HybridDeferredRemoteThumbnailWriter.hasPendingExact(url, requestSize);
}

export function hasPersistedRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  return findExistingRemoteThumbnailCachePath(ctx, url, requestSize, allowSyncFs) !== undefined;
}

export function hasExactPersistedRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  return findExactRemoteThumbnailCachePath(ctx, url, requestSize, allowSyncFs) !== undefined;
}

export async function loadRemoteThumbnail(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  loadKind: HybridRemoteThumbnailLoadKind = HybridRemoteThumbnailLoadKind.VISIBLE,
): Promise<HybridRemoteThumbnailLoadResult> {
  let persistedFileMiss: string = '';
  const compressedBufferHit = HybridCompressedRemoteThumbnailBufferCache.get(url, requestSize);
  if (compressedBufferHit) {
    HybridRemoteThumbnailStats.noteSourceKind(compressedBufferHit.sourceKind);
    return {
      pixelMap: await decodeRemoteThumbnailFromBuffer(
        compressedBufferHit.data,
        requestSize,
        loadKind,
      ),
      sourceKind: compressedBufferHit.sourceKind,
      loadPath: HybridRemoteThumbnailLoadPath.COMPRESSED_BUFFER,
    };
  }

  const pendingData = HybridDeferredRemoteThumbnailWriter.peekData(url, requestSize);
  if (pendingData) {
    HybridCompressedRemoteThumbnailBufferCache.store(
      url,
      requestSize,
      pendingData,
      HybridRemoteThumbnailSourceKind.PENDING_WRITE,
    );
    HybridRemoteThumbnailStats.noteSourceKind(HybridRemoteThumbnailSourceKind.PENDING_WRITE);
    return {
      pixelMap: await decodeRemoteThumbnailFromBuffer(
        cloneRemoteThumbnailBuffer(pendingData),
        requestSize,
        loadKind,
      ),
      sourceKind: HybridRemoteThumbnailSourceKind.PENDING_WRITE,
      loadPath: HybridRemoteThumbnailLoadPath.DEFERRED_WRITE,
    };
  }

  const cachePath = findExistingRemoteThumbnailCachePath(ctx, url, requestSize);
  if (cachePath) {
    try {
      const pixelMap = await decodeRemoteThumbnailFromFile(url, cachePath, requestSize, loadKind);
      HybridRemoteThumbnailStats.noteSourceKind(HybridRemoteThumbnailSourceKind.PERSISTED_FILE);
      return {
        pixelMap: pixelMap,
        sourceKind: HybridRemoteThumbnailSourceKind.PERSISTED_FILE,
        loadPath: HybridRemoteThumbnailLoadPath.PERSISTED_FILE,
      };
    } catch (error) {
      const resolvedError = error as Error;
      persistedFileMiss = `decode-failed path=${cachePath} error=${resolvedError.message}`;
      console.warn(
        `[HybridPhotoThumbnailDisk] persisted file fallback miss: ` +
          `loadKind=${describeRemoteThumbnailLoadKind(loadKind)} requestSize=${requestSize} ` +
          `urlHash=${hashString(url)} path=${cachePath} error=${resolvedError.message}`,
      );
      deleteFileIfExists(cachePath);
      HybridRemoteThumbnailCacheIndex.noteRemoved(cachePath);
    }
  }

  if (persistedFileMiss.length <= 0) {
    persistedFileMiss = HybridRemoteThumbnailCacheIndex.describeLookup(ctx, url, requestSize);
  }
  console.warn(
    `[HybridPhotoThumbnailDisk] remote network fallback: ` +
      `loadKind=${describeRemoteThumbnailLoadKind(loadKind)} requestSize=${requestSize} ` +
      `urlHash=${hashString(url)} compressedBuffer=${HybridCompressedRemoteThumbnailBufferCache.describeLookup(url, requestSize)} ` +
      `pendingWrite=${HybridDeferredRemoteThumbnailWriter.describeLookup(url, requestSize)} ` +
      `persistedFile=${persistedFileMiss}`,
  );

  const request = http.createHttp();
  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    maxLimit: 8 * 1024 * 1024,
  };
  URLSessionManager.applyToOptions(ctx.getApplicationContext(), options, url);

  try {
    HybridRemoteThumbnailStats.noteNetworkFetch();
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

    HybridCompressedRemoteThumbnailBufferCache.store(
      url,
      requestSize,
      data,
      HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES
        ? HybridRemoteThumbnailSourceKind.PENDING_WRITE
        : HybridRemoteThumbnailSourceKind.NETWORK_MISS,
    );

    if (HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      HybridDeferredRemoteThumbnailWriter.enqueue(ctx, url, requestSize, cloneRemoteThumbnailBuffer(data));
    }

    return {
      pixelMap: await decodeRemoteThumbnailFromBuffer(data, requestSize, loadKind),
      sourceKind: HybridRemoteThumbnailSourceKind.NETWORK_MISS,
      loadPath: HybridRemoteThumbnailLoadPath.NETWORK,
    };
  } finally {
    request.destroy();
  }
}

export async function preloadPersistedRemoteThumbnailBuffer(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): Promise<boolean> {
  if (hasRemoteThumbnailCompressedData(url, requestSize)) {
    return false;
  }

  const cachePath = findExistingRemoteThumbnailCachePath(ctx, url, requestSize, false);
  if (!cachePath) {
    return false;
  }

  try {
    HybridRemoteThumbnailCacheIndex.markAccessed(cachePath);
    const buffer = await readRemoteThumbnailBufferFromFile(cachePath, HybridRemoteThumbnailLoadKind.PREFETCH);
    HybridCompressedRemoteThumbnailBufferCache.store(
      url,
      requestSize,
      buffer,
      HybridRemoteThumbnailSourceKind.PERSISTED_FILE,
    );
    return true;
  } catch (error) {
    const resolvedError = error as Error;
    console.warn(
      `[HybridPhotoThumbnailDisk] persisted buffer preload failed: ` +
        `requestSize=${requestSize} urlHash=${hashString(url)} path=${cachePath} error=${resolvedError.message}`,
    );
    deleteFileIfExists(cachePath);
    HybridRemoteThumbnailCacheIndex.noteRemoved(cachePath);
    return false;
  }
}

export async function ensureRemoteThumbnailCached(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  exactRequestSize: boolean = false,
): Promise<string> {
  if (!HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
    return '';
  }

  const existingCachePath = exactRequestSize
    ? findExactRemoteThumbnailCachePath(ctx, url, requestSize)
    : findExistingRemoteThumbnailCachePath(ctx, url, requestSize);
  if (existingCachePath) {
    HybridRemoteThumbnailStats.noteSourceKind(HybridRemoteThumbnailSourceKind.PERSISTED_FILE);
    return existingCachePath;
  }

  const cachePath = remoteThumbnailCachePath(ctx, url, requestSize);
  const pendingData = exactRequestSize
    ? HybridDeferredRemoteThumbnailWriter.peekExactData(url, requestSize)
    : HybridDeferredRemoteThumbnailWriter.peekData(url, requestSize);
  if (pendingData) {
    HybridRemoteThumbnailStats.noteSourceKind(HybridRemoteThumbnailSourceKind.PENDING_WRITE);
    if (HybridScrollState.isScrolling || !shouldPersistRemoteThumbnailImmediately()) {
      return cachePath;
    }

    const persistData = exactRequestSize
      ? (HybridDeferredRemoteThumbnailWriter.takeExactData(url, requestSize) ?? pendingData)
      : (HybridDeferredRemoteThumbnailWriter.takeData(url, requestSize) ?? pendingData);
    return persistRemoteThumbnailBuffer(ctx, url, requestSize, persistData);
  }

  const compressedBufferData = exactRequestSize
    ? HybridCompressedRemoteThumbnailBufferCache.copyExactForPersist(url, requestSize)
    : HybridCompressedRemoteThumbnailBufferCache.copyForPersist(url, requestSize);
  if (compressedBufferData) {
    if (HybridScrollState.isScrolling || !shouldPersistRemoteThumbnailImmediately()) {
      HybridDeferredRemoteThumbnailWriter.enqueue(ctx, url, requestSize, compressedBufferData);
      return cachePath;
    }
    return persistRemoteThumbnailBuffer(ctx, url, requestSize, compressedBufferData);
  }

  const request = http.createHttp();
  const options: http.HttpRequestOptions = {
    method: http.RequestMethod.GET,
    expectDataType: http.HttpDataType.ARRAY_BUFFER,
    maxLimit: 8 * 1024 * 1024,
  };
  URLSessionManager.applyToOptions(ctx.getApplicationContext(), options, url);

  try {
    HybridRemoteThumbnailStats.noteNetworkFetch();
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
    if (HybridScrollState.isScrolling || !shouldPersistRemoteThumbnailImmediately()) {
      HybridCompressedRemoteThumbnailBufferCache.store(
        url,
        requestSize,
        data,
        HybridRemoteThumbnailSourceKind.PENDING_WRITE,
      );
      HybridDeferredRemoteThumbnailWriter.enqueue(ctx, url, requestSize, cloneRemoteThumbnailBuffer(data));
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
    priorityHint: HybridRemotePredownloadPriorityHint = HybridRemotePredownloadPriorityHint.NEARBY,
    exactRequestSize: boolean = false,
  ): Promise<void> {
    if (!HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return;
    }

    if (exactRequestSize
      ? hasExactRemoteThumbnailCache(ctx, url, requestSize)
      : hasRemoteThumbnailCache(ctx, url, requestSize)) {
      return;
    }

    await waitForDeferredWriteCapacity();

    if (exactRequestSize
      ? hasExactRemoteThumbnailCache(ctx, url, requestSize)
      : hasRemoteThumbnailCache(ctx, url, requestSize)) {
      return;
    }

    const key = `${requestSize}:${exactRequestSize ? 1 : 0}:${url}`;
    const existing = HybridRemoteThumbnailBackgroundPredownload.entries.get(key);
    if (existing?.downloadingPromise) {
      await existing.downloadingPromise;
      return;
    }

    const entry: HybridRemoteCacheEntry = existing ?? {};
    entry.downloadingPromise = HybridBackgroundPredownloadLimiter.run(
      () => ensureRemoteThumbnailCached(ctx, url, requestSize, exactRequestSize),
      priorityHint,
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
  private static waiters: Array<HybridBackgroundPredownloadWaiter> = [];

  static async run<T>(
    task: () => Promise<T>,
    priorityHint: HybridRemotePredownloadPriorityHint,
  ): Promise<T> {
    await HybridBackgroundPredownloadLimiter.acquire(priorityHint);
    try {
      return await task();
    } finally {
      HybridBackgroundPredownloadLimiter.release();
    }
  }

  private static async acquire(priorityHint: HybridRemotePredownloadPriorityHint): Promise<void> {
    if (HybridBackgroundPredownloadLimiter.tryAcquire(priorityHint)) {
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      HybridBackgroundPredownloadLimiter.waiters.push({
        resolve: resolve,
        priorityHint: priorityHint,
      });
    });
  }

  private static tryAcquire(priorityHint: HybridRemotePredownloadPriorityHint): boolean {
    if (HybridBackgroundPredownloadLimiter.activeCount >=
      resolveBackgroundPredownloadConcurrencyLimit(priorityHint)) {
      return false;
    }

    HybridBackgroundPredownloadLimiter.activeCount += 1;
    return true;
  }

  private static release(): void {
    if (HybridBackgroundPredownloadLimiter.activeCount > 0) {
      HybridBackgroundPredownloadLimiter.activeCount -= 1;
    }

    const priorityOrder: Array<HybridRemotePredownloadPriorityHint> = [
      HybridRemotePredownloadPriorityHint.NEARBY,
      HybridRemotePredownloadPriorityHint.INITIAL,
      HybridRemotePredownloadPriorityHint.BACKGROUND,
    ];
    for (let index = 0; index < priorityOrder.length; index += 1) {
      const priorityHint = priorityOrder[index];
      const waiterIndex = HybridBackgroundPredownloadLimiter.waiters.findIndex(
        (waiter: HybridBackgroundPredownloadWaiter): boolean => waiter.priorityHint === priorityHint,
      );
      if (waiterIndex < 0) {
        continue;
      }
      if (!HybridBackgroundPredownloadLimiter.tryAcquire(priorityHint)) {
        continue;
      }
      const waiter = HybridBackgroundPredownloadLimiter.waiters.splice(waiterIndex, 1)[0];
      waiter?.resolve();
      return;
    }
  }
}

export function flushDeferredThumbnailWritesIfIdle(): void {
  HybridDeferredRemoteThumbnailWriter.flushIfIdle();
}

export function getRemoteThumbnailStatsSnapshot(): HybridRemoteThumbnailStatsSnapshot {
  return HybridRemoteThumbnailStats.snapshot();
}

export function trimCompressedRemoteThumbnailBufferCache(
  targetBytes: number = HYBRID_COMPRESSED_BUFFER_CACHE_IDLE_TARGET_BYTES,
): void {
  HybridCompressedRemoteThumbnailBufferCache.trimIfNeeded(targetBytes);
}

export function shouldThrottleRemoteDiskPredownload(): boolean {
  return HybridDeferredRemoteThumbnailWriter.isHighWater();
}
