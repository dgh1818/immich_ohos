import { common } from '@kit.AbilityKit';
import { HybridFlutterBridge } from '../../bridge/HybridFlutterBridge';
import * as Shared from './HybridPhotoGridShared';
import * as ThumbnailDisk from './HybridPhotoThumbnailDisk';
import { HybridThumbnailCache, buildThumbnailCacheKey, prefetchAssetThumbnail } from './HybridPhotoThumbnail';
import { HybridPhotoTile } from './HybridPhotoTile';
import { HybridPhotoTimelineBuilder } from './HybridPhotoTimeline';
import { HybridDayGridVm } from './viewmodel/HybridDayGridVm';
import { HybridDayGridVc } from './viewcontroller/HybridDayGridVc';
import { HybridSlidingWindowDataSource } from './viewmodel/HybridSlidingWindowDataSource';
import { HybridIncrementalUpdater } from './viewmodel/HybridIncrementalUpdater';
import { HybridPinchGestureHandler } from './viewcontroller/HybridPinchGestureHandler';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridTimelineItem = Shared.HybridTimelineItem;

class TargetAnchorPosition {
  public anchorX: number = 0;
  public anchorY: number = 0;

  constructor(anchorX: number, anchorY: number) {
    this.anchorX = anchorX;
    this.anchorY = anchorY;
  }
}

@Component
export struct HybridPhotoGridNew {
  private readonly context = getContext(this) as common.UIAbilityContext;
  @Prop topInset: number = 56;

  private readonly viewModel: HybridDayGridVm = new HybridDayGridVm(this.context, 0);
  private readonly viewController: HybridDayGridVc = new HybridDayGridVc();
  private readonly slidingWindowDataSource: HybridSlidingWindowDataSource = new HybridSlidingWindowDataSource();
  private readonly incrementalUpdater: HybridIncrementalUpdater = new HybridIncrementalUpdater();
  private readonly timelineBuilder: HybridPhotoTimelineBuilder = new HybridPhotoTimelineBuilder();
  private readonly pinchHandler: HybridPinchGestureHandler = new HybridPinchGestureHandler();
  private readonly scroller: Scroller = new Scroller();
  private readonly targetScroller: Scroller = new Scroller();
  private readonly gridDataSource: Shared.HybridGridDataSource = new Shared.HybridGridDataSource();
  private readonly targetGridDataSource: Shared.HybridGridDataSource = new Shared.HybridGridDataSource();

  @State private sections: Array<HybridPhotoSection> = [];
  @State private isLoading: boolean = true;
  @State private isLoadingMore: boolean = false;
  @State private hasMore: boolean = true;
  @State private errorText: string = '';
  @State private floatingSectionTitle: string = '';
  @State private floatingSectionCount: number = 0;
  @State private listWidth: number = 0;
  @State private listHeight: number = 0;
  @State private gridColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @State private columnsTemplate: string = '1fr 1fr 1fr 1fr';
  @State private currentScrollOffsetY: number = 0;

  @State private pinchActive: boolean = false;
  @State private pinchScale: number = 1;
  @State private pinchCenterX: number = 0;
  @State private pinchCenterY: number = 0;
  @State private pinchStartColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @State private pinchTargetColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @State private pinchProgress: number = 0;
  @State private showTargetGrid: boolean = false;
  @State private targetGridScale: number = 1;
  @State private targetGridOpacity: number = 0;

  private allGridItems: Array<Shared.HybridGridItem> = [];
  private targetGridItems: Array<Shared.HybridGridItem> = [];

  // ========== Pre-built adjacent grids for instant pinch switching ==========
  private readonly prebuiltZoomInDataSource: Shared.HybridGridDataSource = new Shared.HybridGridDataSource();
  private readonly prebuiltZoomOutDataSource: Shared.HybridGridDataSource = new Shared.HybridGridDataSource();
  private readonly prebuiltZoomInScroller: Scroller = new Scroller();
  private readonly prebuiltZoomOutScroller: Scroller = new Scroller();
  @State private prebuiltZoomInColumns: number = 0;
  @State private prebuiltZoomOutColumns: number = 0;
  private prebuiltZoomInGridItems: Array<Shared.HybridGridItem> = [];
  private prebuiltZoomOutGridItems: Array<Shared.HybridGridItem> = [];
  private prebuildToken: number = 0;

