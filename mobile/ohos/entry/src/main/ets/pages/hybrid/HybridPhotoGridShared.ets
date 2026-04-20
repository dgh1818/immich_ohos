import { common } from '@kit.AbilityKit';
import { IDataSourcePrefetching } from '@kit.ArkUI';
export const HYBRID_GRID_COLUMNS = 4;
export const HYBRID_GRID_GAP = 0;
export const HYBRID_GRID_MIN_COLUMNS = 3;
export const HYBRID_GRID_MAX_COLUMNS = 16;
export const HYBRID_GRID_MIN_TILE_WIDTH = 96;
export const HYBRID_PAGE_SIZE = 360;
export const HYBRID_REQUEST_SIZE = 180;
export const HYBRID_LIST_CACHE_COUNT = 50;
export const HYBRID_PREFETCH_ROW_THRESHOLD = 32;
export const HYBRID_INITIAL_PREFETCH_ROWS = 16;
export const HYBRID_THUMBNAIL_PREFETCH_ROWS = 32;
export const HYBRID_SCROLL_THUMBNAIL_PREFETCH_ROWS = 48;
export const HYBRID_SECTION_LEAD_LOOKAHEAD = 5;
export const HYBRID_THUMBNAIL_CACHE_LIMIT = 1200;
export const HYBRID_ACTIVE_ROW_KEEP_BEHIND = 12;
export const HYBRID_ACTIVE_ROW_KEEP_AHEAD = 40;
export const HYBRID_MAX_CONCURRENT_THUMBNAIL_REQUESTS = 14;
export const HYBRID_MAX_CONCURRENT_PREFETCH_REQUESTS = 10;
export const HYBRID_MAX_CONCURRENT_REMOTE_WARMUP_DOWNLOADS = 6;
export const HYBRID_MAX_CONCURRENT_NEARBY_REMOTE_PREDOWNLOADS = 3;
export const HYBRID_MAX_CONCURRENT_INITIAL_REMOTE_PREDOWNLOADS = 4;
export const HYBRID_MAX_CONCURRENT_BACKGROUND_PREDOWNLOADS = 3;
export const HYBRID_PREFETCH_CONCURRENCY_NORMAL = 6;
export const HYBRID_PREFETCH_CONCURRENCY_CONSTRAINED = 2;
export const HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE = 360;
export const HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE = 24;
export const HYBRID_INITIAL_REMOTE_PREDOWNLOAD_TARGET = 1000;
export const HYBRID_INITIAL_REMOTE_PREDOWNLOAD_BATCH_SIZE = 24;
export const HYBRID_INITIAL_REMOTE_PREDOWNLOAD_RESUME_DELAY_MS = 120;
export const HYBRID_SMALL_SECTION_WARMUP_ASSET_LIMIT = 8;
export const HYBRID_LARGE_SECTION_WARMUP_ASSET_LIMIT = 12;
export const HYBRID_WINDOW_BEHIND_ROWS = 32;
export const HYBRID_WINDOW_AHEAD_ROWS = 120;
export const HYBRID_WINDOW_MIN_ROWS = 160;
export const HYBRID_WINDOW_SHIFT_THRESHOLD = 16;
export const HYBRID_WINDOW_EMERGENCY_MARGIN = 4;
export const HYBRID_THUMBNAIL_RELEASE_DELAY_MS = 220;
export const HYBRID_LOAD_MORE_THROTTLE_MS = 100;
export const HYBRID_FLOATING_HEADER_HEIGHT = 56;
export const HYBRID_REMOTE_THUMBNAIL_CACHE_DIR = 'thumbnail';
export const HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES = 2 * 1024 * 1024 * 1024;
export const HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES = 1800 * 1024 * 1024;
export const HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_INTERVAL_MS = 10000;
export const HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS = 20;
export const HYBRID_SCROLL_IDLE_DELAY_MS = 240;
export const HYBRID_SCROLL_PREFETCH_INTERVAL_MS = 50;
export const HYBRID_SCROLL_MEMORY_PREFETCH_FORWARD_SCREEN_MULTIPLIER = 5;
export const HYBRID_SCROLL_MEMORY_PREFETCH_BACKWARD_SCREEN_MULTIPLIER = 2;
export const HYBRID_SCROLL_STOP_MEMORY_PREFETCH_SCREEN_MULTIPLIER = 6;
export const HYBRID_SCROLL_MIN_MEMORY_PREFETCH_COUNT = 128;
export const HYBRID_NEARBY_MEMORY_PREDECODE_SCREEN_MULTIPLIER = 5;
export const HYBRID_NEARBY_COMPRESSED_BUFFER_PRELOAD_SCREEN_MULTIPLIER = 9;
export const HYBRID_NEARBY_COMPRESSED_BUFFER_PRELOAD_MAX_COUNT = 512;
export const HYBRID_PREFETCH_READY_RETENTION_MS = 1600;
export const HYBRID_SCROLL_REMOTE_DISK_PREDOWNLOAD_MIN = 32;
export const HYBRID_SCROLL_REMOTE_DISK_PREDOWNLOAD_MAX = 96;
export const HYBRID_DISK_IDLE_DELAY_MS = 900;
export const HYBRID_DEFERRED_REMOTE_WRITE_LIMIT = 2048;
export const HYBRID_DEFERRED_REMOTE_WRITE_MAX_BYTES = 192 * 1024 * 1024;
export const HYBRID_COMPRESSED_BUFFER_CACHE_MAX_BYTES = 200 * 1024 * 1024;
export const HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES = true;
export const HYBRID_VIEWPORT_CACHE_PRUNE_INTERVAL_MS = 180;
export const HYBRID_MIN_RUNWAY_ROWS = 160;
export const HYBRID_RUNWAY_MULTIPLIER = 12;
export const HYBRID_LOAD_MORE_AHEAD_MIN_ROWS = 64;
export const HYBRID_LOAD_MORE_VIEWPORT_MULTIPLIER = 6;
export const HYBRID_KEEP_ABOVE_SCREEN_MULTIPLIER = 4;
export const HYBRID_KEEP_BELOW_SCREEN_MULTIPLIER = 4;
export const HYBRID_SCROLL_FORWARD_PREFETCH_SCREEN_MULTIPLIER = 7;
export const HYBRID_SCROLL_BACKWARD_PREFETCH_SCREEN_MULTIPLIER = 4;
export const HYBRID_SCROLL_STOP_PREFETCH_SCREEN_MULTIPLIER = 8;
export const HYBRID_SCROLL_VISIBLE_THUMBNAIL_LIMIT = 8;
export const HYBRID_SCROLL_PREFETCH_LIMIT = 4;
export const HYBRID_IDLE_PREVIEW_VISIBLE_SCREEN_MULTIPLIER = 1;
export const HYBRID_IDLE_PREVIEW_OVERSCAN_ABOVE_SCREEN_MULTIPLIER = 1.0;
export const HYBRID_IDLE_PREVIEW_OVERSCAN_BELOW_SCREEN_MULTIPLIER = 1.0;

