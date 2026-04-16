import { common } from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES,
  HYBRID_GRID_COLUMNS,
  HYBRID_MAX_CONCURRENT_THUMBNAIL_REQUESTS,
  HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES,
  HYBRID_REQUEST_SIZE,
  HYBRID_THUMBNAIL_RELEASE_DELAY_MS,
  HybridPhotoAsset,
  HybridPrefetchRuntimeMode,
  HybridRemoteCacheEntry,
  HybridThumbnailCacheEntry,
  resolveHybridPrefetchConcurrency,
  resolveAdaptiveCacheLimit,
  setHybridPrefetchRuntimeMode,
} from './HybridPhotoGridShared';
import * as Disk from './HybridPhotoThumbnailDisk';

function toError(error: Object | string | number | boolean | undefined | null): Error {
  if (error instanceof Error) {
    return error;
  }
  return new Error(`${error}`);
}

interface HybridLocalPhotoAssetCacheEntry {
  asset: photoAccessHelper.PhotoAsset;
  lastUsedAt: number;
}

interface ResolvedHybridLocalPhotoAsset {
  asset: photoAccessHelper.PhotoAsset;
  fromCache: boolean;
}

class HybridLocalPhotoAssetCache {
  private static readonly LIMIT: number = 256;
  private static entries: Map<string, HybridLocalPhotoAssetCacheEntry> = new Map();

  static acquire(assetId: string): photoAccessHelper.PhotoAsset | undefined {
    const entry = HybridLocalPhotoAssetCache.entries.get(assetId);
    if (!entry) {
      return undefined;
    }
    entry.lastUsedAt = Date.now();
    return entry.asset;
  }

  static store(assetId: string, asset: photoAccessHelper.PhotoAsset): void {
    HybridLocalPhotoAssetCache.entries.set(assetId, {
      asset: asset,
      lastUsedAt: Date.now(),
    });
    HybridLocalPhotoAssetCache.prune();
  }

  static invalidate(assetId: string): void {
    HybridLocalPhotoAssetCache.entries.delete(assetId);
  }

  private static prune(): void {
    if (HybridLocalPhotoAssetCache.entries.size <= HybridLocalPhotoAssetCache.LIMIT) {
      return;
    }

    const removableKeys: Array<string> = [];
    HybridLocalPhotoAssetCache.entries.forEach((_: HybridLocalPhotoAssetCacheEntry, key: string) => {
      removableKeys.push(key);
    });

    removableKeys.sort((leftKey: string, rightKey: string) => {
      const leftEntry = HybridLocalPhotoAssetCache.entries.get(leftKey);
      const rightEntry = HybridLocalPhotoAssetCache.entries.get(rightKey);
      const leftUsedAt = leftEntry?.lastUsedAt ?? 0;
      const rightUsedAt = rightEntry?.lastUsedAt ?? 0;
      return leftUsedAt - rightUsedAt;
    });

    while (
      HybridLocalPhotoAssetCache.entries.size > HybridLocalPhotoAssetCache.LIMIT &&
      removableKeys.length > 0
    ) {
      const key = removableKeys.shift();
      if (!key) {
        break;
      }
      HybridLocalPhotoAssetCache.entries.delete(key);
    }
  }
}

export class HybridThumbnailCache {
  private static entries: Map<string, HybridThumbnailCacheEntry> = new Map();
  private static activeColumns: number = HYBRID_GRID_COLUMNS;

  static setActiveColumns(columns: number): void {
    HybridThumbnailCache.activeColumns = columns;
  }

  static entryCount(): number {
    return HybridThumbnailCache.entries.size;
  }

  static hasReady(key: string): boolean {
    return !!HybridThumbnailCache.entries.get(key)?.pixelMap;
  }

  static acquire(key: string): PixelMap | undefined {
    const entry = HybridThumbnailCache.entries.get(key);
    if (!entry?.pixelMap) {
      return undefined;
    }

    entry.refCount += 1;
    entry.lastUsedAt = Date.now();
    return entry.pixelMap;
  }