  aboutToAppear(): void {
    this.viewModel.setGridColumns(this.gridColumns);
    this.updateColumnsTemplate();
    this.initPinchHandler();
    this.viewController.init(this.viewModel, this.scroller, this.targetScroller);
    this.registerListeners();
    void this.reload();
  }

  aboutToDisappear(): void {
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    this.viewModel.release();
    this.viewController.release();
  }

  private initPinchHandler(): void {
    this.pinchHandler.setOnScaleUpdate((scale: number, centerX: number, centerY: number): void => {
      this.pinchScale = scale;
      this.pinchCenterX = centerX;
      this.pinchCenterY = centerY;
      this.updateTargetGridProperties(scale);
      this.syncTargetGridScroll();
    });
  }

  private registerListeners(): void {
    this.viewModel.addDataLoadListener({
      onDataLoaded: (_items: Array<HybridTimelineItem>, hasMore: boolean): void => {
        this.hasMore = hasMore;
      },
      onDataLoadError: (error: string): void => {
        this.errorText = error;
      },
      onDataLoading: (isLoading: boolean): void => {
        this.isLoading = isLoading;
      },
    });

    this.viewModel.addScrollStateListener({
      onScrollStart: (): void => {
        ThumbnailDisk.HybridScrollState.isScrolling = true;
        this.invalidatePrebuilds();
      },
      onScrollStop: (): void => {
        ThumbnailDisk.HybridScrollState.isScrolling = false;
        this.startPrebuiltGrids();
      },
      onScrollIndex: (firstIndex: number, _lastIndex: number): void => {
        this.updateFloatingSection(firstIndex);
      },
    });

    this.slidingWindowDataSource.addWindowListener({
      onWindowRangeChange: (_oldRange, _newRange): void => {},
    });

    this.incrementalUpdater.addListener({
      onAfterUpdate: (_result): void => {},
    });
  }

  private async reload(): Promise<void> {
    this.sections = [];
    this.errorText = '';
    this.floatingSectionTitle = '';
    this.floatingSectionCount = 0;
    this.resetPinchState();

    try {
      await this.viewModel.reload();
      this.syncDataFromViewModel(true);
      const items = this.viewModel.getAllTimelineItems();
      if (items.length > 0) {
        this.applyFloatingSection(items[0]);
      }
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
      await this.viewModel.loadMore();
      this.syncDataFromViewModel(false);
    } finally {
      this.isLoadingMore = false;
    }
  }

  private syncDataFromViewModel(reinitializeIncremental: boolean): void {
    this.sections = this.viewModel.getSections();
    const items = this.viewModel.getAllTimelineItems();
    this.slidingWindowDataSource.replaceAll(items);
    if (reinitializeIncremental) {
      this.incrementalUpdater.initialize(items);
    }
    this.updateGridData();
  }

  private updateGridData(): void {
    this.allGridItems = this.buildGridItemsForColumns(this.gridColumns);
    this.gridDataSource.updateAll(this.allGridItems);
  }

  private buildGridItemsForColumns(columns: number): Array<Shared.HybridGridItem> {
    const items: Array<Shared.HybridGridItem> = [];
    let itemId = 0;
    const reflowedSections = this.timelineBuilder.reflowSections(this.sections, columns);

    for (const section of reflowedSections) {
      for (const row of section.rows) {
        for (const asset of row) {
          items.push({
            id: `photo_${asset.id}`,
            kind: 'photo',
            asset: asset,
            sectionKey: section.key,
          });
        }
      }
    }

    items.push({
      id: `tail_${itemId++}`,
      kind: 'tail',
      sectionKey: '',
    });

    return items;
  }

  private updateColumnsTemplate(): void {
    this.columnsTemplate = '1fr '.repeat(this.gridColumns).trim();
  }

  private getGridContentTopInsetHeight(): number {
    return 0;
  }

  private getFloatingHeaderTopInsetHeight(): number {
    return this.topInset + 4;
  }

  private getTimelineRowHeightForColumns(columns: number): number {
    if (this.listWidth <= 0 || columns <= 0) {
      return 0;
    }

    const totalGap = Shared.HYBRID_GRID_GAP * Math.max(0, columns - 1);
    return Math.max(0, (this.listWidth - totalGap) / columns);
  }

  private getTotalPhotoCount(): number {
    let count = 0;
    for (const section of this.sections) {
      for (const row of section.rows) {
        count += row.length;
      }
    }
    return count;
  }