export enum HybridThumbnailLayerRole {
  ACTIVE = 0,
  PREVIEW = 1,
  WARM = 2,
}

export enum HybridPrefetchRuntimeMode {
  NORMAL = 0,
  CONSTRAINED = 1,
}

let hybridPrefetchRuntimeMode: HybridPrefetchRuntimeMode = HybridPrefetchRuntimeMode.NORMAL;

export function setHybridPrefetchRuntimeMode(mode: HybridPrefetchRuntimeMode): void {
  hybridPrefetchRuntimeMode = mode;
}

export function getHybridPrefetchRuntimeMode(): HybridPrefetchRuntimeMode {
  return hybridPrefetchRuntimeMode;
}

export function resolveHybridPrefetchConcurrency(): number {
  return hybridPrefetchRuntimeMode === HybridPrefetchRuntimeMode.CONSTRAINED
    ? HYBRID_PREFETCH_CONCURRENCY_CONSTRAINED
    : HYBRID_PREFETCH_CONCURRENCY_NORMAL;
}

export function resolveScrollMemoryPrefetchBudget(visibleCapacity: number): number {
  const scaledBudget = Math.ceil(
    Math.max(1, visibleCapacity) * HYBRID_SCROLL_MEMORY_PREFETCH_FORWARD_SCREEN_MULTIPLIER,
  );
  return Math.min(
    HYBRID_THUMBNAIL_CACHE_LIMIT,
    Math.max(HYBRID_SCROLL_MIN_MEMORY_PREFETCH_COUNT, scaledBudget),
  );
}