  static async load(key: string, loader: () => Promise<PixelMap>): Promise<PixelMap> {
    let entry = HybridThumbnailCache.entries.get(key);
    const now = Date.now();
    if (!entry) {
      entry = {
        refCount: 0,
        lastUsedAt: now,
      };
      HybridThumbnailCache.entries.set(key, entry);
    }

    const existing = entry;
    if (existing?.pixelMap) {
      existing.refCount += 1;
      existing.lastUsedAt = now;
      return existing.pixelMap;
    }

    if (existing?.loadingPromise) {
      existing.refCount += 1;
      existing.lastUsedAt = now;
      const pixelMap = await existing.loadingPromise;
      const loaded = HybridThumbnailCache.entries.get(key);
      if (loaded) {
        loaded.lastUsedAt = Date.now();
      }
      return pixelMap;
    }

    existing.refCount += 1;
    existing.lastUsedAt = now;

    existing.loadingPromise = loader()
      .then((pixelMap: PixelMap) => {
        const loaded: HybridThumbnailCacheEntry = HybridThumbnailCache.entries.get(key) ?? {
          refCount: 0,
          lastUsedAt: Date.now(),
        };
        loaded.pixelMap = pixelMap;
        loaded.loadingPromise = undefined;
        loaded.lastUsedAt = Date.now();
        HybridThumbnailCache.entries.set(key, loaded);
        HybridThumbnailCache.prune();
        return pixelMap;
      })
      .catch((error: Error) => {
        const failed = HybridThumbnailCache.entries.get(key);
        if (failed) {
          failed.loadingPromise = undefined;
          if (!failed.pixelMap && failed.refCount <= 0) {
            HybridThumbnailCache.entries.delete(key);
          }
        }
        throw toError(error);
      });

    HybridThumbnailCache.entries.set(key, existing);

    try {
      return await existing.loadingPromise;
    } catch (error) {
      existing.refCount = Math.max(0, existing.refCount - 1);
      existing.lastUsedAt = Date.now();
      if (!existing.pixelMap && !existing.loadingPromise && existing.refCount <= 0) {
        HybridThumbnailCache.entries.delete(key);
      }
      throw toError(error);
    }
  }

  static prefetch(key: string, loader: () => Promise<PixelMap>): void {
    const existing = HybridThumbnailCache.entries.get(key);
    if (existing?.pixelMap || existing?.loadingPromise) {
      return;
    }

    const entry: HybridThumbnailCacheEntry = existing ?? {
      refCount: 0,
      lastUsedAt: Date.now(),
    };

    entry.loadingPromise = loader()
      .then((pixelMap: PixelMap) => {
        const loaded: HybridThumbnailCacheEntry = HybridThumbnailCache.entries.get(key) ?? {
          refCount: 0,
          lastUsedAt: Date.now(),
        };
        loaded.pixelMap = pixelMap;
        loaded.loadingPromise = undefined;
        loaded.lastUsedAt = Date.now();
        HybridThumbnailCache.entries.set(key, loaded);
        HybridThumbnailCache.prune();
        return pixelMap;
      })
      .catch((error: Error) => {
        const failed = HybridThumbnailCache.entries.get(key);
        if (failed) {
          failed.loadingPromise = undefined;
          if (!failed.pixelMap && failed.refCount <= 0) {
            HybridThumbnailCache.entries.delete(key);
          }
        }
        throw toError(error);
      });

    HybridThumbnailCache.entries.set(key, entry);
  }

  static release(key: string): void {
    const entry = HybridThumbnailCache.entries.get(key);
    if (!entry) {
      return;
    }

    if (entry.refCount > 0) {
      entry.refCount -= 1;
    }
    entry.lastUsedAt = Date.now();

    if (!entry.pixelMap && !entry.loadingPromise && entry.refCount <= 0) {
      HybridThumbnailCache.entries.delete(key);
      return;
    }

    HybridThumbnailCache.prune();
  }

