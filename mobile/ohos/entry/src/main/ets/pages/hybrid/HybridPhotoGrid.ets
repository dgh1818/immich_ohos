import { common } from '@kit.AbilityKit';
import { HybridFlutterBridge } from '../../bridge/HybridFlutterBridge';
import * as Shared from './HybridPhotoGridShared';
import * as Thumbnail from './HybridPhotoThumbnail';
import * as ThumbnailDisk from './HybridPhotoThumbnailDisk';
import { HybridPhotoTile } from './HybridPhotoTile';
import { HybridPhotoTimelineBuilder } from './HybridPhotoTimeline';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridTimelineItem = Shared.HybridTimelineItem;

@Component
export struct HybridPhotoGrid {
  private context = getContext(this) as common.UIAbilityContext;
  @Prop topInset: number = 56;

  @State sections: Array<HybridPhotoSection> = [];
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State nextOffset: number = 0;
  @State errorText: string = '';
  @State floatingSectionTitle: string = '';
  @State floatingSectionCount: number = 0;
  @State listWidth: number = 0;

  private readonly pageSize: number = Shared.HYBRID_PAGE_SIZE;
  private readonly scroller: Scroller = new Scroller();
  private readonly timelineDataSource: Shared.HybridTimelineDataSource = new Shared.HybridTimelineDataSource();
  private readonly timelineBuilder: HybridPhotoTimelineBuilder = new HybridPhotoTimelineBuilder();
  private allTimelineItems: Array<HybridTimelineItem> = [];
  private prefetchCursor: number = -1;
  private lastLoadMoreTriggerAt: number = 0;
  private backgroundPredownloadToken: number = 0;
  private backgroundPredownloadRunning: boolean = false;
  private idleWorkToken: number = 0;
  private pendingWarmupSections: Array<HybridPhotoSection> = [];
  private lastVisibleStart: number = 0;
  private lastVisibleEnd: number = 0;
  private lastScrollPrefetchAt: number = 0;
  private lastForwardPrefetchEnd: number = -1;
  private lastBackwardPrefetchStart: number = Number.MAX_SAFE_INTEGER;
  private lastViewportPruneAt: number = 0;
  private windowStartIndex: number = 0;
  private windowEndIndex: number = -1;
  private pendingWindowShiftStart: number = -1;
  private pendingWindowShiftEnd: number = -1;

  aboutToAppear() {
    this.reload();
  }

  aboutToDisappear() {
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    this.backgroundPredownloadToken += 1;
    this.backgroundPredownloadRunning = false;
    this.idleWorkToken += 1;
  }