export function resolveNearbyMemoryPredecodeBudget(visibleCapacity: number): number {
  const scaledBudget = Math.ceil(
    Math.max(1, visibleCapacity) * HYBRID_NEARBY_MEMORY_PREDECODE_SCREEN_MULTIPLIER,
  );
  return Math.min(
    HYBRID_THUMBNAIL_CACHE_LIMIT,
    Math.max(HYBRID_SCROLL_MIN_MEMORY_PREFETCH_COUNT, scaledBudget),
  );
}

export function resolveNearbyCompressedBufferPreloadBudget(visibleCapacity: number): number {
  const scaledBudget = Math.ceil(
    Math.max(1, visibleCapacity) * HYBRID_NEARBY_COMPRESSED_BUFFER_PRELOAD_SCREEN_MULTIPLIER,
  );
  return Math.min(
    HYBRID_NEARBY_COMPRESSED_BUFFER_PRELOAD_MAX_COUNT,
    Math.max(resolveNearbyMemoryPredecodeBudget(visibleCapacity), scaledBudget),
  );
}

export function resolveScrollRemoteDiskPredownloadBudget(visibleCapacity: number): number {
  const baseBudget = Math.ceil(Math.max(1, visibleCapacity) * 2);
  return Math.max(
    HYBRID_SCROLL_REMOTE_DISK_PREDOWNLOAD_MIN,
    Math.min(HYBRID_SCROLL_REMOTE_DISK_PREDOWNLOAD_MAX, baseBudget),
  );
}

/**
 * Column-density multiplier for row-based prefetch/runway counts.
 * Dense grids (7-8 cols) get more rows prefetched because each row is cheaper to decode.
 */
export function resolveColumnDensityMultiplier(columns: number): number {
  if (columns >= 7) {
    return 2.0;
  }
  if (columns >= 5) {
    return 1.5;
  }
  return 1.0;
}

/**
 * Adaptive initial prefetch rows scaled by column density.
 */
export function resolveInitialPrefetchRows(columns: number): number {
  return Math.ceil(HYBRID_INITIAL_PREFETCH_ROWS * resolveColumnDensityMultiplier(columns));
}

/**
 * Adaptive incremental prefetch rows scaled by column density.
 */
export function resolveIncrementalPrefetchRows(columns: number): number {
  return Math.ceil(HYBRID_THUMBNAIL_PREFETCH_ROWS * resolveColumnDensityMultiplier(columns));
}

/**
 * Adaptive cache limit: dense grids need more entries because each row has more tiles.
 * Ensures the cache can hold at least the full keep range (above + viewport + below).
 */
export function resolveAdaptiveCacheLimit(columns: number): number {
  const screenRows = columns >= 7 ? 18 : (columns >= 5 ? 12 : 8);
  const keepRows = (HYBRID_KEEP_ABOVE_SCREEN_MULTIPLIER + 1 + HYBRID_KEEP_BELOW_SCREEN_MULTIPLIER) * screenRows;
  const keepTiles = keepRows * columns;
  return Math.max(HYBRID_THUMBNAIL_CACHE_LIMIT, Math.ceil(keepTiles * 1.5));
}

/**
 * Adaptive UI cachedCount: dense grids need more component cache.
 */
export function resolveListCacheCount(columns: number): number {
  if (columns >= 5) {
    return 60;
  }
  return HYBRID_LIST_CACHE_COUNT;
}