  static pruneOutsideKeys(keepKeys: Set<string>): void {
    const removableKeys: Array<string> = [];
    HybridThumbnailCache.entries.forEach((entry: HybridThumbnailCacheEntry, key: string) => {
      if (keepKeys.has(key) || entry.refCount > 0 || entry.loadingPromise) {
        return;
      }
      removableKeys.push(key);
    });

    removableKeys.forEach((key: string) => {
      const entry = HybridThumbnailCache.entries.get(key);
      if (!entry || entry.refCount > 0 || entry.loadingPromise) {
        return;
      }
      try {
        entry.pixelMap?.release();
      } catch (_) {}
      HybridThumbnailCache.entries.delete(key);
    });
  }

  static touchRetainedKeys(keys: Array<string>): void {
    const now = Date.now();
    for (const key of keys) {
      const entry = HybridThumbnailCache.entries.get(key);
      if (entry?.pixelMap) {
        entry.lastUsedAt = now;
      }
    }
  }

  private static prune(): void {
    const cacheLimit = resolveAdaptiveCacheLimit(HybridThumbnailCache.activeColumns);
    if (HybridThumbnailCache.entries.size <= cacheLimit) {
      return;
    }

    const overflowKeys: Array<string> = [];
    HybridThumbnailCache.entries.forEach((entry: HybridThumbnailCacheEntry, key: string) => {
      if (entry.refCount <= 0 && !entry.loadingPromise) {
        overflowKeys.push(key);
      }
    });

    overflowKeys.sort((leftKey: string, rightKey: string) => {
      const leftEntry = HybridThumbnailCache.entries.get(leftKey);
      const rightEntry = HybridThumbnailCache.entries.get(rightKey);
      const leftUsedAt = leftEntry?.lastUsedAt ?? 0;
      const rightUsedAt = rightEntry?.lastUsedAt ?? 0;
      return leftUsedAt - rightUsedAt;
    });

    while (HybridThumbnailCache.entries.size > cacheLimit && overflowKeys.length > 0) {
      const key = overflowKeys.shift();
      if (!key) {
        break;
      }

      const entry = HybridThumbnailCache.entries.get(key);
      if (!entry || entry.refCount > 0 || entry.loadingPromise) {
        continue;
      }
      try {
        entry.pixelMap?.release();
      } catch (_) {}
      HybridThumbnailCache.entries.delete(key);
    }
  }
}

export function buildThumbnailCacheKey(assetId: string, requestSize: number): string {
  return `${assetId}@${requestSize}`;
}

class HybridRemoteThumbnailWarmup {
  private static entries: Map<string, HybridRemoteCacheEntry> = new Map();

  static predownload(
    ctx: common.UIAbilityContext,
    asset: HybridPhotoAsset,
    requestSize: number,
  ): void {
    if (!HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      HybridThumbnailCache.prefetch(buildThumbnailCacheKey(asset.id, requestSize), () =>
        loadThumbnailForPrefetchAsset(ctx, asset, requestSize)
      );
      return;
    }

    if (!asset.thumbnailUrl) {
      return;
    }

    if (Disk.hasRemoteThumbnailCache(ctx, asset.thumbnailUrl, requestSize)) {
      HybridThumbnailCache.prefetch(buildThumbnailCacheKey(asset.id, requestSize), () =>
        loadThumbnailForPrefetchAsset(ctx, asset, requestSize)
      );
      return;
    }

    const key = `${requestSize}:${asset.thumbnailUrl}`;
    const existing = HybridRemoteThumbnailWarmup.entries.get(key);
    if (existing?.downloadingPromise) {
      return;
    }

    const entry: HybridRemoteCacheEntry = existing ?? {};
    entry.downloadingPromise = HybridRemoteWarmupLimiter.run(() =>
      Disk.ensureRemoteThumbnailCached(ctx, asset.thumbnailUrl as string, requestSize)
    )
      .then(() => {
        HybridThumbnailCache.prefetch(buildThumbnailCacheKey(asset.id, requestSize), () =>
          loadThumbnailForPrefetchAsset(ctx, asset, requestSize)
        );
      })
      .catch(() => {})
      .finally(() => {
        const current = HybridRemoteThumbnailWarmup.entries.get(key);
        if (current) {
          current.downloadingPromise = undefined;
          HybridRemoteThumbnailWarmup.entries.delete(key);
        }
      });

    HybridRemoteThumbnailWarmup.entries.set(key, entry);
  }
}