  private resolveTargetAnchorPosition(columns: number): TargetAnchorPosition {
    const state = this.pinchHandler.getState();
    const anchor = state?.anchor;
    const targetTileSize = this.getTimelineRowHeightForColumns(columns);
    if (!anchor || targetTileSize <= 0) {
      return new TargetAnchorPosition(
        this.pinchCenterX,
        this.getGridContentTopInsetHeight(),
      );
    }

    const safeColumns = Math.max(1, columns);
    const step = targetTileSize + Shared.HYBRID_GRID_GAP;
    const totalPhotoCount = Math.max(1, this.getTotalPhotoCount());
    const anchorIndex = Math.max(0, Math.min(totalPhotoCount - 1, anchor.itemIndex));
    const rowIndex = Math.floor(anchorIndex / safeColumns);
    const columnIndex = anchorIndex % safeColumns;

    return new TargetAnchorPosition(
      columnIndex * step + anchor.xProgress * targetTileSize,
      this.getGridContentTopInsetHeight() + rowIndex * step + anchor.yProgress * targetTileSize,
    );
  }

  private resolveTargetGridScale(): number {
    if (!this.pinchActive || this.pinchTargetColumns === this.pinchStartColumns) {
      return 1;
    }

    const currentTileSize = this.getTimelineRowHeightForColumns(this.pinchStartColumns);
    const targetTileSize = this.getTimelineRowHeightForColumns(this.pinchTargetColumns);
    if (currentTileSize <= 0 || targetTileSize <= 0) {
      return 1;
    }

    const currentStep = currentTileSize + Shared.HYBRID_GRID_GAP;
    const targetStep = targetTileSize + Shared.HYBRID_GRID_GAP;
    if (currentStep <= 0 || targetStep <= 0) {
      return 1;
    }

    const startScale = currentStep / targetStep;
    return startScale + (1 - startScale) * this.pinchProgress;
  }

  private resolveTargetGridTranslateX(): number {
    if (!this.pinchActive || this.pinchTargetColumns === this.pinchStartColumns) {
      return 0;
    }

    const targetAnchor = this.resolveTargetAnchorPosition(this.pinchTargetColumns);
    const scaledAnchorX =
      this.pinchCenterX + this.targetGridScale * (targetAnchor.anchorX - this.pinchCenterX);
    return this.pinchCenterX - scaledAnchorX;
  }

  private resolveTargetGridScrollOffset(columns: number, fallbackScrollOffset: number): number {
    if (!this.pinchActive || columns <= 0) {
      return Math.max(0, fallbackScrollOffset);
    }

    const targetAnchor = this.resolveTargetAnchorPosition(columns);
    return Math.max(0, targetAnchor.anchorY - this.pinchCenterY);
  }

  private updateTargetGridProperties(scale: number): void {
    const isTargetChanged = this.pinchTargetColumns !== this.pinchStartColumns;
    if (!isTargetChanged) {
      this.pinchProgress = 0;
      this.targetGridScale = 1;
      this.targetGridOpacity = this.pinchActive ? 1 : 0;
      return;
    }

    let progress = Math.max(0, Math.min(1, Math.abs(scale - 1) / 0.35));
    progress = Math.max(progress, 0.12);

    this.pinchProgress = progress;
    this.targetGridScale = this.resolveTargetGridScale();
    this.targetGridOpacity = Math.max(0.24, Math.min(1, 0.24 + progress * 0.76));
  }

  private handlePinchStart(centerX: number, centerY: number): void {
    let scrollOffset = 0;
    try {
      scrollOffset = Math.max(0, this.scroller.currentOffset().yOffset);
    } catch (_) {
      scrollOffset = this.currentScrollOffsetY;
    }

    const state = this.pinchHandler.start(
      this.gridColumns,
      centerX,
      centerY,
      scrollOffset,
      Math.max(1, this.listWidth),
      Math.max(1, this.listHeight),
      this.getGridContentTopInsetHeight(),
    );

    this.pinchActive = true;
    this.showTargetGrid = true;
    this.pinchScale = 1;
    this.pinchStartColumns = this.gridColumns;
    this.pinchTargetColumns = state.targetColumns;
    this.pinchProgress = 0;
    this.pinchCenterX = state.anchor.anchorCenterX;
    this.pinchCenterY = state.anchor.anchorCenterY;
    this.targetGridScale = 1;
    this.targetGridOpacity = 1;

    // Reuse pre-built grid items if available for the target column count
    const prebuiltItems = this.getPrebuiltGridItemsForColumns(state.targetColumns);
    if (prebuiltItems !== null) {
      this.targetGridItems = prebuiltItems;
      console.info(`[HybridPhotoGridNew] pinchStart: reusing prebuilt grid for ${state.targetColumns} cols`);
    } else {
      this.targetGridItems = this.buildGridItemsForColumns(state.targetColumns);
    }
    this.targetGridDataSource.updateAll(this.targetGridItems);
    this.syncTargetGridScroll(scrollOffset);
    this.viewModel.handlePinchStart(centerX, centerY);
  }