const HYBRID_REQUEST_SIZE_BUCKETS: Array<number> = [96, 128, 160, 192, 224];

function resolveFallbackTileWidth(columns: number): number {
  if (columns <= 3) {
    return 224;
  }
  if (columns === 4) {
    return 180;
  }
  if (columns === 5) {
    return 152;
  }
  if (columns === 6) {
    return 128;
  }
  if (columns === 7) {
    return 112;
  }
  return 96;
}

function clampRequestSizeBucket(size: number): number {
  for (let index = 0; index < HYBRID_REQUEST_SIZE_BUCKETS.length; index += 1) {
    const bucket = HYBRID_REQUEST_SIZE_BUCKETS[index];
    if (size <= bucket) {
      return bucket;
    }
  }
  return HYBRID_REQUEST_SIZE_BUCKETS[HYBRID_REQUEST_SIZE_BUCKETS.length - 1];
}

function downgradeRequestSizeBucket(size: number): number {
  const bucket = clampRequestSizeBucket(size);
  const bucketIndex = HYBRID_REQUEST_SIZE_BUCKETS.indexOf(bucket);
  if (bucketIndex <= 0) {
    return HYBRID_REQUEST_SIZE_BUCKETS[0];
  }
  return HYBRID_REQUEST_SIZE_BUCKETS[bucketIndex - 1];
}

export function resolveHybridRequestSizeBucket(
  columns: number,
  listWidth: number,
  layerRole: HybridThumbnailLayerRole,
): number {
  const safeColumns = Math.max(1, columns);
  const safeWidth = Math.max(0, listWidth);
  const totalGap = HYBRID_GRID_GAP * Math.max(0, safeColumns - 1);
  const tileWidth = safeWidth > 0
    ? Math.max(0, (safeWidth - totalGap) / safeColumns)
    : resolveFallbackTileWidth(safeColumns);
  const bufferMultiplier = safeColumns >= 7 ? 1.0 : 1.1;
  let requestedSize = Math.ceil(tileWidth * bufferMultiplier);
  if (requestedSize <= 0) {
    requestedSize = resolveFallbackTileWidth(safeColumns);
  }
  let bucket = clampRequestSizeBucket(requestedSize);
  if (safeColumns >= 8) {
    // 8列: 强制最小 bucket (96px), DMA ≈ 36KB/张
    bucket = HYBRID_REQUEST_SIZE_BUCKETS[0];
  } else if (safeColumns >= 7) {
    bucket = Math.max(HYBRID_REQUEST_SIZE_BUCKETS[0], downgradeRequestSizeBucket(bucket));
  }
  if (layerRole === HybridThumbnailLayerRole.WARM) {
    bucket = Math.max(HYBRID_REQUEST_SIZE_BUCKETS[0], downgradeRequestSizeBucket(bucket));
  }
  return bucket;
}

export function resolveHybridRequestSizeBucketFamily(requestSize: number): Array<number> {
  if (requestSize <= 0) {
    return [];
  }

  const primaryBucket = clampRequestSizeBucket(requestSize);
  let preferredBucket = primaryBucket;
  for (let index = 0; index < HYBRID_REQUEST_SIZE_BUCKETS.length; index += 1) {
    const bucket = HYBRID_REQUEST_SIZE_BUCKETS[index];
    if (bucket <= 224) {
      preferredBucket = bucket;
    }
  }

  const family: Array<number> = [preferredBucket];
  const largerBuckets: Array<number> = [];
  const smallerBuckets: Array<number> = [];
  for (let index = HYBRID_REQUEST_SIZE_BUCKETS.length - 1; index >= 0; index -= 1) {
    const bucket = HYBRID_REQUEST_SIZE_BUCKETS[index];
    if (bucket < preferredBucket) {
      smallerBuckets.push(bucket);
    }
  }
  for (let index = 0; index < HYBRID_REQUEST_SIZE_BUCKETS.length; index += 1) {
    const bucket = HYBRID_REQUEST_SIZE_BUCKETS[index];
    if (bucket > preferredBucket) {
      largerBuckets.push(bucket);
    }
  }

  const alternateCount = Math.max(largerBuckets.length, smallerBuckets.length);
  for (let index = 0; index < alternateCount; index += 1) {
    if (index < largerBuckets.length) {
      family.push(largerBuckets[index]);
    }
    if (index < smallerBuckets.length) {
      family.push(smallerBuckets[index]);
    }
  }
  return family;
}

