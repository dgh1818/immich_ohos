import { common } from '@kit.AbilityKit';
import { dataSharePredicates } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import {
  HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES,
  HYBRID_GRID_COLUMNS,
  HYBRID_IDLE_COMPRESSED_BUFFER_PRELOAD_TARGET,
  HYBRID_MAX_CONCURRENT_REMOTE_WARMUP_DOWNLOADS,
  HYBRID_MAX_CONCURRENT_THUMBNAIL_REQUESTS,
  HYBRID_PREFETCH_READY_RETENTION_MS,
  HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES,
  HYBRID_SCROLL_COMPRESSED_BUFFER_PRELOAD_LOW_WATERMARK,
  HYBRID_SCROLL_PREFETCH_LIMIT,
  HYBRID_SCROLL_VISIBLE_THUMBNAIL_LIMIT,
  HYBRID_THUMBNAIL_RELEASE_DELAY_MS,
  HybridPhotoAsset,
  HybridPrefetchRuntimeMode,
  HybridRemoteCacheEntry,
  HybridThumbnailCacheEntry,
  resolveHybridCanonicalRequestSizeBucket,
  resolveHybridPrefetchConcurrency,
  resolveAdaptiveCacheLimit,
  setHybridPrefetchRuntimeMode,
} from './HybridPhotoGridShared';
import * as Disk from './HybridPhotoThumbnailDisk';
export {
  HybridRemotePredownloadPriorityHint,
  HybridRemoteThumbnailSourceKind,
  HybridRemoteThumbnailStatsSnapshot,
} from './HybridPhotoThumbnailDisk';

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

interface HybridPrefetchWaiter {
  generation: number;
  resolve: (acquired: boolean) => void;
}

interface HybridLoadedThumbnail {
  pixelMap: PixelMap;
  remoteSourceKind: Disk.HybridRemoteThumbnailSourceKind;
  remoteLoadPath: Disk.HybridRemoteThumbnailLoadPath;
}

enum HybridReadyAcquireState {
  HIT = 0,
  MISS_NO_ENTRY = 1,
  MISS_LOADING_PREFETCH = 2,
  MISS_LOADING_VISIBLE = 3,
  MISS_NOT_READY = 4,
}

enum HybridRemotePrefetchRequestState {
  SCHEDULED = 0,
  SKIP_READY = 1,
  SKIP_LOADING_PREFETCH = 2,
  SKIP_LOADING_VISIBLE = 3,
}

enum HybridRemotePrefetchResultState {
  COMPLETE = 0,
  FAIL = 1,
  STALE = 2,
  READY_EVICT = 3,
}

interface HybridThumbnailMetricBucket {
  startedAt: number;
  visibleLoadCount: number;
  visibleLoadTotalMs: number;
  visibleLoadMaxMs: number;
  visibleLoadOver16Ms: number;
  visibleRemoteLoadCount: number;
  visibleRemoteMemoryReadyCount: number;
  visibleRemoteResidentReadyCount: number;
  visibleRemotePrefetchJoinCount: number;
  visibleRemotePrefetchUpgradeCount: number;
  visibleRemoteCompressedBufferHitCount: number;
  visibleRemoteDeferredWriteHitCount: number;
  visibleRemotePersistedFileReadCount: number;
  visibleRemoteFileHitCount: number;
  visibleRemotePendingHitCount: number;
  visibleRemoteNetworkMissCount: number;
  visibleRemoteReadyAcquireHitCount: number;
  visibleRemoteReadyAcquireMissCount: number;
  visibleRemoteReadyAcquireMissNoEntryCount: number;
  visibleRemoteReadyAcquireMissLoadingPrefetchCount: number;
  visibleRemoteReadyAcquireMissLoadingVisibleCount: number;
  visibleRemoteReadyAcquireMissNotReadyCount: number;
  remotePrefetchRequestCount: number;
  remotePrefetchScheduledCount: number;
  remotePrefetchSkipReadyCount: number;
  remotePrefetchSkipLoadingPrefetchCount: number;
  remotePrefetchSkipLoadingVisibleCount: number;
  remotePrefetchCompleteCount: number;
  remotePrefetchFailCount: number;
  remotePrefetchStaleCount: number;
  remotePrefetchReadyEvictCount: number;
  releaseCount: number;
  releaseZeroRefCount: number;
  releaseRetainedCount: number;
  releaseTotalMs: number;
  pruneCount: number;
  pruneForceCount: number;
  pruneDeferredCount: number;
  pruneRemovedCount: number;
  pruneReleasedCount: number;
  pruneTotalMs: number;
  remoteStatsSnapshot: Disk.HybridRemoteThumbnailStatsSnapshot;
}

interface HybridRemoteThumbnailStatsDelta {
  remoteNetworkFetchCount: number;
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

class HybridThumbnailPerfStats {
  private static readonly SUMMARY_INTERVAL_MS: number = 2000;
  private static readonly VISIBLE_LOAD_SLOW_MS: number = 16;
  private static scrollingBucket: HybridThumbnailMetricBucket = HybridThumbnailPerfStats.createBucket();
  private static idleBucket: HybridThumbnailMetricBucket = HybridThumbnailPerfStats.createBucket();

  private static createBucket(): HybridThumbnailMetricBucket {
    return {
      startedAt: Date.now(),
      visibleLoadCount: 0,
      visibleLoadTotalMs: 0,
      visibleLoadMaxMs: 0,
      visibleLoadOver16Ms: 0,
      visibleRemoteLoadCount: 0,
      visibleRemoteMemoryReadyCount: 0,
      visibleRemoteResidentReadyCount: 0,
      visibleRemotePrefetchJoinCount: 0,
      visibleRemotePrefetchUpgradeCount: 0,
      visibleRemoteCompressedBufferHitCount: 0,
      visibleRemoteDeferredWriteHitCount: 0,
      visibleRemotePersistedFileReadCount: 0,
      visibleRemoteFileHitCount: 0,
      visibleRemotePendingHitCount: 0,
      visibleRemoteNetworkMissCount: 0,
      visibleRemoteReadyAcquireHitCount: 0,
      visibleRemoteReadyAcquireMissCount: 0,
      visibleRemoteReadyAcquireMissNoEntryCount: 0,
      visibleRemoteReadyAcquireMissLoadingPrefetchCount: 0,
      visibleRemoteReadyAcquireMissLoadingVisibleCount: 0,
      visibleRemoteReadyAcquireMissNotReadyCount: 0,
      remotePrefetchRequestCount: 0,
      remotePrefetchScheduledCount: 0,
      remotePrefetchSkipReadyCount: 0,
      remotePrefetchSkipLoadingPrefetchCount: 0,
      remotePrefetchSkipLoadingVisibleCount: 0,
      remotePrefetchCompleteCount: 0,
      remotePrefetchFailCount: 0,
      remotePrefetchStaleCount: 0,
      remotePrefetchReadyEvictCount: 0,
      releaseCount: 0,
      releaseZeroRefCount: 0,
      releaseRetainedCount: 0,
      releaseTotalMs: 0,
      pruneCount: 0,
      pruneForceCount: 0,
      pruneDeferredCount: 0,
      pruneRemovedCount: 0,
      pruneReleasedCount: 0,
      pruneTotalMs: 0,
      remoteStatsSnapshot: Disk.getRemoteThumbnailStatsSnapshot(),
    };
  }

  private static resolveBucket(scrolling: boolean): HybridThumbnailMetricBucket {
    return scrolling ? HybridThumbnailPerfStats.scrollingBucket : HybridThumbnailPerfStats.idleBucket;
  }

  private static resetBucket(scrolling: boolean): void {
    if (scrolling) {
      HybridThumbnailPerfStats.scrollingBucket = HybridThumbnailPerfStats.createBucket();
      return;
    }
    HybridThumbnailPerfStats.idleBucket = HybridThumbnailPerfStats.createBucket();
  }

  private static hasMetrics(bucket: HybridThumbnailMetricBucket): boolean {
    return bucket.visibleLoadCount > 0 ||
      bucket.visibleRemoteReadyAcquireHitCount > 0 ||
      bucket.visibleRemoteReadyAcquireMissCount > 0 ||
      bucket.remotePrefetchRequestCount > 0 ||
      bucket.remotePrefetchCompleteCount > 0 ||
      bucket.remotePrefetchFailCount > 0 ||
      bucket.remotePrefetchStaleCount > 0 ||
      bucket.remotePrefetchReadyEvictCount > 0 ||
      bucket.releaseCount > 0 ||
      bucket.pruneCount > 0 ||
      bucket.pruneDeferredCount > 0;
  }