  private handlePinchUpdate(scale: number, centerX: number, centerY: number): void {
    if (!this.pinchActive) {
      return;
    }

    const state = this.pinchHandler.update(scale, centerX, centerY, Math.max(1, this.listWidth));
    if (!state) {
      return;
    }

    if (state.targetColumns !== this.pinchTargetColumns) {
      this.pinchTargetColumns = state.targetColumns;
      const prebuiltItems = this.getPrebuiltGridItemsForColumns(state.targetColumns);
      if (prebuiltItems !== null) {
        this.targetGridItems = prebuiltItems;
        console.info(`[HybridPhotoGridNew] pinchUpdate: reusing prebuilt grid for ${state.targetColumns} cols`);
      } else {
        this.targetGridItems = this.buildGridItemsForColumns(state.targetColumns);
      }
      this.targetGridDataSource.updateAll(this.targetGridItems);
    }

    this.updateTargetGridProperties(state.currentScale);
    this.syncTargetGridScroll();
    this.viewModel.handlePinchUpdate(scale, centerX, centerY);
  }

  private handlePinchEnd(): void {
    if (!this.pinchActive) {
      return;
    }

    const previousColumns = this.gridColumns;
    const result = this.pinchHandler.end();
    this.viewModel.handlePinchEnd();
    if (!result) {
      this.resetPinchState();
      return;
    }

    const shouldApplyColumns = result.columns !== previousColumns;
    const duration = shouldApplyColumns ? 200 : 160;
    this.pinchTargetColumns = result.columns;

    if (shouldApplyColumns) {
      this.applyNewColumns(result.columns, result.scrollOffset);
      this.pinchScale = previousColumns / result.columns;
      this.targetGridScale = 1;
      this.targetGridOpacity = 1;
    }

    this.getUIContext().animateTo(
      {
        duration: duration,
        curve: this.pinchHandler.getAnimationCurve(),
      },
      (): void => {
        this.pinchScale = 1;
        this.targetGridScale = 1;
        this.targetGridOpacity = 0;
        this.pinchProgress = 0;
      },
    );

    setTimeout((): void => {
      this.resetPinchState();
      this.touchRetainedKeysForViewport();
      this.startPrebuiltGrids();
    }, duration + 10);
  }

  private applyNewColumns(columns: number, scrollOffset: number): void {
    if (columns === this.gridColumns) {
      return;
    }

    this.gridColumns = columns;
    this.viewModel.setGridColumns(columns);
    this.updateColumnsTemplate();
    this.updateGridData();

    setTimeout((): void => {
      try {
        const nextOffset = Math.max(0, scrollOffset);
        this.scroller.scrollTo({
          xOffset: 0,
          yOffset: nextOffset,
        });
        this.currentScrollOffsetY = nextOffset;
      } catch (_) {}
    }, 0);
  }

  private resetPinchState(): void {
    this.pinchActive = false;
    this.pinchScale = 1;
    this.pinchProgress = 0;
    this.pinchStartColumns = this.gridColumns;
    this.pinchTargetColumns = this.gridColumns;
    this.showTargetGrid = false;
    this.targetGridOpacity = 0;
    this.targetGridScale = 1;
  }

  private touchRetainedKeysForViewport(): void {
    const items = this.viewModel.getAllTimelineItems();
    if (items.length <= 0) {
      return;
    }

    const screenRows = Math.max(1, this.viewModel.getVisibleRowCapacity());
    const keepStart = Math.max(0, this.viewModel.getLastVisibleStart() - screenRows * 2);
    const keepEnd = Math.min(items.length - 1, this.viewModel.getLastVisibleEnd() + screenRows * 4);
    const retainKeys: Array<string> = [];
    for (let index = keepStart; index <= keepEnd; index += 1) {
      const item = items[index];
      if (item && item.assets) {
        item.assets.forEach((asset: Shared.HybridPhotoAsset) => {
          if (asset.id) {
            retainKeys.push(buildThumbnailCacheKey(asset.id, Shared.HYBRID_REQUEST_SIZE));
          }
        });
      }
    }

    if (retainKeys.length > 0) {
      HybridThumbnailCache.touchRetainedKeys(retainKeys);
    }
  }