class HybridRemoteWarmupLimiter {
  private static activeCount: number = 0;
  private static waiters: Array<() => void> = [];

  static async run<T>(task: () => Promise<T>): Promise<T> {
    await HybridRemoteWarmupLimiter.acquire();
    try {
      return await task();
    } finally {
      HybridRemoteWarmupLimiter.release();
    }
  }

  private static async acquire(): Promise<void> {
    if (HybridRemoteWarmupLimiter.tryAcquire()) {
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      HybridRemoteWarmupLimiter.waiters.push(resolve);
    });
  }

  private static tryAcquire(): boolean {
    if (HybridRemoteWarmupLimiter.activeCount >= resolveHybridPrefetchConcurrency()) {
      return false;
    }

    HybridRemoteWarmupLimiter.activeCount += 1;
    return true;
  }

  private static release(): void {
    if (HybridRemoteWarmupLimiter.activeCount > 0) {
      HybridRemoteWarmupLimiter.activeCount -= 1;
    }

    if (
      HybridRemoteWarmupLimiter.waiters.length > 0 &&
      HybridRemoteWarmupLimiter.tryAcquire()
    ) {
      const waiter = HybridRemoteWarmupLimiter.waiters.shift();
      waiter?.();
    }
  }
}

export class HybridThumbnailRequestLimiter {
  private static activeCount: number = 0;
  private static activePrefetchCount: number = 0;
  private static visibleWaiters: Array<() => void> = [];
  private static prefetchWaiters: Array<() => void> = [];
  private static scrollActive: boolean = false;
  private static readonly SCROLL_VISIBLE_THUMBNAIL_LIMIT: number = 8;
  private static readonly SCROLL_PREFETCH_LIMIT: number = 2;

  static async run(task: () => Promise<PixelMap>, isPrefetch: boolean): Promise<PixelMap> {
    await HybridThumbnailRequestLimiter.acquire(isPrefetch);
    try {
      return await task();
    } finally {
      HybridThumbnailRequestLimiter.release(isPrefetch);
    }
  }

  static setScrollActive(active: boolean): void {
    HybridThumbnailRequestLimiter.scrollActive = active;
    // When scroll stops, resume any held-back waiters
    if (!active) {
      HybridThumbnailRequestLimiter.resumeNext();
    }
  }

  static drainStalePrefetchWaiters(): void {
    // Drop all queued prefetch waiters on scroll start — their viewport targets are stale.
    // Resolve each promise so the caller's async chain finishes (the limiter never acquired
    // a slot for them, so no release is needed). The prefetch loader will run but the cache
    // entry will be pruned later if it falls outside the keep range.
    const stale = HybridThumbnailRequestLimiter.prefetchWaiters.splice(0);
    for (const waiter of stale) {
      waiter();
    }
  }

  static shouldPausePrefetch(): boolean {
    if (!HybridThumbnailRequestLimiter.scrollActive) {
      return false;
    }

    return HybridThumbnailRequestLimiter.activePrefetchCount >=
      HybridThumbnailRequestLimiter.SCROLL_PREFETCH_LIMIT ||
      HybridThumbnailRequestLimiter.activeCount >=
      HybridThumbnailRequestLimiter.SCROLL_VISIBLE_THUMBNAIL_LIMIT;
  }

  /**
   * Returns true when the system is under visible-request pressure:
   * scrolling actively OR many in-flight visible requests.
   * Background predownloads should yield when this returns true.
   */
  static isUnderPressure(): boolean {
    if (HybridThumbnailRequestLimiter.scrollActive) {
      return true;
    }
    // If more than half the idle capacity is consumed by visible requests, back off
    return HybridThumbnailRequestLimiter.activeCount >= Math.floor(HYBRID_MAX_CONCURRENT_THUMBNAIL_REQUESTS / 2);
  }