export function resolveHybridCanonicalRequestSizeBucket(): number {
  return HYBRID_REQUEST_SIZE_BUCKETS[HYBRID_REQUEST_SIZE_BUCKETS.length - 1];
}

export interface HybridPhotoAsset {
  id: string;
  localId?: string;
  remoteId?: string;
  storage?: string;
  thumbnailUrl?: string;
  thumbHash?: string;
  createdAt?: string;
  isVideo: boolean;
  durationInSeconds: number;
  width?: number;
  height?: number;
  isFavorite?: boolean;
}

export interface HybridPhotoSection {
  key: string;
  title: string;
  rows: Array<Array<HybridPhotoAsset>>;
}

export interface HybridBucketInfo {
  date: string;
  count: number;
  offset: number;
}

export interface HybridGroupInfo {
  key: string;
  title: string;
  count: number;
  offset: number;
}

export interface HybridPhotoPageResult {
  ready: boolean;
  offset: number;
  hasMore: boolean;
  nextOffset: number;
  windowStartOffset: number;
  windowEndOffset: number;
  sections: Array<HybridPhotoSection>;
  groupDayGroups: Array<HybridGroupInfo>;
  yearBuckets: Array<HybridBucketInfo>;
  monthBuckets: Array<HybridBucketInfo>;
  reason?: string;
}

export interface HybridTimelineItem {
  layoutId: number;
  key: string;
  kind: string;
  spacerHeight?: number;
  title?: string;
  count: number;
  sectionKey: string;
  sectionTitle: string;
  sectionCount: number;
  assets: Array<HybridPhotoAsset>;
  isFirstInSection: boolean;
}

// Grid 数据结构：每个 GridItem 是单张照片或标题头
export interface HybridGridItem {
  id: string;
  kind: 'photo' | 'header' | 'spacer' | 'tail' | 'placeholder' | 'groupHeader';
  sourceIndex?: number;
  headerText?: string;
  headerCount?: number;
  spacerHeight?: number;
  asset?: HybridPhotoAsset;
  sectionKey: string;
}

export interface HybridThumbnailCacheEntry {
  pixelMap?: PixelMap;
  loadingPromise?: Promise<PixelMap>;
  loadingIsPrefetch?: boolean;
  loadingToken?: number;
  refCount: number;
  lastUsedAt: number;
  retainUntilAt?: number;
}

export interface HybridRemoteCacheEntry {
  downloadingPromise?: Promise<void>;
}

export interface HybridDeferredRemoteWriteEntry {
  ctx: common.UIAbilityContext;
  url: string;
  requestSize: number;
  data: ArrayBuffer;
  dataByteLength: number;
}

export interface HybridTimelineAssetEntry {
  asset: HybridPhotoAsset;
  sectionKey: string;
  sectionTitle: string;
  sectionCount: number;
  isSectionLead: boolean;
}

export interface HybridSectionMergeResult {
  sections: Array<HybridPhotoSection>;
  appendedEntries: Array<HybridTimelineAssetEntry>;
}

export interface HybridTimelineTailUpdate {
  startIndex: number;
  items: Array<HybridTimelineItem>;
}

export interface HybridGridPrefetchRequest {
  index: number;
  item?: HybridGridItem;
  visibleStart: number;
  visibleEnd: number;
  isCanceled: () => boolean;
}

export interface HybridGridPrefetchHandler {
  prefetch(request: HybridGridPrefetchRequest): Promise<void>;
  cancel(index: number, item?: HybridGridItem): void;
}