  private static maybeFlush(scrolling: boolean, reason: string): void {
    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    if (!HybridThumbnailPerfStats.hasMetrics(bucket)) {
      return;
    }
    if (Date.now() - bucket.startedAt < HybridThumbnailPerfStats.SUMMARY_INTERVAL_MS) {
      return;
    }
    HybridThumbnailPerfStats.flushStage(scrolling, reason);
  }

  static noteVisibleLoad(
    durationMs: number,
    scrolling: boolean,
    remoteVisibleLoad: boolean,
    remoteMemoryReady: boolean,
    remoteSourceKind: Disk.HybridRemoteThumbnailSourceKind,
    remoteLoadPath: Disk.HybridRemoteThumbnailLoadPath,
    joinedInflightPrefetch: boolean,
  ): void {
    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    bucket.visibleLoadCount += 1;
    bucket.visibleLoadTotalMs += durationMs;
    bucket.visibleLoadMaxMs = Math.max(bucket.visibleLoadMaxMs, durationMs);
    if (durationMs > HybridThumbnailPerfStats.VISIBLE_LOAD_SLOW_MS) {
      bucket.visibleLoadOver16Ms += 1;
    }
    if (remoteVisibleLoad) {
      bucket.visibleRemoteLoadCount += 1;
      if (remoteMemoryReady) {
        bucket.visibleRemoteMemoryReadyCount += 1;
      }
      if (
        remoteMemoryReady ||
        remoteSourceKind === Disk.HybridRemoteThumbnailSourceKind.PERSISTED_FILE ||
        remoteSourceKind === Disk.HybridRemoteThumbnailSourceKind.PENDING_WRITE
      ) {
        bucket.visibleRemoteResidentReadyCount += 1;
      }
      if (joinedInflightPrefetch) {
        bucket.visibleRemotePrefetchJoinCount += 1;
      }
      if (remoteLoadPath === Disk.HybridRemoteThumbnailLoadPath.COMPRESSED_BUFFER) {
        bucket.visibleRemoteCompressedBufferHitCount += 1;
      } else if (remoteLoadPath === Disk.HybridRemoteThumbnailLoadPath.DEFERRED_WRITE) {
        bucket.visibleRemoteDeferredWriteHitCount += 1;
      } else if (remoteLoadPath === Disk.HybridRemoteThumbnailLoadPath.PERSISTED_FILE) {
        bucket.visibleRemotePersistedFileReadCount += 1;
      }
      if (remoteSourceKind === Disk.HybridRemoteThumbnailSourceKind.PERSISTED_FILE) {
        bucket.visibleRemoteFileHitCount += 1;
      } else if (remoteSourceKind === Disk.HybridRemoteThumbnailSourceKind.PENDING_WRITE) {
        bucket.visibleRemotePendingHitCount += 1;
      } else if (remoteSourceKind === Disk.HybridRemoteThumbnailSourceKind.NETWORK_MISS) {
        bucket.visibleRemoteNetworkMissCount += 1;
      }
    }
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static noteVisibleReadyAcquire(
    scrolling: boolean,
    isRemoteAsset: boolean,
    state: HybridReadyAcquireState,
  ): void {
    if (!isRemoteAsset) {
      return;
    }

    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    if (state === HybridReadyAcquireState.HIT) {
      bucket.visibleRemoteReadyAcquireHitCount += 1;
    } else {
      bucket.visibleRemoteReadyAcquireMissCount += 1;
      if (state === HybridReadyAcquireState.MISS_NO_ENTRY) {
        bucket.visibleRemoteReadyAcquireMissNoEntryCount += 1;
      } else if (state === HybridReadyAcquireState.MISS_LOADING_PREFETCH) {
        bucket.visibleRemoteReadyAcquireMissLoadingPrefetchCount += 1;
      } else if (state === HybridReadyAcquireState.MISS_LOADING_VISIBLE) {
        bucket.visibleRemoteReadyAcquireMissLoadingVisibleCount += 1;
      } else if (state === HybridReadyAcquireState.MISS_NOT_READY) {
        bucket.visibleRemoteReadyAcquireMissNotReadyCount += 1;
      }
    }
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static noteVisibleRemotePrefetchUpgrade(scrolling: boolean, isRemoteAsset: boolean): void {
    if (!isRemoteAsset) {
      return;
    }

    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    bucket.visibleRemotePrefetchUpgradeCount += 1;
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static noteRemotePrefetchRequest(
    scrolling: boolean,
    isRemoteAsset: boolean,
    state: HybridRemotePrefetchRequestState,
  ): void {
    if (!isRemoteAsset) {
      return;
    }

    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    bucket.remotePrefetchRequestCount += 1;
    if (state === HybridRemotePrefetchRequestState.SCHEDULED) {
      bucket.remotePrefetchScheduledCount += 1;
    } else if (state === HybridRemotePrefetchRequestState.SKIP_READY) {
      bucket.remotePrefetchSkipReadyCount += 1;
    } else if (state === HybridRemotePrefetchRequestState.SKIP_LOADING_PREFETCH) {
      bucket.remotePrefetchSkipLoadingPrefetchCount += 1;
    } else if (state === HybridRemotePrefetchRequestState.SKIP_LOADING_VISIBLE) {
      bucket.remotePrefetchSkipLoadingVisibleCount += 1;
    }
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static noteRemotePrefetchResult(
    scrolling: boolean,
    isRemoteAsset: boolean,
    state: HybridRemotePrefetchResultState,
  ): void {
    if (!isRemoteAsset) {
      return;
    }

    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    if (state === HybridRemotePrefetchResultState.COMPLETE) {
      bucket.remotePrefetchCompleteCount += 1;
    } else if (state === HybridRemotePrefetchResultState.FAIL) {
      bucket.remotePrefetchFailCount += 1;
    } else if (state === HybridRemotePrefetchResultState.STALE) {
      bucket.remotePrefetchStaleCount += 1;
    } else if (state === HybridRemotePrefetchResultState.READY_EVICT) {
      bucket.remotePrefetchReadyEvictCount += 1;
    }
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  private static resolveRemoteStatsDelta(
    bucket: HybridThumbnailMetricBucket,
  ): HybridRemoteThumbnailStatsDelta {
    const currentStats = Disk.getRemoteThumbnailStatsSnapshot();
    return {
      remoteNetworkFetchCount: Math.max(
        0,
        currentStats.remoteNetworkFetchCount - bucket.remoteStatsSnapshot.remoteNetworkFetchCount,
      ),
      remoteAstcDecodeCount: Math.max(
        0,
        currentStats.remoteAstcDecodeCount - bucket.remoteStatsSnapshot.remoteAstcDecodeCount,
      ),
      remoteAstcFallbackCount: Math.max(
        0,
        currentStats.remoteAstcFallbackCount - bucket.remoteStatsSnapshot.remoteAstcFallbackCount,
      ),
      deferredWriteDropCount: Math.max(
        0,
        currentStats.deferredWriteDropCount - bucket.remoteStatsSnapshot.deferredWriteDropCount,
      ),
      highWaterWaitCount: Math.max(
        0,
        currentStats.highWaterWaitCount - bucket.remoteStatsSnapshot.highWaterWaitCount,
      ),
      highWaterResumeCount: Math.max(
        0,
        currentStats.highWaterResumeCount - bucket.remoteStatsSnapshot.highWaterResumeCount,
      ),
      highWaterWaitTotalMs: Math.max(
        0,
        currentStats.highWaterWaitTotalMs - bucket.remoteStatsSnapshot.highWaterWaitTotalMs,
      ),
      highWaterLastWaitMs: currentStats.highWaterLastWaitMs,
      highWaterMaxWaitMs: currentStats.highWaterMaxWaitMs,
      deferredWriteQueueSize: currentStats.deferredWriteQueueSize,
      deferredWriteQueueBytes: currentStats.deferredWriteQueueBytes,
      compressedBufferCacheEntryCount: currentStats.compressedBufferCacheEntryCount,
      compressedBufferCacheBytes: currentStats.compressedBufferCacheBytes,
    };
  }

  static noteRelease(durationMs: number, scrolling: boolean, zeroRef: boolean, retained: boolean): void {
    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    bucket.releaseCount += 1;
    bucket.releaseTotalMs += durationMs;
    if (zeroRef) {
      bucket.releaseZeroRefCount += 1;
    }
    if (retained) {
      bucket.releaseRetainedCount += 1;
    }
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static notePruneDeferred(scrolling: boolean): void {
    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    bucket.pruneDeferredCount += 1;
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static notePrune(
    durationMs: number,
    scrolling: boolean,
    force: boolean,
    removedCount: number,
    releasedCount: number,
  ): void {
    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    bucket.pruneCount += 1;
    bucket.pruneTotalMs += durationMs;
    bucket.pruneRemovedCount += removedCount;
    bucket.pruneReleasedCount += releasedCount;
    if (force) {
      bucket.pruneForceCount += 1;
    }
    HybridThumbnailPerfStats.maybeFlush(scrolling, 'interval');
  }

  static flushStage(scrolling: boolean, reason: string): void {
    const bucket = HybridThumbnailPerfStats.resolveBucket(scrolling);
    if (!HybridThumbnailPerfStats.hasMetrics(bucket)) {
      HybridThumbnailPerfStats.resetBucket(scrolling);
      return;
    }

    const durationMs = Math.max(0, Date.now() - bucket.startedAt);
    const visibleLoadAvgMs = bucket.visibleLoadCount > 0
      ? Math.round(bucket.visibleLoadTotalMs / bucket.visibleLoadCount)
      : 0;
    const visibleRemoteMemoryReadyRate = bucket.visibleRemoteLoadCount > 0
      ? Math.round((bucket.visibleRemoteMemoryReadyCount * 100) / bucket.visibleRemoteLoadCount)
      : 0;
    const visibleRemoteResidentReadyRate = bucket.visibleRemoteLoadCount > 0
      ? Math.round((bucket.visibleRemoteResidentReadyCount * 100) / bucket.visibleRemoteLoadCount)
      : 0;
    const remoteStatsDelta = HybridThumbnailPerfStats.resolveRemoteStatsDelta(bucket);
    console.info(
      `[HybridPhotoThumbnail] metrics stage=${scrolling ? 'scrolling' : 'idle'} reason=${reason} durationMs=${durationMs} ` +
      `visibleLoads=${bucket.visibleLoadCount} visibleLoadTotalMs=${bucket.visibleLoadTotalMs} ` +
      `visibleLoadAvgMs=${visibleLoadAvgMs} visibleLoadMaxMs=${bucket.visibleLoadMaxMs} ` +
      `visibleLoadOver16Ms=${bucket.visibleLoadOver16Ms} visibleRemoteLoads=${bucket.visibleRemoteLoadCount} ` +
      `visibleRemoteMemoryReady=${bucket.visibleRemoteMemoryReadyCount} ` +
      `visibleRemoteMemoryReadyRate=${visibleRemoteMemoryReadyRate} ` +
      `visibleRemoteResidentReady=${bucket.visibleRemoteResidentReadyCount} ` +
      `visibleRemoteResidentReadyRate=${visibleRemoteResidentReadyRate} ` +
      `visibleRemotePrefetchJoin=${bucket.visibleRemotePrefetchJoinCount} ` +
      `visibleRemotePrefetchUpgrade=${bucket.visibleRemotePrefetchUpgradeCount} ` +
      `visibleRemoteReadyAcquireHit=${bucket.visibleRemoteReadyAcquireHitCount} ` +
      `visibleRemoteReadyAcquireMiss=${bucket.visibleRemoteReadyAcquireMissCount} ` +
      `visibleRemoteReadyAcquireMissNoEntry=${bucket.visibleRemoteReadyAcquireMissNoEntryCount} ` +
      `visibleRemoteReadyAcquireMissLoadingPrefetch=${bucket.visibleRemoteReadyAcquireMissLoadingPrefetchCount} ` +
      `visibleRemoteReadyAcquireMissLoadingVisible=${bucket.visibleRemoteReadyAcquireMissLoadingVisibleCount} ` +
      `visibleRemoteReadyAcquireMissNotReady=${bucket.visibleRemoteReadyAcquireMissNotReadyCount} ` +
      `visibleRemoteCompressedBufferHit=${bucket.visibleRemoteCompressedBufferHitCount} ` +
      `visibleRemoteDeferredWriteHit=${bucket.visibleRemoteDeferredWriteHitCount} ` +
      `visibleRemotePersistedFileRead=${bucket.visibleRemotePersistedFileReadCount} ` +
      `visibleRemoteFileHit=${bucket.visibleRemoteFileHitCount} ` +
      `visibleRemotePendingHit=${bucket.visibleRemotePendingHitCount} ` +
      `visibleRemoteNetworkMiss=${bucket.visibleRemoteNetworkMissCount} ` +
      `remotePrefetchRequests=${bucket.remotePrefetchRequestCount} ` +
      `remotePrefetchScheduled=${bucket.remotePrefetchScheduledCount} ` +
      `remotePrefetchSkipReady=${bucket.remotePrefetchSkipReadyCount} ` +
      `remotePrefetchSkipLoadingPrefetch=${bucket.remotePrefetchSkipLoadingPrefetchCount} ` +
      `remotePrefetchSkipLoadingVisible=${bucket.remotePrefetchSkipLoadingVisibleCount} ` +
      `remotePrefetchComplete=${bucket.remotePrefetchCompleteCount} ` +
      `remotePrefetchFail=${bucket.remotePrefetchFailCount} ` +
      `remotePrefetchStale=${bucket.remotePrefetchStaleCount} ` +
      `remotePrefetchReadyEvict=${bucket.remotePrefetchReadyEvictCount} ` +
      `remoteNetworkFetchCount=${remoteStatsDelta.remoteNetworkFetchCount} ` +
      `remoteAstcDecodeCount=${remoteStatsDelta.remoteAstcDecodeCount} ` +
      `remoteAstcFallbackCount=${remoteStatsDelta.remoteAstcFallbackCount} ` +
      `deferredWriteDropCount=${remoteStatsDelta.deferredWriteDropCount} ` +
      `highWaterWaitCount=${remoteStatsDelta.highWaterWaitCount} ` +
      `highWaterResumeCount=${remoteStatsDelta.highWaterResumeCount} ` +
      `highWaterWaitMs=${remoteStatsDelta.highWaterWaitTotalMs} ` +
      `highWaterLastWaitMs=${remoteStatsDelta.highWaterLastWaitMs} ` +
      `highWaterMaxWaitMs=${remoteStatsDelta.highWaterMaxWaitMs} ` +
      `deferredWriteQueueSize=${remoteStatsDelta.deferredWriteQueueSize} ` +
      `deferredWriteQueueBytes=${remoteStatsDelta.deferredWriteQueueBytes} ` +
      `compressedBufferEntries=${remoteStatsDelta.compressedBufferCacheEntryCount} ` +
      `compressedBufferBytes=${remoteStatsDelta.compressedBufferCacheBytes} ` +
      `releaseCount=${bucket.releaseCount} ` +
      `releaseZeroRef=${bucket.releaseZeroRefCount} releaseRetained=${bucket.releaseRetainedCount} ` +
      `releaseTotalMs=${bucket.releaseTotalMs} pruneCount=${bucket.pruneCount} ` +
      `pruneForce=${bucket.pruneForceCount} pruneDeferred=${bucket.pruneDeferredCount} ` +
      `pruneRemoved=${bucket.pruneRemovedCount} pruneReleased=${bucket.pruneReleasedCount} ` +
      `pruneTotalMs=${bucket.pruneTotalMs} cacheEntries=${HybridThumbnailCache.entryCount()}`,
    );
    HybridThumbnailPerfStats.resetBucket(scrolling);
  }
}

class HybridStalePrefetchError extends Error {
  constructor() {
    super('stale prefetch request');
  }
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
  private static remoteSourceKinds: Map<string, Disk.HybridRemoteThumbnailSourceKind> = new Map();
  private static remoteLoadPaths: Map<string, Disk.HybridRemoteThumbnailLoadPath> = new Map();
  private static viewportKeepKeys: Set<string> = new Set<string>();
  private static activeColumns: number = HYBRID_GRID_COLUMNS;
  private static pendingPrune: boolean = false;
  private static lastPruneAt: number = 0;
  private static readonly PRUNE_INTERVAL_MS: number = 120;
  private static readonly SCROLL_PRUNE_OVERFLOW_TILES_PER_COLUMN: number = 40;
  private static readonly MAX_RELEASES_PER_PRUNE_PASS: number = 96;
  private static readonly SCROLL_RELEASE_RETENTION_MS: number = Math.max(
    600,
    HYBRID_THUMBNAIL_RELEASE_DELAY_MS * 3,
  );
  private static deferredPruneTimeoutId?: number = undefined;

  static setActiveColumns(columns: number): void {
    HybridThumbnailCache.activeColumns = columns;
  }

  static entryCount(): number {
    return HybridThumbnailCache.entries.size;
  }

  static updateViewportKeepKeys(keys: Set<string>): void {
    const nextKeys: Set<string> = new Set<string>();
    keys.forEach((key: string) => {
      nextKeys.add(key);
    });
    HybridThumbnailCache.viewportKeepKeys = nextKeys;
  }

  static flushDeferredPrune(): void {
    HybridThumbnailCache.clearDeferredPruneTimer();
    if (
      !HybridThumbnailCache.pendingPrune &&
      HybridThumbnailCache.entries.size <= resolveAdaptiveCacheLimit(HybridThumbnailCache.activeColumns)
    ) {
      return;
    }

      HybridThumbnailCache.prune();
  }

  static hasReady(key: string): boolean {
    return !!HybridThumbnailCache.entries.get(key)?.pixelMap;
  }

  private static recordRemoteSourceKind(
    key: string,
    sourceKind: Disk.HybridRemoteThumbnailSourceKind,
  ): void {
    if (sourceKind === Disk.HybridRemoteThumbnailSourceKind.NONE) {
      HybridThumbnailCache.remoteSourceKinds.delete(key);
      return;
    }
    HybridThumbnailCache.remoteSourceKinds.set(key, sourceKind);
  }

  private static recordRemoteLoadPath(
    key: string,
    loadPath: Disk.HybridRemoteThumbnailLoadPath,
  ): void {
    if (loadPath === Disk.HybridRemoteThumbnailLoadPath.NONE) {
      HybridThumbnailCache.remoteLoadPaths.delete(key);
      return;
    }
    HybridThumbnailCache.remoteLoadPaths.set(key, loadPath);
  }

  private static resolveRemoteSourceKind(key: string): Disk.HybridRemoteThumbnailSourceKind {
    return HybridThumbnailCache.remoteSourceKinds.get(key) ?? Disk.HybridRemoteThumbnailSourceKind.NONE;
  }

  private static resolveRemoteLoadPath(key: string): Disk.HybridRemoteThumbnailLoadPath {
    return HybridThumbnailCache.remoteLoadPaths.get(key) ?? Disk.HybridRemoteThumbnailLoadPath.NONE;
  }

  private static deleteEntry(key: string): void {
    const entry = HybridThumbnailCache.entries.get(key);
    HybridThumbnailCache.noteRemotePrefetchReadyEvict(entry);
    HybridThumbnailCache.entries.delete(key);
    HybridThumbnailCache.remoteSourceKinds.delete(key);
    HybridThumbnailCache.remoteLoadPaths.delete(key);
  }

  private static noteRemotePrefetchReadyEvict(entry: HybridThumbnailCacheEntry | undefined): void {
    if (!entry?.pixelMap || entry.readyOriginPrefetch !== true || entry.readyPrefetchAcquired === true) {
      return;
    }

    HybridThumbnailPerfStats.noteRemotePrefetchResult(
      HybridThumbnailRequestLimiter.isScrollActive(),
      true,
      HybridRemotePrefetchResultState.READY_EVICT,
    );
  }

  static acquire(key: string, isRemoteAsset: boolean = false): PixelMap | undefined {
    const scrolling = HybridThumbnailRequestLimiter.isScrollActive();
    const entry = HybridThumbnailCache.entries.get(key);
    if (!entry) {
      HybridThumbnailPerfStats.noteVisibleReadyAcquire(
        scrolling,
        isRemoteAsset,
        HybridReadyAcquireState.MISS_NO_ENTRY,
      );
      return undefined;
    }

    if (!entry.pixelMap) {
      HybridThumbnailPerfStats.noteVisibleReadyAcquire(
        scrolling,
        isRemoteAsset,
        entry.loadingPromise
          ? (entry.loadingIsPrefetch === true
            ? HybridReadyAcquireState.MISS_LOADING_PREFETCH
            : HybridReadyAcquireState.MISS_LOADING_VISIBLE)
          : HybridReadyAcquireState.MISS_NOT_READY,
      );
      return undefined;
    }

    entry.refCount += 1;
    entry.lastUsedAt = Date.now();
    entry.retainUntilAt = 0;
    if (entry.readyOriginPrefetch === true) {
      entry.readyPrefetchAcquired = true;
    }
    HybridThumbnailPerfStats.noteVisibleReadyAcquire(
      scrolling,
      isRemoteAsset,
      HybridReadyAcquireState.HIT,
    );
    return entry.pixelMap;
  }

  private static startVisibleLoad(
    key: string,
    entry: HybridThumbnailCacheEntry,
    loader: () => Promise<HybridLoadedThumbnail>,
  ): Promise<PixelMap> {
    const nextLoadingToken = (entry.loadingToken ?? 0) + 1;
    entry.loadingToken = nextLoadingToken;
    entry.loadingIsPrefetch = false;
    entry.loadingStarted = false;

    const loadingPromise = loader()
      .then((loadedThumbnail: HybridLoadedThumbnail) => {
        const loaded: HybridThumbnailCacheEntry = HybridThumbnailCache.entries.get(key) ?? {
          refCount: 0,
          lastUsedAt: Date.now(),
        };
        if ((loaded.loadingToken ?? 0) !== nextLoadingToken) {
          try {
            loadedThumbnail.pixelMap.release();
          } catch (_) {}
          throw new HybridStalePrefetchError();
        }
        HybridThumbnailCache.recordRemoteSourceKind(key, loadedThumbnail.remoteSourceKind);
        HybridThumbnailCache.recordRemoteLoadPath(key, loadedThumbnail.remoteLoadPath);
        const pixelMap = loadedThumbnail.pixelMap;
        loaded.pixelMap = pixelMap;
        loaded.loadingPromise = undefined;
        loaded.loadingIsPrefetch = false;
        loaded.loadingStarted = false;
        loaded.loadingToken = nextLoadingToken;
        loaded.readyOriginPrefetch = false;
        loaded.readyPrefetchAcquired = false;
        loaded.lastUsedAt = Date.now();
        loaded.retainUntilAt = 0;
        HybridThumbnailCache.entries.set(key, loaded);
        HybridThumbnailCache.prune();
        return pixelMap;
      })
      .catch((error: Error) => {
        const failed = HybridThumbnailCache.entries.get(key);
        if (failed && (failed.loadingToken ?? 0) === nextLoadingToken) {
          failed.loadingPromise = undefined;
          failed.loadingIsPrefetch = false;
          failed.loadingStarted = false;
          if (!failed.pixelMap && failed.refCount <= 0) {
            HybridThumbnailCache.deleteEntry(key);
          }
        }
        throw toError(error);
      });

    entry.loadingPromise = loadingPromise;
    HybridThumbnailCache.entries.set(key, entry);
    return loadingPromise;
  }

  static async load(
    key: string,
    isRemoteAsset: boolean,
    loader: () => Promise<HybridLoadedThumbnail>,
  ): Promise<PixelMap> {
    const startedAt = Date.now();
    const scrolling = HybridThumbnailRequestLimiter.isScrollActive();
    let remoteMemoryReady = false;
    let remoteSourceKind = HybridThumbnailCache.resolveRemoteSourceKind(key);
    let remoteLoadPath = HybridThumbnailCache.resolveRemoteLoadPath(key);
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
      existing.retainUntilAt = 0;
      if (existing.readyOriginPrefetch === true) {
        existing.readyPrefetchAcquired = true;
      }
      remoteMemoryReady = true;
      try {
        return existing.pixelMap;
      } finally {
        HybridThumbnailPerfStats.noteVisibleLoad(
          Date.now() - startedAt,
          scrolling,
          isRemoteAsset,
          remoteMemoryReady,
          remoteSourceKind,
          remoteLoadPath,
          false,
        );
      }
    }

    if (existing?.loadingPromise) {
      existing.refCount += 1;
      existing.lastUsedAt = now;
      existing.retainUntilAt = 0;
      const joinedInflightPrefetch = existing.loadingIsPrefetch === true && existing.loadingStarted === true;
      if (existing.loadingIsPrefetch === true && !joinedInflightPrefetch) {
        HybridThumbnailPerfStats.noteVisibleRemotePrefetchUpgrade(scrolling, isRemoteAsset);
      }
      const loadingPromise = joinedInflightPrefetch
        ? existing.loadingPromise.catch((error: Error) => {
            if (!(error instanceof HybridStalePrefetchError)) {
              throw toError(error);
            }

            const currentEntry = HybridThumbnailCache.entries.get(key);
            if (currentEntry?.pixelMap) {
              currentEntry.lastUsedAt = Date.now();
              currentEntry.retainUntilAt = 0;
              if (currentEntry.readyOriginPrefetch === true) {
                currentEntry.readyPrefetchAcquired = true;
              }
              remoteMemoryReady = true;
              return currentEntry.pixelMap;
            }

            return HybridThumbnailCache.startVisibleLoad(key, currentEntry ?? existing, loader);
          })
        : (existing.loadingIsPrefetch === true
          ? HybridThumbnailCache.startVisibleLoad(key, existing, loader)
          : existing.loadingPromise);
      try {
        const pixelMap = await loadingPromise;
        const loaded = HybridThumbnailCache.entries.get(key);
        if (loaded) {
          loaded.lastUsedAt = Date.now();
          loaded.retainUntilAt = 0;
        }
        remoteSourceKind = HybridThumbnailCache.resolveRemoteSourceKind(key);
        remoteLoadPath = HybridThumbnailCache.resolveRemoteLoadPath(key);
        return pixelMap;
      } catch (error) {
        existing.refCount = Math.max(0, existing.refCount - 1);
        existing.lastUsedAt = Date.now();
        if (!existing.pixelMap && !existing.loadingPromise && existing.refCount <= 0) {
          HybridThumbnailCache.deleteEntry(key);
        }
        throw toError(error);
      } finally {
        HybridThumbnailPerfStats.noteVisibleLoad(
          Date.now() - startedAt,
          scrolling,
          isRemoteAsset,
          remoteMemoryReady,
          remoteSourceKind,
          remoteLoadPath,
          joinedInflightPrefetch,
        );
      }
    }

    existing.refCount += 1;
    existing.lastUsedAt = now;

    try {
      const pixelMap = await HybridThumbnailCache.startVisibleLoad(key, existing, loader);
      remoteSourceKind = HybridThumbnailCache.resolveRemoteSourceKind(key);
      remoteLoadPath = HybridThumbnailCache.resolveRemoteLoadPath(key);
      return pixelMap;
    } catch (error) {
      existing.refCount = Math.max(0, existing.refCount - 1);
      existing.lastUsedAt = Date.now();
      if (!existing.pixelMap && !existing.loadingPromise && existing.refCount <= 0) {
        HybridThumbnailCache.deleteEntry(key);
      }
      throw toError(error);
    } finally {
      HybridThumbnailPerfStats.noteVisibleLoad(
        Date.now() - startedAt,
        scrolling,
        isRemoteAsset,
        false,
        remoteSourceKind,
        remoteLoadPath,
        false,
      );
    }
  }

  static prefetch(
    key: string,
    isRemoteAsset: boolean,
    loader: (onStart: () => void) => Promise<HybridLoadedThumbnail>,
  ): boolean {
    const scrolling = HybridThumbnailRequestLimiter.isScrollActive();
    const existing = HybridThumbnailCache.entries.get(key);
    if (existing?.pixelMap) {
      HybridThumbnailPerfStats.noteRemotePrefetchRequest(
        scrolling,
        isRemoteAsset,
        HybridRemotePrefetchRequestState.SKIP_READY,
      );
      return false;
    }

    if (existing?.loadingPromise) {
      HybridThumbnailPerfStats.noteRemotePrefetchRequest(
        scrolling,
        isRemoteAsset,
        existing.loadingIsPrefetch === true
          ? HybridRemotePrefetchRequestState.SKIP_LOADING_PREFETCH
          : HybridRemotePrefetchRequestState.SKIP_LOADING_VISIBLE,
      );
      return false;
    }

    HybridThumbnailPerfStats.noteRemotePrefetchRequest(
      scrolling,
      isRemoteAsset,
      HybridRemotePrefetchRequestState.SCHEDULED,
    );

    const entry: HybridThumbnailCacheEntry = existing ?? {
      refCount: 0,
      lastUsedAt: Date.now(),
    };
    const nextLoadingToken = (entry.loadingToken ?? 0) + 1;
    entry.loadingToken = nextLoadingToken;
    entry.loadingIsPrefetch = true;
    entry.loadingStarted = false;

    const markLoadingStarted = (): void => {
      const current = HybridThumbnailCache.entries.get(key);
      if (current && (current.loadingToken ?? 0) === nextLoadingToken) {
        current.loadingStarted = true;
      }
    };

    entry.loadingPromise = loader(markLoadingStarted)
      .then((loadedThumbnail: HybridLoadedThumbnail) => {
        const loaded: HybridThumbnailCacheEntry = HybridThumbnailCache.entries.get(key) ?? {
          refCount: 0,
          lastUsedAt: Date.now(),
        };
        if ((loaded.loadingToken ?? 0) !== nextLoadingToken) {
          try {
            loadedThumbnail.pixelMap.release();
          } catch (_) {}
          throw new HybridStalePrefetchError();
        }
        HybridThumbnailCache.recordRemoteSourceKind(key, loadedThumbnail.remoteSourceKind);
        HybridThumbnailCache.recordRemoteLoadPath(key, loadedThumbnail.remoteLoadPath);
        const pixelMap = loadedThumbnail.pixelMap;
        loaded.pixelMap = pixelMap;
        loaded.loadingPromise = undefined;
        loaded.loadingIsPrefetch = false;
        loaded.loadingStarted = false;
        loaded.loadingToken = nextLoadingToken;
        loaded.readyOriginPrefetch = true;
        loaded.readyPrefetchAcquired = false;
        loaded.lastUsedAt = Date.now();
        loaded.retainUntilAt = loaded.lastUsedAt + HYBRID_PREFETCH_READY_RETENTION_MS;
        HybridThumbnailCache.entries.set(key, loaded);
        HybridThumbnailCache.prune();
        HybridThumbnailPerfStats.noteRemotePrefetchResult(
          HybridThumbnailRequestLimiter.isScrollActive(),
          isRemoteAsset,
          HybridRemotePrefetchResultState.COMPLETE,
        );
        return pixelMap;
      })
      .catch((error: Error) => {
        const failed = HybridThumbnailCache.entries.get(key);
        if (failed && (failed.loadingToken ?? 0) === nextLoadingToken) {
          failed.loadingPromise = undefined;
          failed.loadingIsPrefetch = false;
          failed.loadingStarted = false;
          if (!failed.pixelMap && failed.refCount <= 0) {
            HybridThumbnailCache.deleteEntry(key);
          }
        }
        HybridThumbnailPerfStats.noteRemotePrefetchResult(
          HybridThumbnailRequestLimiter.isScrollActive(),
          isRemoteAsset,
          error instanceof HybridStalePrefetchError
            ? HybridRemotePrefetchResultState.STALE
            : HybridRemotePrefetchResultState.FAIL,
        );
        throw toError(error);
      });

    HybridThumbnailCache.entries.set(key, entry);
    return true;
  }

  static release(key: string): void {
    const startedAt = Date.now();
    const scrolling = HybridThumbnailRequestLimiter.isScrollActive();
    const entry = HybridThumbnailCache.entries.get(key);
    if (!entry) {
      return;
    }

    if (entry.refCount > 0) {
      entry.refCount -= 1;
    }
    entry.lastUsedAt = Date.now();

    const zeroRef = entry.refCount <= 0;
    let retained = false;
    if (zeroRef && entry.pixelMap) {
      entry.retainUntilAt = entry.lastUsedAt + HybridThumbnailCache.resolveReleaseRetentionMs(scrolling);
      retained = true;
    }

    if (!entry.pixelMap && !entry.loadingPromise && zeroRef) {
      HybridThumbnailCache.deleteEntry(key);
      HybridThumbnailPerfStats.noteRelease(Date.now() - startedAt, scrolling, true, false);
      return;
    }

    HybridThumbnailCache.schedulePruneIfNeeded(scrolling);
    HybridThumbnailPerfStats.noteRelease(Date.now() - startedAt, scrolling, zeroRef, retained);
  }

  static pruneOutsideKeys(keepKeys: Set<string>): void {
    const startedAt = Date.now();
    const scrolling = HybridThumbnailRequestLimiter.isScrollActive();
    const now = Date.now();
    const removableKeys: Array<string> = [];
    HybridThumbnailCache.entries.forEach((entry: HybridThumbnailCacheEntry, key: string) => {
      if (
        keepKeys.has(key) ||
        HybridThumbnailCache.viewportKeepKeys.has(key) ||
        entry.refCount > 0 ||
        entry.loadingPromise ||
        HybridThumbnailCache.shouldRetainEntry(entry, now, false)
      ) {
        return;
      }
      removableKeys.push(key);
    });

    let removedCount = 0;
    let releasedCount = 0;
    removableKeys.forEach((key: string) => {
      const entry = HybridThumbnailCache.entries.get(key);
      if (
        !entry ||
        keepKeys.has(key) ||
        HybridThumbnailCache.viewportKeepKeys.has(key) ||
        entry.refCount > 0 ||
        entry.loadingPromise ||
        HybridThumbnailCache.shouldRetainEntry(entry, now, false)
      ) {
        return;
      }
      try {
        entry.pixelMap?.release();
      } catch (_) {}
      HybridThumbnailCache.deleteEntry(key);
      removedCount += 1;
      if (entry.pixelMap) {
        releasedCount += 1;
      }
    });
    if (HybridThumbnailCache.entries.size > resolveAdaptiveCacheLimit(HybridThumbnailCache.activeColumns)) {
      HybridThumbnailCache.pendingPrune = true;
      HybridThumbnailCache.scheduleDeferredPrune(HybridThumbnailCache.resolveNextRetentionDelayMs(now));
    }
    HybridThumbnailPerfStats.notePrune(Date.now() - startedAt, scrolling, false, removedCount, releasedCount);
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

  private static resolveScrollOverflowLimit(cacheLimit: number): number {
    return cacheLimit + Math.max(
      48,
      HybridThumbnailCache.activeColumns * HybridThumbnailCache.SCROLL_PRUNE_OVERFLOW_TILES_PER_COLUMN,
    );
  }

  private static clearDeferredPruneTimer(): void {
    if (HybridThumbnailCache.deferredPruneTimeoutId === undefined) {
      return;
    }
    clearTimeout(HybridThumbnailCache.deferredPruneTimeoutId);
    HybridThumbnailCache.deferredPruneTimeoutId = undefined;
  }

  private static scheduleDeferredPrune(delayMs: number): void {
    if (HybridThumbnailCache.deferredPruneTimeoutId !== undefined) {
      return;
    }
    const safeDelayMs = Math.max(0, delayMs);
    HybridThumbnailCache.deferredPruneTimeoutId = setTimeout((): void => {
      HybridThumbnailCache.deferredPruneTimeoutId = undefined;
      HybridThumbnailCache.prune();
    }, safeDelayMs);
  }

  private static resolveReleaseRetentionMs(scrolling: boolean): number {
    return scrolling
      ? HybridThumbnailCache.SCROLL_RELEASE_RETENTION_MS
      : HYBRID_THUMBNAIL_RELEASE_DELAY_MS;
  }

  private static shouldRetainEntry(
    entry: HybridThumbnailCacheEntry,
    now: number,
    force: boolean,
  ): boolean {
    if (force || !entry.pixelMap) {
      return false;
    }
    const retainUntilAt = entry.retainUntilAt ?? 0;
    return retainUntilAt > now;
  }

  private static resolveNextRetentionDelayMs(now: number): number {
    let nextDelayMs = HybridThumbnailCache.PRUNE_INTERVAL_MS;
    HybridThumbnailCache.entries.forEach((entry: HybridThumbnailCacheEntry) => {
      if (entry.refCount > 0 || entry.loadingPromise || !entry.pixelMap) {
        return;
      }
      const retainUntilAt = entry.retainUntilAt ?? 0;
      if (retainUntilAt <= now) {
        return;
      }
      nextDelayMs = Math.min(nextDelayMs, Math.max(0, retainUntilAt - now));
    });
    return nextDelayMs;
  }

  private static schedulePruneIfNeeded(scrolling: boolean): void {
    const cacheLimit = resolveAdaptiveCacheLimit(HybridThumbnailCache.activeColumns);
    if (!HybridThumbnailCache.pendingPrune && HybridThumbnailCache.entries.size <= cacheLimit) {
      return;
    }
    if (
      scrolling &&
      HybridThumbnailCache.entries.size <= HybridThumbnailCache.resolveScrollOverflowLimit(cacheLimit)
    ) {
      HybridThumbnailCache.pendingPrune = true;
      return;
    }
    const delayMs = scrolling
      ? HYBRID_THUMBNAIL_RELEASE_DELAY_MS
      : Math.max(40, Math.floor(HYBRID_THUMBNAIL_RELEASE_DELAY_MS / 2));
    HybridThumbnailCache.scheduleDeferredPrune(delayMs);
  }

  private static prune(force: boolean = false): void {
    const startedAt = Date.now();
    const scrolling = HybridThumbnailRequestLimiter.isScrollActive();
    const cacheLimit = resolveAdaptiveCacheLimit(HybridThumbnailCache.activeColumns);
    if (HybridThumbnailCache.entries.size <= cacheLimit) {
      HybridThumbnailCache.pendingPrune = false;
      return;
    }

    const now = Date.now();
    if (!force) {
      if (
        HybridThumbnailRequestLimiter.isScrollActive() &&
        HybridThumbnailCache.entries.size <= HybridThumbnailCache.resolveScrollOverflowLimit(cacheLimit)
      ) {
        HybridThumbnailCache.pendingPrune = true;
        HybridThumbnailPerfStats.notePruneDeferred(scrolling);
        return;
      }

      if (now - HybridThumbnailCache.lastPruneAt < HybridThumbnailCache.PRUNE_INTERVAL_MS) {
        HybridThumbnailCache.pendingPrune = true;
        HybridThumbnailCache.scheduleDeferredPrune(
          HybridThumbnailCache.PRUNE_INTERVAL_MS - (now - HybridThumbnailCache.lastPruneAt),
        );
        HybridThumbnailPerfStats.notePruneDeferred(scrolling);
        return;
      }
    }

    if (force) {
      HybridThumbnailCache.clearDeferredPruneTimer();
    }
    HybridThumbnailCache.pendingPrune = false;
    HybridThumbnailCache.lastPruneAt = now;

    const overflowKeys: Array<string> = [];
    HybridThumbnailCache.entries.forEach((entry: HybridThumbnailCacheEntry, key: string) => {
      if (
        !HybridThumbnailCache.viewportKeepKeys.has(key) &&
        entry.refCount <= 0 &&
        !entry.loadingPromise &&
        !HybridThumbnailCache.shouldRetainEntry(entry, now, force)
      ) {
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

    let removedCount = 0;
    let releasedCount = 0;
    while (
      HybridThumbnailCache.entries.size > cacheLimit &&
      overflowKeys.length > 0 &&
      removedCount < HybridThumbnailCache.MAX_RELEASES_PER_PRUNE_PASS
    ) {
      const key = overflowKeys.shift();
      if (!key) {
        break;
      }

      const entry = HybridThumbnailCache.entries.get(key);
      if (!entry || HybridThumbnailCache.viewportKeepKeys.has(key) || entry.refCount > 0 || entry.loadingPromise) {
        continue;
      }
      try {
        entry.pixelMap?.release();
      } catch (_) {}
      HybridThumbnailCache.deleteEntry(key);
      removedCount += 1;
      if (entry.pixelMap) {
        releasedCount += 1;
      }
    }

    if (HybridThumbnailCache.entries.size > cacheLimit) {
      HybridThumbnailCache.pendingPrune = true;
      const nextDelayMs = overflowKeys.length > 0
        ? HybridThumbnailCache.PRUNE_INTERVAL_MS
        : HybridThumbnailCache.resolveNextRetentionDelayMs(now);
      HybridThumbnailCache.scheduleDeferredPrune(nextDelayMs);
    }
    HybridThumbnailPerfStats.notePrune(Date.now() - startedAt, scrolling, force, removedCount, releasedCount);
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
    const cacheKey = buildThumbnailCacheKey(asset.id, requestSize);
    const prefetchGeneration = HybridThumbnailRequestLimiter.getPrefetchGeneration();
    if (!HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      HybridThumbnailCache.prefetch(cacheKey, true, (onStart: () => void) =>
        loadThumbnailForPrefetchAsset(ctx, asset, requestSize, prefetchGeneration, onStart)
      );
      return;
    }

    if (!asset.thumbnailUrl) {
      return;
    }

    const remoteDiskRequestSize = resolveHybridCanonicalRequestSizeBucket();
    if (Disk.hasRemoteThumbnailCache(ctx, asset.thumbnailUrl, remoteDiskRequestSize)) {
      HybridThumbnailCache.prefetch(cacheKey, true, (onStart: () => void) =>
        loadThumbnailForPrefetchAsset(ctx, asset, requestSize, prefetchGeneration, onStart)
      );
      return;
    }

    const key = asset.thumbnailUrl;
    const existing = HybridRemoteThumbnailWarmup.entries.get(key);
    if (existing?.downloadingPromise) {
      return;
    }

    const entry: HybridRemoteCacheEntry = existing ?? {};
    entry.downloadingPromise = HybridRemoteWarmupLimiter.run(() =>
      Disk.ensureRemoteThumbnailCached(ctx, asset.thumbnailUrl as string, remoteDiskRequestSize)
    )
      .then(() => {
        const nextPrefetchGeneration = HybridThumbnailRequestLimiter.getPrefetchGeneration();
        HybridThumbnailCache.prefetch(cacheKey, true, (onStart: () => void) =>
          loadThumbnailForPrefetchAsset(ctx, asset, requestSize, nextPrefetchGeneration, onStart)
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

class HybridRemoteThumbnailBufferWarmup {
  private static entries: Map<string, HybridRemoteCacheEntry> = new Map();

  static preload(
    ctx: common.UIAbilityContext,
    asset: HybridPhotoAsset,
    requestSize: number,
  ): boolean {
    if (!asset.thumbnailUrl || !HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return false;
    }

    const remoteDiskRequestSize = resolveHybridCanonicalRequestSizeBucket();
    void requestSize;
    if (Disk.hasRemoteThumbnailCompressedData(asset.thumbnailUrl, remoteDiskRequestSize)) {
      return false;
    }
    if (!Disk.hasPersistedRemoteThumbnailCache(ctx, asset.thumbnailUrl, remoteDiskRequestSize, false)) {
      return false;
    }

    const key = `${remoteDiskRequestSize}:${asset.thumbnailUrl}`;
    const existing = HybridRemoteThumbnailBufferWarmup.entries.get(key);
    if (existing?.downloadingPromise) {
      return false;
    }

    const entry: HybridRemoteCacheEntry = existing ?? {};
    entry.downloadingPromise = HybridRemoteWarmupLimiter.run(() =>
      Disk.preloadPersistedRemoteThumbnailBuffer(ctx, asset.thumbnailUrl as string, remoteDiskRequestSize)
    )
      .then(() => {})
      .catch(() => {})
      .finally(() => {
        const current = HybridRemoteThumbnailBufferWarmup.entries.get(key);
        if (current) {
          current.downloadingPromise = undefined;
          HybridRemoteThumbnailBufferWarmup.entries.delete(key);
        }
      });

    HybridRemoteThumbnailBufferWarmup.entries.set(key, entry);
    return true;
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
    if (HybridRemoteWarmupLimiter.activeCount >= HYBRID_MAX_CONCURRENT_REMOTE_WARMUP_DOWNLOADS) {
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
  private static prefetchWaiters: Array<HybridPrefetchWaiter> = [];
  private static prefetchGeneration: number = 0;
  private static scrollActive: boolean = false;
  private static readonly SCROLL_VISIBLE_THUMBNAIL_LIMIT: number = HYBRID_SCROLL_VISIBLE_THUMBNAIL_LIMIT;
  private static readonly SCROLL_PREFETCH_LIMIT: number = HYBRID_SCROLL_PREFETCH_LIMIT;
  private static readonly SCROLL_PREFETCH_BACKLOG_LIMIT: number = Math.max(
    12,
    HYBRID_SCROLL_PREFETCH_LIMIT * 4,
  );
  private static readonly SCROLL_NEAR_VISIBLE_PREFETCH_BACKLOG_ALLOWANCE: number = Math.max(
    6,
    Math.floor(HYBRID_SCROLL_PREFETCH_LIMIT / 2),
  );

  static getPrefetchGeneration(): number {
    return HybridThumbnailRequestLimiter.prefetchGeneration;
  }

  static async run<T>(
    task: () => Promise<T>,
    isPrefetch: boolean,
    prefetchGeneration: number = HybridThumbnailRequestLimiter.prefetchGeneration,
    onAcquired?: () => void,
  ): Promise<T> {
    const acquired = await HybridThumbnailRequestLimiter.acquire(isPrefetch, prefetchGeneration);
    if (!acquired) {
      throw new HybridStalePrefetchError();
    }

    if (isPrefetch && prefetchGeneration !== HybridThumbnailRequestLimiter.prefetchGeneration) {
      HybridThumbnailRequestLimiter.release(isPrefetch);
      throw new HybridStalePrefetchError();
    }

    onAcquired?.();

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

  static isScrollActive(): boolean {
    return HybridThumbnailRequestLimiter.scrollActive;
  }

  static drainStalePrefetchWaiters(): void {
    HybridThumbnailRequestLimiter.prefetchGeneration += 1;
    const stale = HybridThumbnailRequestLimiter.prefetchWaiters.splice(0);
    for (let index = 0; index < stale.length; index += 1) {
      stale[index].resolve(false);
    }
  }

  static shouldPausePrefetch(): boolean {
    if (!HybridThumbnailRequestLimiter.scrollActive) {
      return false;
    }

    return HybridThumbnailRequestLimiter.activePrefetchCount +
      HybridThumbnailRequestLimiter.prefetchWaiters.length >=
      HybridThumbnailRequestLimiter.SCROLL_PREFETCH_BACKLOG_LIMIT;
  }

  static shouldPauseNearVisiblePrefetch(): boolean {
    if (!HybridThumbnailRequestLimiter.scrollActive) {
      return false;
    }

    return HybridThumbnailRequestLimiter.activePrefetchCount +
      HybridThumbnailRequestLimiter.prefetchWaiters.length >=
      HybridThumbnailRequestLimiter.SCROLL_PREFETCH_BACKLOG_LIMIT +
        HybridThumbnailRequestLimiter.SCROLL_NEAR_VISIBLE_PREFETCH_BACKLOG_ALLOWANCE;
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

  private static async acquire(isPrefetch: boolean, prefetchGeneration: number): Promise<boolean> {
    if (HybridThumbnailRequestLimiter.tryAcquire(isPrefetch)) {
      return true;
    }

    return await new Promise<boolean>((resolve: (acquired: boolean) => void) => {
      if (isPrefetch) {
        if (prefetchGeneration !== HybridThumbnailRequestLimiter.prefetchGeneration) {
          resolve(false);
          return;
        }
        HybridThumbnailRequestLimiter.prefetchWaiters.push({
          generation: prefetchGeneration,
          resolve: resolve,
        });
      } else {
        HybridThumbnailRequestLimiter.visibleWaiters.push(() => {
          resolve(true);
        });
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

    while (HybridThumbnailRequestLimiter.prefetchWaiters.length > 0) {
      const waiter = HybridThumbnailRequestLimiter.prefetchWaiters.shift();
      if (!waiter) {
        return;
      }
      if (waiter.generation !== HybridThumbnailRequestLimiter.prefetchGeneration) {
        waiter.resolve(false);
        continue;
      }
      if (!HybridThumbnailRequestLimiter.tryAcquire(true)) {
        HybridThumbnailRequestLimiter.prefetchWaiters.unshift(waiter);
        return;
      }
      waiter.resolve(true);
      return;
    }
  }
}

async function loadThumbnailForAsset(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
  isPrefetch: boolean,
  prefetchGeneration?: number,
  onStart?: () => void,
): Promise<HybridLoadedThumbnail> {
  return await HybridThumbnailRequestLimiter.run(async () => {
    if (asset.localId) {
      try {
        const localThumbnail: HybridLoadedThumbnail = {
          pixelMap: await loadLocalThumbnail(ctx, asset.localId, requestSize),
          remoteSourceKind: Disk.HybridRemoteThumbnailSourceKind.NONE,
          remoteLoadPath: Disk.HybridRemoteThumbnailLoadPath.NONE,
        };
        return localThumbnail;
      } catch (error) {
        if (!asset.thumbnailUrl) {
          throw toError(error);
        }
      }
    }

    if (asset.thumbnailUrl) {
      const remoteResult = await Disk.loadRemoteThumbnail(
        ctx,
        asset.thumbnailUrl,
        requestSize,
        isPrefetch
          ? Disk.HybridRemoteThumbnailLoadKind.PREFETCH
          : Disk.HybridRemoteThumbnailLoadKind.VISIBLE,
      );
      const remoteThumbnail: HybridLoadedThumbnail = {
        pixelMap: remoteResult.pixelMap,
        remoteSourceKind: remoteResult.sourceKind,
        remoteLoadPath: remoteResult.loadPath,
      };
      return remoteThumbnail;
    }

    throw new Error('No thumbnail source available');
  }, isPrefetch, prefetchGeneration, onStart);
}

async function loadThumbnailForVisibleAsset(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): Promise<HybridLoadedThumbnail> {
  return await loadThumbnailForAsset(ctx, asset, requestSize, false);
}

async function loadThumbnailForPrefetchAsset(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
  prefetchGeneration?: number,
  onStart?: () => void,
): Promise<HybridLoadedThumbnail> {
  return await loadThumbnailForAsset(ctx, asset, requestSize, true, prefetchGeneration, onStart);
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
    HybridThumbnailCache.prefetch(buildThumbnailCacheKey(asset.id, requestSize), false, (onStart: () => void) =>
      loadThumbnailForPrefetchAsset(
        ctx,
        asset,
        requestSize,
        HybridThumbnailRequestLimiter.getPrefetchGeneration(),
        onStart,
      )
    );
    return;
  }

  if (asset.thumbnailUrl) {
    if (HybridThumbnailRequestLimiter.isScrollActive()) {
      prefetchAssetThumbnail(ctx, asset, requestSize);
      return;
    }

    HybridRemoteThumbnailWarmup.predownload(ctx, asset, requestSize);
  }
}

export async function loadVisibleAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): Promise<HybridLoadedThumbnail> {
  return await loadThumbnailForVisibleAsset(ctx, asset, requestSize);
}

export function prefetchAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): boolean {
  if (HybridThumbnailRequestLimiter.shouldPausePrefetch()) {
    return false;
  }

  const cacheKey = buildThumbnailCacheKey(asset.id, requestSize);
  return HybridThumbnailCache.prefetch(cacheKey, asset.thumbnailUrl !== undefined, (onStart: () => void) =>
    loadThumbnailForPrefetchAsset(
      ctx,
      asset,
      requestSize,
      HybridThumbnailRequestLimiter.getPrefetchGeneration(),
      onStart,
    )
  );
}

export function prefetchResidentRemoteAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): boolean {
  const remoteUrl = asset.thumbnailUrl;
  void ctx;
  if (!remoteUrl || remoteUrl.length <= 0) {
    return false;
  }

  if (!Disk.hasRemoteThumbnailCompressedData(remoteUrl, requestSize)) {
    return false;
  }

  if (HybridThumbnailRequestLimiter.shouldPauseNearVisiblePrefetch()) {
    return false;
  }

  const cacheKey = buildThumbnailCacheKey(asset.id, requestSize);
  return HybridThumbnailCache.prefetch(cacheKey, true, (onStart: () => void) =>
    loadThumbnailForPrefetchAsset(
      ctx,
      asset,
      requestSize,
      HybridThumbnailRequestLimiter.getPrefetchGeneration(),
      onStart,
    )
  );
}

export function predownloadRemoteAssetThumbnail(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
  exactRequestSize: boolean = false,
): boolean {
  void requestSize;
  if (!asset.thumbnailUrl) {
    return false;
  }
  if (Disk.shouldThrottleRemoteDiskPredownload()) {
    return false;
  }
  const remoteDiskRequestSize = resolveHybridCanonicalRequestSizeBucket();
  if (exactRequestSize
    ? Disk.hasExactRemoteThumbnailCache(ctx, asset.thumbnailUrl, remoteDiskRequestSize, false)
    : Disk.hasRemoteThumbnailCache(ctx, asset.thumbnailUrl, remoteDiskRequestSize, false)) {
    return false;
  }
  void backgroundPredownloadRemoteThumbnail(
    ctx,
    asset.thumbnailUrl,
    remoteDiskRequestSize,
    Disk.HybridRemotePredownloadPriorityHint.NEARBY,
    exactRequestSize,
  );
  return true;
}

export function preloadRemoteAssetThumbnailCompressedData(
  ctx: common.UIAbilityContext,
  asset: HybridPhotoAsset,
  requestSize: number,
): boolean {
  if (
    HybridThumbnailRequestLimiter.isScrollActive() &&
    Disk.getRemoteThumbnailStatsSnapshot().compressedBufferCacheEntryCount >=
      HYBRID_SCROLL_COMPRESSED_BUFFER_PRELOAD_LOW_WATERMARK
  ) {
    return false;
  }
  return HybridRemoteThumbnailBufferWarmup.preload(ctx, asset, requestSize);
}

export function resolveIdleCompressedBufferPreloadTarget(): number {
  return HYBRID_IDLE_COMPRESSED_BUFFER_PRELOAD_TARGET;
}

export function hasRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  return Disk.hasRemoteThumbnailCache(ctx, url, requestSize, allowSyncFs);
}

export function hasRemoteThumbnailCompressedData(
  url: string,
  requestSize: number,
): boolean {
  return Disk.hasRemoteThumbnailCompressedData(url, requestSize);
}

export function hasPersistedRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  return Disk.hasPersistedRemoteThumbnailCache(ctx, url, requestSize, allowSyncFs);
}

export function hasExactRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  return Disk.hasExactRemoteThumbnailCache(ctx, url, requestSize, allowSyncFs);
}

export function hasExactPersistedRemoteThumbnailCache(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  allowSyncFs: boolean = true,
): boolean {
  return Disk.hasExactPersistedRemoteThumbnailCache(ctx, url, requestSize, allowSyncFs);
}

export function primeRemoteThumbnailCacheIndex(ctx: common.UIAbilityContext): void {
  Disk.primeRemoteThumbnailCacheIndex(ctx);
}

export function setPrefetchRuntimeMode(mode: HybridPrefetchRuntimeMode): void {
  setHybridPrefetchRuntimeMode(mode);
}

export function setRuntimeScrollActive(active: boolean): void {
  const previousScrollActive = HybridThumbnailRequestLimiter.isScrollActive();
  if (previousScrollActive !== active) {
    HybridThumbnailPerfStats.flushStage(previousScrollActive, active ? 'scroll-start' : 'scroll-stop');
  }
  HybridThumbnailRequestLimiter.setScrollActive(active);
  Disk.HybridScrollState.isScrolling = active;
  if (!active) {
    HybridThumbnailCache.flushDeferredPrune();
    Disk.flushDeferredThumbnailWritesIfIdle();
    Disk.trimCompressedRemoteThumbnailBufferCache();
  }
}

export async function backgroundPredownloadRemoteThumbnail(
  ctx: common.UIAbilityContext,
  url: string,
  requestSize: number,
  priorityHint: Disk.HybridRemotePredownloadPriorityHint = Disk.HybridRemotePredownloadPriorityHint.NEARBY,
  exactRequestSize: boolean = false,
): Promise<void> {
  await Disk.HybridRemoteThumbnailBackgroundPredownload.predownload(
    ctx,
    url,
    requestSize,
    priorityHint,
    exactRequestSize,
  );
}

export function flushDeferredThumbnailWritesIfIdle(): void {
  Disk.flushDeferredThumbnailWritesIfIdle();
}

export function getRemoteThumbnailStatsSnapshot(): Disk.HybridRemoteThumbnailStatsSnapshot {
  return Disk.getRemoteThumbnailStatsSnapshot();
}

export function trimRemoteThumbnailCacheIfNeeded(
  ctx: common.UIAbilityContext,
  force: boolean = false,
): void {
  Disk.HybridRemoteThumbnailCachePruner.trimIfNeeded(ctx, force);
}

export function shouldThrottleRemoteDiskPredownload(): boolean {
  return Disk.shouldThrottleRemoteDiskPredownload();
}

export function shouldContinueBackgroundPredownload(ctx: common.UIAbilityContext): boolean {
  if (Disk.shouldThrottleRemoteDiskPredownload()) {
    return false;
  }
  return Disk.HybridRemoteThumbnailCacheIndex.totalTrackedBytes(ctx, true) <
    HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES;
}