  // ========== Pre-built adjacent grids ==========

  private invalidatePrebuilds(): void {
    this.prebuildToken += 1;
    this.prebuiltZoomInColumns = 0;
    this.prebuiltZoomOutColumns = 0;
    this.prebuiltZoomInGridItems = [];
    this.prebuiltZoomOutGridItems = [];
  }

  private startPrebuiltGrids(): void {
    this.invalidatePrebuilds();

    const currentColumns = this.gridColumns;
    const items = this.viewModel.getAllTimelineItems();
    if (items.length <= 0) {
      return;
    }

    const token = this.prebuildToken;

    // Calculate adjacent column counts
    const zoomInColumns = currentColumns > Shared.HYBRID_GRID_MIN_COLUMNS ? currentColumns - 1 : 0;
    const zoomOutColumns = currentColumns < Shared.HYBRID_GRID_MAX_COLUMNS ? currentColumns + 1 : 0;

    // Build zoom-in grid (fewer columns = zoom in / enlarge)
    if (zoomInColumns > 0) {
      this.prebuiltZoomInGridItems = this.buildGridItemsForColumns(zoomInColumns);
      this.prebuiltZoomInColumns = zoomInColumns;
      this.prebuiltZoomInDataSource.updateAll(this.prebuiltZoomInGridItems);

      // Scroll pre-built grid to matching position
      this.syncPrebuiltGridScroll(this.prebuiltZoomInScroller, zoomInColumns);

      // Prefetch thumbnails for the pre-built grid viewport
      this.prefetchPrebuiltGridThumbnails(items, zoomInColumns, token);
    }

    // Build zoom-out grid (more columns = zoom out / shrink)
    if (zoomOutColumns > 0) {
      this.prebuiltZoomOutGridItems = this.buildGridItemsForColumns(zoomOutColumns);
      this.prebuiltZoomOutColumns = zoomOutColumns;
      this.prebuiltZoomOutDataSource.updateAll(this.prebuiltZoomOutGridItems);

      // Scroll pre-built grid to matching position
      this.syncPrebuiltGridScroll(this.prebuiltZoomOutScroller, zoomOutColumns);

      // Prefetch thumbnails for the pre-built grid viewport
      this.prefetchPrebuiltGridThumbnails(items, zoomOutColumns, token);
    }

    console.info(
      `[HybridPhotoGridNew] startPrebuiltGrids: current=${currentColumns}, ` +
      `zoomIn=${zoomInColumns}(${this.prebuiltZoomInGridItems.length} items), ` +
      `zoomOut=${zoomOutColumns}(${this.prebuiltZoomOutGridItems.length} items)`,
    );
  }

  private syncPrebuiltGridScroll(scroller: Scroller, targetColumns: number): void {
    if (this.listWidth <= 0 || targetColumns <= 0) {
      return;
    }

    // Calculate scroll offset for the target column layout based on current viewport position
    const currentTileSize = this.getTimelineRowHeightForColumns(this.gridColumns);
    const targetTileSize = this.getTimelineRowHeightForColumns(targetColumns);
    if (currentTileSize <= 0 || targetTileSize <= 0) {
      return;
    }

    // Approximate: convert current scroll offset proportionally
    const currentRow = this.currentScrollOffsetY / (currentTileSize + Shared.HYBRID_GRID_GAP);
    const currentItemIndex = Math.floor(currentRow) * this.gridColumns;
    const targetRow = Math.floor(currentItemIndex / targetColumns);
    const targetOffset = Math.max(0, targetRow * (targetTileSize + Shared.HYBRID_GRID_GAP));

    setTimeout((): void => {
      try {
        scroller.scrollTo({ xOffset: 0, yOffset: targetOffset });
      } catch (_) {}
    }, 0);
  }

