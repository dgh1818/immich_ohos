import { common } from '@kit.AbilityKit';
export const HYBRID_GRID_COLUMNS = 4;
export const HYBRID_GRID_GAP = 0;
export const HYBRID_GRID_MIN_COLUMNS = 3;
export const HYBRID_GRID_MAX_COLUMNS = 8;
export const HYBRID_GRID_MIN_TILE_WIDTH = 96;
export const HYBRID_PAGE_SIZE = 120;
export const HYBRID_REQUEST_SIZE = 180;
export const HYBRID_LIST_CACHE_COUNT = 8;
export const HYBRID_PREFETCH_ROW_THRESHOLD = 32;
export const HYBRID_INITIAL_PREFETCH_ROWS = 8;
export const HYBRID_THUMBNAIL_PREFETCH_ROWS = 16;
export const HYBRID_SCROLL_THUMBNAIL_PREFETCH_ROWS = 32;
export const HYBRID_SECTION_LEAD_LOOKAHEAD = 3;
export const HYBRID_THUMBNAIL_CACHE_LIMIT = 160;
export const HYBRID_ACTIVE_ROW_KEEP_BEHIND = 12;
export const HYBRID_ACTIVE_ROW_KEEP_AHEAD = 40;
export const HYBRID_MAX_CONCURRENT_THUMBNAIL_REQUESTS = 6;
export const HYBRID_MAX_CONCURRENT_PREFETCH_REQUESTS = 4;
export const HYBRID_MAX_CONCURRENT_REMOTE_WARMUP_DOWNLOADS = 2;
export const HYBRID_MAX_CONCURRENT_BACKGROUND_PREDOWNLOADS = 1;
export const HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE = 180;
export const HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE = 12;
export const HYBRID_SMALL_SECTION_WARMUP_ASSET_LIMIT = 8;
export const HYBRID_LARGE_SECTION_WARMUP_ASSET_LIMIT = 12;
export const HYBRID_WINDOW_BEHIND_ROWS = 32;
export const HYBRID_WINDOW_AHEAD_ROWS = 80;
export const HYBRID_WINDOW_MIN_ROWS = 112;
export const HYBRID_WINDOW_SHIFT_THRESHOLD = 16;
export const HYBRID_WINDOW_EMERGENCY_MARGIN = 4;
export const HYBRID_THUMBNAIL_RELEASE_DELAY_MS = 220;
export const HYBRID_LOAD_MORE_THROTTLE_MS = 220;
export const HYBRID_FLOATING_HEADER_HEIGHT = 56;
export const HYBRID_REMOTE_THUMBNAIL_CACHE_DIR = 'hybrid_photos';
export const HYBRID_REMOTE_THUMBNAIL_CACHE_MAX_BYTES = 2 * 1024 * 1024 * 1024;
export const HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES = 1800 * 1024 * 1024;
export const HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_INTERVAL_MS = 10000;
export const HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS = 80;
export const HYBRID_SCROLL_IDLE_DELAY_MS = 240;
export const HYBRID_SCROLL_PREFETCH_INTERVAL_MS = 90;
export const HYBRID_DISK_IDLE_DELAY_MS = 900;
export const HYBRID_DEFERRED_REMOTE_WRITE_LIMIT = 24;
export const HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES = true;
export const HYBRID_VIEWPORT_CACHE_PRUNE_INTERVAL_MS = 180;
export const HYBRID_MIN_RUNWAY_ROWS = 64;
export const HYBRID_RUNWAY_MULTIPLIER = 8;
export const HYBRID_LOAD_MORE_AHEAD_MIN_ROWS = 32;
export const HYBRID_LOAD_MORE_VIEWPORT_MULTIPLIER = 4;

export enum HybridThumbnailLayerRole {
  ACTIVE = 0,
  PREVIEW = 1,
  WARM = 2,
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
  let requestedSize = Math.ceil(tileWidth * 1.1);
  if (requestedSize <= 0) {
    requestedSize = resolveFallbackTileWidth(safeColumns);
  }
  let bucket = clampRequestSizeBucket(requestedSize);
  if (layerRole === HybridThumbnailLayerRole.WARM) {
    bucket = Math.max(HYBRID_REQUEST_SIZE_BUCKETS[0], downgradeRequestSizeBucket(bucket));
  }
  return bucket;
}

export interface HybridPhotoAsset {
  id: string;
  localId?: string;
  remoteId?: string;
  storage?: string;
  thumbnailUrl?: string;
  thumbHash?: string;
  isVideo: boolean;
  durationInSeconds: number;
}

export interface HybridPhotoSection {
  key: string;
  title: string;
  rows: Array<Array<HybridPhotoAsset>>;
}

export interface HybridPhotoPageResult {
  ready: boolean;
  hasMore: boolean;
  nextOffset: number;
  sections: Array<HybridPhotoSection>;
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
  kind: 'photo' | 'header' | 'spacer' | 'tail' | 'placeholder';
  sourceIndex?: number;
  asset?: HybridPhotoAsset;  // 照片项
  headerText?: string;       // 标题头文本
  headerCount?: number;      // 标题头数量
  spacerHeight?: number;     // 占位高度
  sectionKey: string;        // 所属 section
}

export interface HybridThumbnailCacheEntry {
  pixelMap?: PixelMap;
  loadingPromise?: Promise<PixelMap>;
  refCount: number;
  lastUsedAt: number;
}

export interface HybridRemoteCacheEntry {
  downloadingPromise?: Promise<void>;
}

export interface HybridDeferredRemoteWriteEntry {
  ctx: common.UIAbilityContext;
  url: string;
  requestSize: number;
  data: ArrayBuffer;
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
export class HybridGridDataSource implements IDataSource {
  private items: Array<HybridGridItem> = [];
  private listeners: Array<DataChangeListener> = [];

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

  // 更新所有数据（用于列数变化时）
  updateAll(items: Array<HybridGridItem>): void {
    this.items = items.slice();
    this.notifyDataReloaded();
  }

  updateAllIfChanged(items: Array<HybridGridItem>): boolean {
    if (this.hasSameItems(items)) {
      return false;
    }
    this.items = items.slice();
    this.notifyDataReloaded();
    return true;
  }

  private hasSameItems(items: Array<HybridGridItem>): boolean {
    if (this.items.length !== items.length) {
      return false;
    }
    for (let index = 0; index < items.length; index += 1) {
      const current = this.items[index];
      const next = items[index];
      if (
        current.id !== next.id ||
        current.kind !== next.kind ||
        current.sectionKey !== next.sectionKey
      ) {
        return false;
      }
    }
    return true;
  }

  private notifyDataReloaded(): void {
    this.listeners.forEach((listener: DataChangeListener) => {
      listener.onDataReloaded();
    });
  }
}