export class HybridTimelineDataSource implements IDataSource {
  private items: Array<HybridTimelineItem> = [];
  private listeners: Array<DataChangeListener> = [];

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): HybridTimelineItem {
    return this.items[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) >= 0) {
      return;
    }
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener);
  }

  replaceAll(items: Array<HybridTimelineItem>): void {
    this.items = items.slice();
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }

  reconcile(items: Array<HybridTimelineItem>): void {
    const nextItems = items.slice();
    const minLength = Math.min(this.items.length, nextItems.length);
    const previousItems = this.items.slice();
    this.items = nextItems;

    for (let index = 0; index < minLength; index += 1) {
      if (!isSameTimelineItem(previousItems[index], nextItems[index])) {
        this.notifyDataChange(index);
      }
    }

    if (previousItems.length > nextItems.length) {
      for (let index = previousItems.length - 1; index >= nextItems.length; index -= 1) {
        this.notifyDataDelete(index);
      }
      return;
    }

    for (let index = previousItems.length; index < nextItems.length; index += 1) {
      this.notifyDataAdd(index);
    }
  }

  updateTail(startIndex: number, tailItems: Array<HybridTimelineItem>): void {
    const safeStart = Math.max(0, Math.min(startIndex, this.items.length));
    const previousLength = this.items.length;
    const previousTail = this.items.slice(safeStart);
    this.items.splice(safeStart, previousLength - safeStart, ...tailItems);

    const overlapCount = Math.min(previousTail.length, tailItems.length);
    for (let index = 0; index < overlapCount; index += 1) {
      const absoluteIndex = safeStart + index;
      if (!isSameTimelineItem(previousTail[index], tailItems[index])) {
        this.notifyDataChange(absoluteIndex);
      }
    }

    if (previousLength > this.items.length) {
      for (let index = previousLength - 1; index >= this.items.length; index -= 1) {
        this.notifyDataDelete(index);
      }
      return;
    }

    for (let index = previousLength; index < this.items.length; index += 1) {
      this.notifyDataAdd(index);
    }
  }

  private notifyDataAdd(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(index);
    });
  }

  private notifyDataDelete(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(index);
    });
  }

  private notifyDataChange(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index);
    });
  }
}

export function isSameTimelineItem(left: HybridTimelineItem, right: HybridTimelineItem): boolean {
  if (left.layoutId !== right.layoutId
    || left.key !== right.key
    || left.kind !== right.kind
    || left.title !== right.title
    || left.count !== right.count
    || left.sectionKey !== right.sectionKey
    || left.sectionTitle !== right.sectionTitle
    || left.sectionCount !== right.sectionCount
    || left.isFirstInSection !== right.isFirstInSection
    || left.assets.length !== right.assets.length) {
    return false;
  }

  for (let index = 0; index < left.assets.length; index += 1) {
    if (left.assets[index].id !== right.assets[index].id) {
      return false;
    }
  }

  return true;
}
export function delay(ms: number): Promise<void> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(), ms);
  });
}