  private prefetchPrebuiltGridThumbnails(
    items: Array<HybridTimelineItem>,
    targetColumns: number,
    token: number,
  ): void {
    if (items.length <= 0 || targetColumns <= 0) {
      return;
    }

    const screenRows = Math.max(1, this.viewModel.getVisibleRowCapacity());
    const prefetchScreens = Shared.HYBRID_SCROLL_STOP_PREFETCH_SCREEN_MULTIPLIER;
    const prefetchRows = screenRows * prefetchScreens;

    // Calculate the item range in the target grid layout
    const currentTileSize = this.getTimelineRowHeightForColumns(this.gridColumns);
    const targetTileSize = this.getTimelineRowHeightForColumns(targetColumns);
    if (currentTileSize <= 0 || targetTileSize <= 0) {
      return;
    }

    // Map current viewport center to target grid row
    const viewportCenter = this.currentScrollOffsetY + this.listHeight / 2;
    const currentRow = viewportCenter / (currentTileSize + Shared.HYBRID_GRID_GAP);
    const currentItemIndex = Math.floor(currentRow) * this.gridColumns;
    const targetCenterRow = Math.floor(currentItemIndex / targetColumns);

    // Prefetch range in timeline item index space
    const prefetchStartRow = Math.max(0, targetCenterRow - prefetchRows);
    const prefetchEndRow = targetCenterRow + prefetchRows;

    // Convert row range to flat item indices, then map to timeline items
    const startItemIndex = prefetchStartRow * targetColumns;
    const endItemIndex = Math.min(items.length - 1, prefetchEndRow * targetColumns + targetColumns - 1);

    // Flatten timeline item assets and prefetch
    let prefetchCount = 0;
    for (let timelineIndex = 0; timelineIndex < items.length && prefetchCount <= endItemIndex; timelineIndex += 1) {
      if (token !== this.prebuildToken) {
        return; // Token changed, abort
      }

      const item = items[timelineIndex];
      for (const asset of item.assets) {
        if (prefetchCount >= startItemIndex && prefetchCount <= endItemIndex) {
          prefetchAssetThumbnail(this.context, asset, Shared.HYBRID_REQUEST_SIZE);
        }
        prefetchCount += 1;
        if (prefetchCount > endItemIndex) {
          break;
        }
      }
    }

    console.info(
      `[HybridPhotoGridNew] prefetchPrebuiltGrid: cols=${targetColumns}, ` +
      `rows=[${prefetchStartRow},${prefetchEndRow}], items=[${startItemIndex},${endItemIndex}]`,
    );
  }

  private getPrebuiltGridItemsForColumns(columns: number): Array<Shared.HybridGridItem> | null {
    if (columns === this.prebuiltZoomInColumns && this.prebuiltZoomInGridItems.length > 0) {
      return this.prebuiltZoomInGridItems;
    }
    if (columns === this.prebuiltZoomOutColumns && this.prebuiltZoomOutGridItems.length > 0) {
      return this.prebuiltZoomOutGridItems;
    }
    return null;
  }

  private syncTargetGridScroll(fallbackScrollOffset?: number): void {
    try {
      this.targetScroller.scrollTo({
        xOffset: 0,
        yOffset: this.resolveTargetGridScrollOffset(
          this.pinchTargetColumns,
          fallbackScrollOffset ?? this.currentScrollOffsetY,
        ),
      });
    } catch (_) {}
  }

  private applyFloatingSection(item: HybridTimelineItem): void {
    this.floatingSectionTitle = item.sectionTitle;
    this.floatingSectionCount = item.sectionCount;
  }

  private updateFloatingSection(startIndex: number): void {
    const items = this.viewModel.getAllTimelineItems();
    if (items.length <= 0) {
      return;
    }

    const safeIndex = Math.max(0, Math.min(startIndex, items.length - 1));
    this.applyFloatingSection(items[safeIndex]);
  }

  private resolveAssetIndex(targetAsset: HybridPhotoAsset): number {
    let index = 0;
    for (const section of this.sections) {
      for (const row of section.rows) {
        for (const asset of row) {
          if (asset.id === targetAsset.id) {
            return index;
          }
          index += 1;
        }
      }
    }
    return -1;
  }

  private async openAssetViewer(asset: HybridPhotoAsset): Promise<void> {
    const index = this.resolveAssetIndex(asset);
    if (index < 0) {
      console.error(`[HybridPhotoGridNew] Failed to resolve timeline index for asset ${asset.id}`);
      return;
    }

    try {
      await HybridFlutterBridge.openTimelineAssetViewerAt(index);
    } catch (error) {
      console.error(`[HybridPhotoGridNew] Open asset viewer failed for ${asset.id}: ${error}`);
    }
  }