  private static async acquire(isPrefetch: boolean): Promise<void> {
    if (HybridThumbnailRequestLimiter.tryAcquire(isPrefetch)) {
      return;
    }

    await new Promise<void>((resolve: () => void) => {
      if (isPrefetch) {
        HybridThumbnailRequestLimiter.prefetchWaiters.push(resolve);
      } else {
        HybridThumbnailRequestLimiter.visibleWaiters.push(resolve);
      }
    });
  }

  private static tryAcquire(isPrefetch: boolean): boolean {
    const thumbnailLimit = HybridThumbnailRequestLimiter.scrollActive
      ? HybridThumbnailRequestLimiter.SCROLL_VISIBLE_THUMBNAIL_LIMIT
      : HYBRID_MAX_CONCURRENT_THUMBNAIL_REQUESTS;
    const prefetchLimit = HybridThumbnailRequestLimiter.scrollActive
      ? HybridThumbnailRequestLimiter.SCROLL_PREFETCH_LIMIT
      : resolveHybridPrefetchConcurrency();

    if (HybridThumbnailRequestLimiter.activeCount >= thumbnailLimit) {
      return false;
    }

    if (isPrefetch && prefetchLimit <= 0) {
      return false;
    }

    if (
      isPrefetch &&
      HybridThumbnailRequestLimiter.activePrefetchCount >= prefetchLimit
    ) {
      return false;
    }

    HybridThumbnailRequestLimiter.activeCount += 1;
    if (isPrefetch) {
      HybridThumbnailRequestLimiter.activePrefetchCount += 1;
    }
    return true;
  }

  private static release(isPrefetch: boolean): void {
    if (HybridThumbnailRequestLimiter.activeCount > 0) {
      HybridThumbnailRequestLimiter.activeCount -= 1;
    }
    if (isPrefetch && HybridThumbnailRequestLimiter.activePrefetchCount > 0) {
      HybridThumbnailRequestLimiter.activePrefetchCount -= 1;
    }

    HybridThumbnailRequestLimiter.resumeNext();
  }

  private static resumeNext(): void {
    if (
      HybridThumbnailRequestLimiter.visibleWaiters.length > 0 &&
      HybridThumbnailRequestLimiter.tryAcquire(false)
    ) {
      const waiter = HybridThumbnailRequestLimiter.visibleWaiters.shift();
      waiter?.();
      return;
    }

    if (
      HybridThumbnailRequestLimiter.prefetchWaiters.length > 0 &&
      HybridThumbnailRequestLimiter.tryAcquire(true)
    ) {
      const waiter = HybridThumbnailRequestLimiter.prefetchWaiters.shift();
      waiter?.();
    }
  }
}

async function loadThumbnailForAsset(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
  isPrefetch: boolean,
): Promise<PixelMap> {
  return await HybridThumbnailRequestLimiter.run(async () => {
    if (asset.localId) {
      try {
        return await loadLocalThumbnail(ctx, asset.localId, requestSize);
      } catch (error) {
        if (!asset.thumbnailUrl) {
          throw toError(error);
        }
      }
    }

    if (asset.thumbnailUrl) {
      return await Disk.loadRemoteThumbnail(ctx, asset.thumbnailUrl, requestSize);
    }

    throw new Error('No thumbnail source available');
  }, isPrefetch);
}

async function loadThumbnailForVisibleAsset(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): Promise<PixelMap> {
  return await loadThumbnailForAsset(ctx, asset, requestSize, false);
}

async function loadThumbnailForPrefetchAsset(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): Promise<PixelMap> {
  return await loadThumbnailForAsset(ctx, asset, requestSize, true);
}