  private async reload(): Promise<void> {
    this.backgroundPredownloadToken += 1;
    this.backgroundPredownloadRunning = false;
    this.sections = [];
    this.allTimelineItems = [];
    this.timelineDataSource.replaceAll([]);
    this.nextOffset = 0;
    this.hasMore = true;
    this.errorText = '';
    this.isLoading = true;
    this.prefetchCursor = -1;
    this.lastLoadMoreTriggerAt = 0;
    this.floatingSectionTitle = '';
    this.floatingSectionCount = 0;
    this.pendingWarmupSections = [];
    this.timelineBuilder.resetLayoutIds();
    this.windowStartIndex = 0;
    this.windowEndIndex = -1;
    this.pendingWindowShiftStart = -1;
    this.pendingWindowShiftEnd = -1;
    this.lastVisibleStart = 0;
    this.lastVisibleEnd = 0;
    this.lastViewportPruneAt = 0;
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    this.idleWorkToken += 1;

    try {
      await this.loadPage(true);
    } finally {
      this.isLoading = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (!this.hasMore || this.isLoading || this.isLoadingMore) {
      return;
    }

    this.isLoadingMore = true;
    try {
      await this.loadPage(false);
    } finally {
      this.isLoadingMore = false;
    }
  }

  private async loadPage(reset: boolean): Promise<void> {
    try {
      const payload = await HybridFlutterBridge.fetchPhotoPage(reset ? 0 : this.nextOffset, this.pageSize);
      const page = this.timelineBuilder.parsePageResult(payload);

      if (!page.ready) {
        this.errorText = page.reason ?? 'Hybrid photo data is unavailable';
        this.hasMore = false;
        return;
      }

      this.errorText = '';
      this.nextOffset = page.nextOffset;
      this.hasMore = page.hasMore;
      const previousItemCount = this.allTimelineItems.length;

      if (reset || previousItemCount === 0) {
        const mergedSections = this.timelineBuilder.mergeSections([], page.sections).sections;
        this.sections = this.timelineBuilder.retainSectionsForMerge(mergedSections);
        const timelineItems = this.timelineBuilder.buildTimelineItems(mergedSections);
        this.allTimelineItems = timelineItems;
        this.windowStartIndex = 0;
        this.windowEndIndex = Math.max(0, timelineItems.length - 1);
        this.timelineDataSource.replaceAll(timelineItems);
        if (timelineItems.length > 0 && !this.floatingSectionTitle) {
          this.applyFloatingSection(timelineItems[0]);
        }
        if (timelineItems.length > 0) {
          const initialRows = reset ? Shared.HYBRID_INITIAL_PREFETCH_ROWS : Shared.HYBRID_THUMBNAIL_PREFETCH_ROWS;
          this.prefetchTimelineRows(0, Math.min(timelineItems.length - 1, initialRows));
        }
        this.pruneThumbnailCacheAroundViewport(0, Math.min(timelineItems.length - 1, Shared.HYBRID_INITIAL_PREFETCH_ROWS), true);
      } else {
        const mergeResult = this.timelineBuilder.mergeSections(this.sections, page.sections);
        this.sections = this.timelineBuilder.retainSectionsForMerge(mergeResult.sections);
        if (mergeResult.appendedEntries.length > 0) {
          const lastItem = this.allTimelineItems[previousItemCount - 1];
          const tailUpdate = this.timelineBuilder.buildAppendTail(lastItem, previousItemCount, mergeResult.appendedEntries);
          this.allTimelineItems.splice(
            tailUpdate.startIndex,
            this.allTimelineItems.length - tailUpdate.startIndex,
            ...tailUpdate.items,
          );
          this.windowStartIndex = 0;
          this.windowEndIndex = Math.max(0, this.allTimelineItems.length - 1);
          this.timelineDataSource.updateTail(tailUpdate.startIndex, tailUpdate.items);
          const totalCount = this.allTimelineItems.length;
          if (totalCount > 0) {
            const prefetchStart = Math.max(0, tailUpdate.startIndex - 1);
            const prefetchEnd = Math.min(totalCount - 1, prefetchStart + Shared.HYBRID_THUMBNAIL_PREFETCH_ROWS);
            this.prefetchTimelineRows(prefetchStart, prefetchEnd);
          }
          this.pruneThumbnailCacheAroundViewport(this.lastVisibleStart, this.lastVisibleEnd, true);
        }
      }
      if (!reset && Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
        if (ThumbnailDisk.HybridScrollState.isScrolling) {
          this.pendingWarmupSections = page.sections.slice();
          this.scheduleIdleWork();
        } else {
          void this.predownloadSections(page.sections, false);
          this.startBackgroundPredownload();
        }
      }

      if (!this.hasMore) {
        this.prefetchCursor = -1;
      }
    } catch (error) {
      this.errorText = `${error}`;
      this.hasMore = false;
    }
  }

  private shouldContinueBackgroundPredownload(): boolean {
    return ThumbnailDisk.HybridRemoteThumbnailCacheIndex.totalTrackedBytes(this.context, true)
      < Shared.HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES;
  }

  private async predownloadSections(
    sections: Array<HybridPhotoSection>,
    includeAllAssets: boolean,
  ): Promise<void> {
    if (sections.length === 0) {
      return;
    }

    const assets = this.timelineBuilder.collectPredownloadAssets(sections, includeAllAssets);
    for (let index = 0; index < assets.length; index += Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE) {
      const batch = assets.slice(index, index + Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE);
      await Promise.all(
        batch.map((asset: HybridPhotoAsset) =>
          ThumbnailDisk.HybridRemoteThumbnailBackgroundPredownload.predownload(
            this.context,
            asset.thumbnailUrl as string,
            Shared.HYBRID_REQUEST_SIZE,
          )
        ),
      );
      await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
    }
  }

  private startBackgroundPredownload(): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return;
    }

    if (ThumbnailDisk.HybridScrollState.isScrolling || this.backgroundPredownloadRunning || !this.shouldContinueBackgroundPredownload()) {
      return;
    }