// Grid DataSource：管理扁平化的照片列表
// 对齐参考程序 DayDataView 的 IDataSource + DataChangeListener 模式
export class HybridGridDataSource implements IDataSource, IDataSourcePrefetching {
  private items: Array<HybridGridItem> = [];
  listeners: Array<DataChangeListener> = [];
  private prefetchHandler?: HybridGridPrefetchHandler = undefined;
  private prefetchVisibleStart: number = 0;
  private prefetchVisibleEnd: number = -1;
  private readonly prefetchTokens: Map<number, number> = new Map();

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): HybridGridItem {
    return this.items[index];
  }

  getItemsSnapshot(): Array<HybridGridItem> {
    return this.items.slice();
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) >= 0) {
      return;
    }
    this.listeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((item: DataChangeListener) => item !== listener);
  }

  setPrefetchHandler(handler?: HybridGridPrefetchHandler): void {
    this.prefetchHandler = handler;
  }

  updatePrefetchViewport(start: number, end: number): void {
    this.prefetchVisibleStart = Math.max(0, start);
    this.prefetchVisibleEnd = Math.max(this.prefetchVisibleStart, end);
  }

  async prefetch(index: number): Promise<void> {
    const handler = this.prefetchHandler;
    if (!handler) {
      return;
    }

    const nextToken = (this.prefetchTokens.get(index) ?? 0) + 1;
    this.prefetchTokens.set(index, nextToken);
    const currentItem = this.items[index];
    const visibleStart = this.prefetchVisibleStart;
    const visibleEnd = this.prefetchVisibleEnd;
    const request: HybridGridPrefetchRequest = {
      index: index,
      item: currentItem,
      visibleStart: visibleStart,
      visibleEnd: visibleEnd,
      isCanceled: (): boolean => {
        return (this.prefetchTokens.get(index) ?? 0) !== nextToken;
      },
    };

    try {
      await handler.prefetch(request);
    } catch (_) {}
  }

  cancel(index: number): void {
    const nextToken = (this.prefetchTokens.get(index) ?? 0) + 1;
    this.prefetchTokens.set(index, nextToken);
    this.prefetchHandler?.cancel(index, this.items[index]);
  }

  /**
   * 更新数据项（不触发通知，由调用方决定何时 onDataReloaded）
   */
  updateData(items: Array<HybridGridItem>): void {
    this.items = items.slice();
  }

  /**
   * 更新数据项并通知重新加载（对齐参考程序 DayDataView 模式）
   * 仅在数据实际变化时触发 onDataReloaded
   */
  updateDataIfChanged(items: Array<HybridGridItem>): boolean {
    if (this.hasSameItems(items)) {
      return false;
    }
    this.items = items.slice();
    this.onDataReloaded();
    return true;
  }

  reconcile(items: Array<HybridGridItem>): boolean {
    if (this.hasSameItems(items)) {
      return false;
    }

    const previousItems = this.items.slice();
    const nextItems = items.slice();
    if (!this.canIncrementallyReconcile(previousItems, nextItems)) {
      this.items = nextItems;
      this.onDataReloaded();
      return true;
    }

    const minLength = Math.min(previousItems.length, nextItems.length);
    this.items = nextItems;

    for (let index = 0; index < minLength; index += 1) {
      if (!this.isSameItem(previousItems[index], nextItems[index])) {
        this.onDataChange(index);
      }
    }

    if (previousItems.length > nextItems.length) {
      for (let index = previousItems.length - 1; index >= nextItems.length; index -= 1) {
        this.onDataDelete(index);
      }
      return true;
    }

    for (let index = previousItems.length; index < nextItems.length; index += 1) {
      this.onDataAdd(index);
    }
    return true;
  }

  private canIncrementallyReconcile(
    previousItems: Array<HybridGridItem>,
    nextItems: Array<HybridGridItem>,
  ): boolean {
    const minLength = Math.min(previousItems.length, nextItems.length);
    for (let index = 0; index < minLength; index += 1) {
      if (!this.isSameItem(previousItems[index], nextItems[index])) {
        return false;
      }
    }
    return true;
  }

  /**
   * 通知数据重新加载（对齐参考程序 DayDataView.onDataReloaded）
   */
  onDataReloaded(): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }

  /**
   * 数据添加（对齐参考程序 DayDataView.onDataAdd）
   */
  onDataAdd(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataAdd(index);
    });
  }

  /**
   * 数据变化（对齐参考程序 DayDataView.onDataChange）
   */
  onDataChange(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataChange(index);
    });
  }

  /**
   * 数据删除（对齐参考程序 DayDataView.onDataDelete）
   */
  onDataDelete(index: number): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataDelete(index);
    });
  }

  private hasSameItems(items: Array<HybridGridItem>): boolean {
    if (this.items.length !== items.length) {
      return false;
    }
    for (let index = 0; index < items.length; index += 1) {
      if (!this.isSameItem(this.items[index], items[index])) {
        return false;
      }
    }
    return true;
  }

  private isSameItem(left: HybridGridItem, right: HybridGridItem): boolean {
    return left.id === right.id && left.kind === right.kind && left.sectionKey === right.sectionKey;
  }
}