async function loadLocalThumbnail(
  ctx: common.UIAbilityContext,
  assetId: string,
  requestSize: number,
): Promise<PixelMap> {
  const resolved = await resolveLocalPhotoAsset(ctx, assetId);
  try {
    return await resolved.asset.getThumbnail({ width: requestSize, height: requestSize });
  } catch (error) {
    if (!resolved.fromCache) {
      throw toError(error);
    }

    HybridLocalPhotoAssetCache.invalidate(assetId);
    const refreshedAsset = await queryLocalPhotoAsset(ctx, assetId);
    return await refreshedAsset.getThumbnail({ width: requestSize, height: requestSize });
  }
}

async function resolveLocalPhotoAsset(
  ctx: common.UIAbilityContext,
  assetId: string,
): Promise<ResolvedHybridLocalPhotoAsset> {
  const cachedAsset = HybridLocalPhotoAssetCache.acquire(assetId);
  if (cachedAsset) {
    return {
      asset: cachedAsset,
      fromCache: true,
    };
  }

  return {
    asset: await queryLocalPhotoAsset(ctx, assetId),
    fromCache: false,
  };
}

async function queryLocalPhotoAsset(
  ctx: common.UIAbilityContext,
  assetId: string,
): Promise<photoAccessHelper.PhotoAsset> {
  const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
  const predicates = new dataSharePredicates.DataSharePredicates();
  predicates.equalTo(photoAccessHelper.PhotoKeys.URI, assetId);

  let result: photoAccessHelper.FetchResult<photoAccessHelper.PhotoAsset> | undefined = undefined;
  try {
    result = await helper.getAssets({
      fetchColumns: [photoAccessHelper.PhotoKeys.URI],
      predicates: predicates,
    });
    const photoAsset = await result.getFirstObject();
    if (!photoAsset) {
      throw new Error(`Local asset not found: ${assetId}`);
    }
    HybridLocalPhotoAssetCache.store(assetId, photoAsset);
    return photoAsset;
  } catch (error) {
    HybridLocalPhotoAssetCache.invalidate(assetId);
    throw toError(error);
  } finally {
    try {
      result?.close();
    } catch (_) {}
  }
}

export function warmupAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): void {
  if (HybridThumbnailRequestLimiter.shouldPausePrefetch()) {
    return;
  }

  if (asset.localId) {
    HybridThumbnailCache.prefetch(buildThumbnailCacheKey(asset.id, requestSize), () =>
      loadThumbnailForPrefetchAsset(ctx, asset, requestSize)
    );
    return;
  }

  if (asset.thumbnailUrl) {
    HybridRemoteThumbnailWarmup.predownload(ctx, asset, requestSize);
  }
}

export async function loadVisibleAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): Promise<PixelMap> {
  return await loadThumbnailForVisibleAsset(ctx, asset, requestSize);
}

export function prefetchAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): void {
  if (HybridThumbnailRequestLimiter.shouldPausePrefetch()) {
    return;
  }

  HybridThumbnailCache.prefetch(buildThumbnailCacheKey(asset.id, requestSize), () =>
    loadThumbnailForPrefetchAsset(ctx, asset, requestSize)
  );
}

export function setPrefetchRuntimeMode(mode: HybridPrefetchRuntimeMode): void {
  setHybridPrefetchRuntimeMode(mode);
}

export function setRuntimeScrollActive(active: boolean): void {
  HybridThumbnailRequestLimiter.setScrollActive(active);
  Disk.HybridScrollState.isScrolling = active;
}

export async function backgroundPredownloadRemoteThumbnail(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
): Promise<void> {
  await Disk.HybridRemoteThumbnailBackgroundPredownload.predownload(ctx, url, requestSize);
}

export function flushDeferredThumbnailWritesIfIdle(): void {
  Disk.flushDeferredThumbnailWritesIfIdle();
}

export function trimRemoteThumbnailCacheIfNeeded(
  ctx: common.UIAbilityContext,
  force: boolean = false,
): void {
  Disk.HybridRemoteThumbnailCachePruner.trimIfNeeded(ctx, force);
}

export function shouldContinueBackgroundPredownload(ctx: common.UIAbilityContext): boolean {
  return Disk.HybridRemoteThumbnailCacheIndex.totalTrackedBytes(ctx, true) <
    HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES;
}