  @Builder
  private buildFloatingHeader() {
    if (this.floatingSectionTitle) {
      Column({ space: 1 }) {
        Text(this.floatingSectionTitle)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(0xff111827)
        Text(`${this.floatingSectionCount} items`)
          .fontSize(10)
          .fontColor(0xff6b7280)
      }
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(0xdaf8fafc)
      .borderRadius(18)
      .margin({ left: 8, top: this.getFloatingHeaderTopInsetHeight() });
    }
  }

  @Builder
  private buildPhotoTile(asset: HybridPhotoAsset, index: number) {
    Stack() {
      HybridPhotoTile({
        asset: asset,
        requestSize: Shared.HYBRID_REQUEST_SIZE,
        suppressRelease: this.pinchActive,
      })
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.openAssetViewer(asset);
        })
    }
    .aspectRatio(1);
  }

  @Builder
  private buildMainGrid() {
    Grid(this.scroller) {
      LazyForEach(
        this.gridDataSource,
        (item: Shared.HybridGridItem, index: number) => {
          GridItem() {
            if (item.kind === 'photo') {
              this.buildPhotoTile(item.asset!, index);
            } else if (item.kind === 'tail') {
              Column() {}
                .width('100%')
                .height(this.hasMore ? 16 : 28);
            }
          }
        },
        (item: Shared.HybridGridItem) => item.id,
      )
    }
    .columnsTemplate(this.columnsTemplate)
    .rowsGap(Shared.HYBRID_GRID_GAP)
    .columnsGap(Shared.HYBRID_GRID_GAP)
    .cachedCount(Shared.HYBRID_LIST_CACHE_COUNT)
    .padding({ top: this.getGridContentTopInsetHeight() })
    .backgroundColor(Color.Transparent)
    .onDidScroll((): void => {
      try {
        this.currentScrollOffsetY = Math.max(0, this.scroller.currentOffset().yOffset);
      } catch (_) {}
    })
    .onScrollStart((): void => {
      this.viewModel.onScrollStart();
    })
    .onScrollStop((): void => {
      this.viewModel.onScrollStop();
    })
    .onScrollIndex((start: number, end: number) => {
      this.viewModel.onScrollIndex(start, end);

      const totalCount = this.allGridItems.length;
      const threshold = 40 * this.gridColumns;
      if (end < totalCount - threshold || !this.hasMore || this.isLoading || this.isLoadingMore) {
        return;
      }

      void this.loadMore();
    })
    .onAreaChange((_: Area, newValue: Area) => {
      const nextWidth = Number(newValue.width);
      const nextHeight = Number(newValue.height);

      if (nextHeight > 0 && Math.abs(nextHeight - this.listHeight) > 0.5) {
        this.listHeight = nextHeight;
      }

      if (nextWidth <= 0 || Math.abs(nextWidth - this.listWidth) <= 0.5) {
        return;
      }

      this.listWidth = nextWidth;
      const newColumns = Math.max(
        Shared.HYBRID_GRID_MIN_COLUMNS,
        Math.min(
          Shared.HYBRID_GRID_MAX_COLUMNS,
          Math.floor(
            (nextWidth + Shared.HYBRID_GRID_GAP) /
              (Shared.HYBRID_GRID_MIN_TILE_WIDTH + Shared.HYBRID_GRID_GAP),
          ),
        ),
      );
      if (newColumns === this.gridColumns) {
        return;
      }

      this.gridColumns = newColumns;
      this.viewModel.setGridColumns(newColumns);
      this.updateColumnsTemplate();
      this.updateGridData();
    })
    .scrollBar(BarState.Off)
    .edgeEffect(this.pinchActive ? EdgeEffect.None : EdgeEffect.Spring)
    .opacity(
      !this.pinchActive || this.pinchTargetColumns === this.pinchStartColumns
        ? 1
        : Math.max(0.18, 1 - this.pinchProgress * 0.82),
    )
    .width('100%')
    .height('100%')
    .clip(false)
    .scale(
      this.pinchActive
        ? {
            x: this.pinchScale,
            y: this.pinchScale,
            centerX: this.pinchCenterX,
            centerY: this.pinchCenterY,
          }
        : { x: 1, y: 1 },
    );
  }

  @Builder
  private buildPrebuiltZoomInGrid() {
    Grid(this.prebuiltZoomInScroller) {
      LazyForEach(
        this.prebuiltZoomInDataSource,
        (item: Shared.HybridGridItem, index: number) => {
          GridItem() {
            if (item.kind === 'photo') {
              this.buildPhotoTile(item.asset!, index);
            }
          }
        },
        (item: Shared.HybridGridItem) => `preZI_${item.id}`,
      )
    }
    .columnsTemplate('1fr '.repeat(this.prebuiltZoomInColumns).trim())
    .rowsGap(Shared.HYBRID_GRID_GAP)
    .columnsGap(Shared.HYBRID_GRID_GAP)
    .cachedCount(Shared.HYBRID_LIST_CACHE_COUNT)
    .padding({ top: this.getGridContentTopInsetHeight() })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .opacity(0)
  }

  @Builder
  private buildPrebuiltZoomOutGrid() {
    Grid(this.prebuiltZoomOutScroller) {
      LazyForEach(
        this.prebuiltZoomOutDataSource,
        (item: Shared.HybridGridItem, index: number) => {
          GridItem() {
            if (item.kind === 'photo') {
              this.buildPhotoTile(item.asset!, index);
            }
          }
        },
        (item: Shared.HybridGridItem) => `preZO_${item.id}`,
      )
    }
    .columnsTemplate('1fr '.repeat(this.prebuiltZoomOutColumns).trim())
    .rowsGap(Shared.HYBRID_GRID_GAP)
    .columnsGap(Shared.HYBRID_GRID_GAP)
    .cachedCount(Shared.HYBRID_LIST_CACHE_COUNT)
    .padding({ top: this.getGridContentTopInsetHeight() })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .opacity(0)
  }

  @Builder
  private buildTargetGrid() {
    Stack({ alignContent: Alignment.TopStart }) {
      Grid(this.targetScroller) {
        LazyForEach(
          this.targetGridDataSource,
          (item: Shared.HybridGridItem, index: number) => {
            GridItem() {
              if (item.kind === 'photo') {
                this.buildPhotoTile(item.asset!, index);
              } else if (item.kind === 'tail') {
                Column() {}
                  .width('100%')
                  .height(this.hasMore ? 16 : 28);
              }
            }
          },
          (item: Shared.HybridGridItem) => `target_${item.id}`,
        )
      }
      .columnsTemplate('1fr '.repeat(this.pinchTargetColumns).trim())
      .rowsGap(Shared.HYBRID_GRID_GAP)
      .columnsGap(Shared.HYBRID_GRID_GAP)
      .cachedCount(Shared.HYBRID_LIST_CACHE_COUNT)
      .padding({ top: this.getGridContentTopInsetHeight() })
      .backgroundColor(Color.Transparent)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .width('100%')
      .height('100%')
      .clip(false)
      .hitTestBehavior(HitTestMode.None)
      .scale({
        x: this.targetGridScale,
        y: this.targetGridScale,
        centerX: this.pinchCenterX,
        centerY: this.pinchCenterY,
      });
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
    .opacity(this.targetGridOpacity)
    .translate({
      x: this.resolveTargetGridTranslateX(),
      y: 0,
    });
  }

  build() {
    Stack() {
      // Hidden pre-built grids: force ArkUI to instantiate tiles so PixelMaps
      // are already cached when pinch starts.
      if (this.prebuiltZoomInColumns > 0) {
        this.buildPrebuiltZoomInGrid();
      }
      if (this.prebuiltZoomOutColumns > 0) {
        this.buildPrebuiltZoomOutGrid();
      }

      if (this.showTargetGrid) {
        this.buildTargetGrid();
      }

      this.buildMainGrid();

      this.buildFloatingHeader();

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color(0xff3b82f6);
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(0x50ffffff);
      }

      if (this.errorText) {
        Column() {
          Text(this.errorText)
            .fontSize(14)
            .fontColor(0xffef4444);
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center);
      }
    }
    .clip(false)
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .transition(TransitionEffect.opacity(0.99))
    .gesture(
      GestureGroup(
        GestureMode.Exclusive,
        PinchGesture({ fingers: 2 })
          .onActionStart((event: GestureEvent): void => {
            this.handlePinchStart(event.pinchCenterX, event.pinchCenterY);
            this.handlePinchUpdate(event.scale, event.pinchCenterX, event.pinchCenterY);
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.handlePinchUpdate(event.scale, event.pinchCenterX, event.pinchCenterY);
          })
          .onActionEnd((_event: GestureEvent): void => {
            this.handlePinchEnd();
          })
          .onActionCancel((_event: GestureEvent): void => {
            this.handlePinchEnd();
          }),
      ),
    )
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]);
  }
}