    const token = this.backgroundPredownloadToken;
    const startOffset = this.nextOffset;
    this.backgroundPredownloadRunning = true;
    void this.runBackgroundPredownload(token, startOffset).finally(() => {
      if (token === this.backgroundPredownloadToken) {
        this.backgroundPredownloadRunning = false;
      }
    });
  }

  private async runBackgroundPredownload(token: number, startOffset: number): Promise<void> {
    let offset = startOffset;

    while (token === this.backgroundPredownloadToken && this.shouldContinueBackgroundPredownload()) {
      try {
        const payload = await HybridFlutterBridge.fetchPhotoPage(offset, Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE);
        const page = this.timelineBuilder.parsePageResult(payload);
        if (!page.ready || page.sections.length === 0) {
          break;
        }

        await this.predownloadSections(page.sections, true);

        if (!page.hasMore || page.nextOffset <= offset) {
          break;
        }

        offset = page.nextOffset;
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
      } catch (_) {
        break;
      }
    }
  }

  private maybePrefetch(endIndex: number): void {
    if (!this.hasMore || this.isLoading || this.isLoadingMore) {
      return;
    }

    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      return;
    }

    if (totalCount - endIndex > Shared.HYBRID_PREFETCH_ROW_THRESHOLD) {
      return;
    }

    if (this.prefetchCursor === this.nextOffset) {
      return;
    }

    this.triggerLoadMore();
  }

  private triggerLoadMore(): void {
    if (!this.hasMore || this.isLoading || this.isLoadingMore) {
      return;
    }

    if (this.prefetchCursor === this.nextOffset) {
      return;
    }

    const now = Date.now();
    if (now - this.lastLoadMoreTriggerAt < Shared.HYBRID_LOAD_MORE_THROTTLE_MS) {
      return;
    }

    this.lastLoadMoreTriggerAt = now;
    this.prefetchCursor = this.nextOffset;
    this.loadMore();
  }

  private applyFloatingSection(item: HybridTimelineItem): void {
    this.floatingSectionTitle = item.sectionTitle;
    this.floatingSectionCount = item.sectionCount;
  }

  private resolveSectionCount(item: HybridTimelineItem): number {
    const section = this.sections.find((candidate: HybridPhotoSection) => {
      if (candidate.key && item.sectionKey && candidate.key === item.sectionKey) {
        return true;
      }

      if (candidate.title && item.sectionTitle && candidate.title === item.sectionTitle) {
        return true;
      }

      return false;
    });

    if (!section) {
      return item.sectionCount;
    }

    return this.timelineBuilder.sectionAssetCount(section);
  }

  private updateFloatingSection(startIndex: number): void {
    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      return;
    }

    const safeIndex = Math.max(0, Math.min(startIndex, totalCount - 1));
    this.applyFloatingSection(this.allTimelineItems[safeIndex]);
  }

  private prefetchTimelineRows(startIndex: number, endIndex: number): void {
    this.prefetchTimelineRowsInternal(startIndex, endIndex, false);
  }

  private prefetchTimelineRowsInternal(
    startIndex: number,
    endIndex: number,
    allowWhileScrolling: boolean,
  ): void {
    if (ThumbnailDisk.HybridScrollState.isScrolling && !allowWhileScrolling) {
      return;
    }

    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      return;
    }

    const safeStart = Math.max(0, startIndex);
    const safeEnd = Math.min(endIndex, totalCount - 1);
    for (let index = safeStart; index <= safeEnd; index += 1) {
      const item = this.allTimelineItems[index];
      this.prefetchTimelineItem(item);
    }
  }

  private prefetchAheadWhileScrolling(
    previousStart: number,
    previousEnd: number,
    startIndex: number,
    endIndex: number,
  ): void {
    if (!ThumbnailDisk.HybridScrollState.isScrolling) {
      return;
    }

    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      return;
    }

    const now = Date.now();
    if (now - this.lastScrollPrefetchAt < Shared.HYBRID_SCROLL_PREFETCH_INTERVAL_MS) {
      return;
    }
    this.lastScrollPrefetchAt = now;

    if (endIndex >= previousEnd) {
      const targetStart = Math.max(0, endIndex + 1);
      const targetEnd = Math.min(totalCount - 1, endIndex + Shared.HYBRID_SCROLL_THUMBNAIL_PREFETCH_ROWS);
      if (targetStart <= targetEnd && targetEnd > this.lastForwardPrefetchEnd) {
        this.prefetchTimelineRowsInternal(targetStart, targetEnd, true);
        this.lastForwardPrefetchEnd = targetEnd;
      }
      return;
    }

    if (startIndex < previousStart) {
      const targetStart = Math.max(0, startIndex - Shared.HYBRID_INITIAL_PREFETCH_ROWS);
      const targetEnd = Math.max(targetStart, startIndex - 1);
      if (targetStart <= targetEnd && targetStart < this.lastBackwardPrefetchStart) {
        this.prefetchTimelineRowsInternal(targetStart, targetEnd, true);
        this.lastBackwardPrefetchStart = targetStart;
      }
    }
  }

  private prefetchTimelineItem(item: HybridTimelineItem): void {
    item.assets.forEach((asset) => {
      Thumbnail.prefetchAssetThumbnail(this.context, asset, Shared.HYBRID_REQUEST_SIZE);
    });
  }

  private pruneThumbnailCacheAroundViewport(startIndex: number, endIndex: number, force: boolean = false): void {
    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      return;
    }

    const now = Date.now();
    if (!force && now - this.lastViewportPruneAt < Shared.HYBRID_VIEWPORT_CACHE_PRUNE_INTERVAL_MS) {
      return;
    }
    this.lastViewportPruneAt = now;

    const keepStart = Math.max(0, startIndex - Shared.HYBRID_ACTIVE_ROW_KEEP_BEHIND);
    const keepEnd = Math.min(totalCount - 1, endIndex + Shared.HYBRID_ACTIVE_ROW_KEEP_AHEAD);
    const keepKeys: Set<string> = new Set();
    for (let index = keepStart; index <= keepEnd; index += 1) {
      const item = this.allTimelineItems[index];
      item.assets.forEach((asset: HybridPhotoAsset) => {
        if (asset.id) {
          keepKeys.add(asset.id);
        }
      });
    }

    Thumbnail.HybridThumbnailCache.pruneOutsideKeys(keepKeys);
  }

  private onScrollStart(): void {
    ThumbnailDisk.HybridScrollState.isScrolling = true;
    this.idleWorkToken += 1;
    this.lastScrollPrefetchAt = 0;
    this.lastForwardPrefetchEnd = this.lastVisibleEnd;
    this.lastBackwardPrefetchStart = this.lastVisibleStart;
  }

  private onScrollStop(): void {
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    this.pendingWindowShiftStart = -1;
    this.pendingWindowShiftEnd = -1;
    this.pruneThumbnailCacheAroundViewport(this.lastVisibleStart, this.lastVisibleEnd, true);
    this.prefetchTimelineRows(this.lastVisibleStart, this.lastVisibleEnd + Shared.HYBRID_THUMBNAIL_PREFETCH_ROWS);
    this.scheduleIdleWork();
  }

  private getBaseTopInsetHeight(): number {
    return this.topInset + Shared.HYBRID_FLOATING_HEADER_HEIGHT + 12;
  }

  private getTimelineRowHeight(): number {
    if (this.listWidth <= 0) {
      return 0;
    }
    return this.listWidth / Shared.HYBRID_GRID_COLUMNS;
  }

  private createSpacerItem(key: string, height: number): HybridTimelineItem {
    return {
      layoutId: key === 'top_spacer' ? -1 : -2,
      key: key,
      kind: 'spacer',
      spacerHeight: Math.max(0, height),
      count: 0,
      sectionKey: '',
      sectionTitle: '',
      sectionCount: 0,
      assets: [],
      isFirstInSection: false,
    };
  }

  private rebuildTimelineWindow(anchorStart: number, anchorEnd: number, force: boolean = false): void {
    const totalCount = this.allTimelineItems.length;
    this.windowStartIndex = 0;
    this.windowEndIndex = totalCount > 0 ? totalCount - 1 : -1;
    this.timelineDataSource.replaceAll(this.allTimelineItems.slice());
  }

  private windowIndexToTimelineIndex(index: number): number {
    if (this.allTimelineItems.length <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(index, this.allTimelineItems.length - 1));
  }

  private maybeShiftTimelineWindow(startIndex: number, endIndex: number): void {
    return;
  }

  private scheduleIdleWork(): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return;
    }

    const token = ++this.idleWorkToken;
    setTimeout(() => {
      if (token !== this.idleWorkToken || ThumbnailDisk.HybridScrollState.isScrolling) {
        return;
      }

      const pendingSections = this.pendingWarmupSections.splice(0, this.pendingWarmupSections.length);
      if (pendingSections.length > 0) {
        void this.predownloadSections(pendingSections, false);
      }
      ThumbnailDisk.flushDeferredThumbnailWritesIfIdle();
      ThumbnailDisk.HybridRemoteThumbnailCachePruner.trimIfNeeded(this.context);
      this.startBackgroundPredownload();
    }, Shared.HYBRID_DISK_IDLE_DELAY_MS);
  }

  @Builder
  private buildBlankSlots(assetCount: number) {
    if (assetCount === 1) {
      Blank()
        .layoutWeight(1)
        .aspectRatio(1);
      Blank()
        .layoutWeight(1)
        .aspectRatio(1);
      Blank()
        .layoutWeight(1)
        .aspectRatio(1);
    } else if (assetCount === 2) {
      Blank()
        .layoutWeight(1)
        .aspectRatio(1);
      Blank()
        .layoutWeight(1)
        .aspectRatio(1);
    } else if (assetCount === 3) {
      Blank()
        .layoutWeight(1)
        .aspectRatio(1);
    }
  }

  @Builder
  private buildFloatingHeader() {
    if (this.floatingSectionTitle) {
      Column({ space: 1 }) {
        Text(this.floatingSectionTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(0xFF111827);

        Text(`${this.floatingSectionCount} items`)
          .fontSize(10)
          .fontColor(0xFF6B7280);
      }
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(0xEEF8FAFC)
      .borderRadius(18)
      .margin({ left: 8, top: this.topInset + 4 });
    }
  }

  @Builder
  private buildPhotoRow(item: HybridTimelineItem, rowIndex: number) {
    Row({ space: Shared.HYBRID_GRID_GAP }) {
      ForEach(
        item.assets,
        (asset: HybridPhotoAsset) => {
          HybridPhotoTile({ asset: asset, requestSize: Shared.HYBRID_REQUEST_SIZE })
            .reuseId(asset.isVideo ? 'hybrid_photo_tile_video' : 'hybrid_photo_tile_image');
        },
        (asset: HybridPhotoAsset) => asset.remoteId ?? asset.localId ?? asset.id ?? asset.thumbnailUrl ?? '',
      );

      this.buildBlankSlots(item.assets.length);
    }
    .width('100%')
    .padding({
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
    });
  }

  build() {
    Column() {
      if (this.isLoading && this.allTimelineItems.length === 0) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(0xFF475569);

          Text('Loading photos...')
            .fontSize(14)
            .fontColor(0xFF64748B)
            .margin({ top: 12 });
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else if (this.errorText && this.allTimelineItems.length === 0) {
        Column() {
          Text('ArkUI photo grid is unavailable')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(0xFF111827);

          Text(this.errorText)
            .fontSize(12)
            .fontColor(0xFF64748B)
            .margin({ top: 8, left: 24, right: 24 })
            .textAlign(TextAlign.Center);

          Button('Retry')
            .margin({ top: 16 })
            .onClick(() => {
              this.reload();
            });
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          List({ scroller: this.scroller, space: 0 }) {
            LazyForEach(
              this.timelineDataSource,
              (item: HybridTimelineItem, index?: number) => {
                ListItem() {
                  if (item.kind === 'spacer') {
                    Blank()
                      .width('100%')
                      .height(item.spacerHeight ?? 0);
                  } else {
                    this.buildPhotoRow(item, index ?? 0);
                  }
                }
                .width('100%');
              },
              (item: HybridTimelineItem) => item.key,
            );

            ListItem() {
              Column() {
                Blank()
                  .width('100%')
                  .height(this.hasMore ? 16 : 28);
              }
              .width('100%');
            }
          }
          .cachedCount(Shared.HYBRID_LIST_CACHE_COUNT)
          .onScrollStart((): void => {
            this.onScrollStart();
          })
          .onScrollStop((): void => {
            this.onScrollStop();
          })
          .onScrollIndex((start: number, end: number, _center: number) => {
            const actualStart = this.windowIndexToTimelineIndex(start);
            const actualEnd = this.windowIndexToTimelineIndex(end);
            const previousStart = this.lastVisibleStart;
            const previousEnd = this.lastVisibleEnd;
            this.lastVisibleStart = actualStart;
            this.lastVisibleEnd = actualEnd;
            this.updateFloatingSection(actualStart);
            this.pruneThumbnailCacheAroundViewport(actualStart, actualEnd);
            this.prefetchAheadWhileScrolling(previousStart, previousEnd, actualStart, actualEnd);
            this.prefetchTimelineRows(actualStart, actualEnd + Shared.HYBRID_THUMBNAIL_PREFETCH_ROWS);
            this.maybePrefetch(actualEnd);
            this.maybeShiftTimelineWindow(actualStart, actualEnd);
          })
          .onAreaChange((_: Area, newValue: Area) => {
            const nextWidth = Number(newValue.width);
            if (nextWidth > 0 && Math.abs(nextWidth - this.listWidth) > 0.5) {
              this.listWidth = nextWidth;
              this.rebuildTimelineWindow(this.lastVisibleStart, this.lastVisibleEnd, true);
            }
          })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .width('100%')
          .height('100%');

          this.buildFloatingHeader();
        }
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(0xFFF7F8FA);
  }
}
