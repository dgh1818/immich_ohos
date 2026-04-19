/**
 * HybridDayGridVm - 日宫格视图模型
 * 负责管理数据加载、滚动处理、Pinch 手势处理等业务逻辑
 * 参考官方 DayGridVm.ets 架构
 */

import { common } from '@kit.AbilityKit';
import { HybridFlutterBridge } from '../../../bridge/HybridFlutterBridge';
import * as Shared from '../HybridPhotoGridShared';
import { HybridPhotoTimelineBuilder } from '../HybridPhotoTimeline';
import * as Thumbnail from '../HybridPhotoThumbnail';
import * as ThumbnailDisk from '../HybridPhotoThumbnailDisk';

// 导入状态管理
import { GridFormFsm, FormEventType, FormStateType, FormStateTypeUtils } from '../statemanager/GridFormFsm';
import { PinchStateManager, PinchObserverProxy, PinchStateUpdateParams, PinchEventListener } from '../statemanager/PinchStateManager';
import { SwitchStartInfo, SwitchType } from '../statemanager/common/SwitchStartInfo';
import { FormIndex, FORM_SIZE } from '../statemanager/constants/GridDefine';
import { PinchAction } from '../statemanager/constants/PinchDefine';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridBucketInfo = Shared.HybridBucketInfo;
type HybridGroupInfo = Shared.HybridGroupInfo;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridTimelineItem = Shared.HybridTimelineItem;

/**
 * 数据加载监听器
 */
export interface DataLoadListener {
  onDataLoaded?: (items: Array<HybridTimelineItem>, hasMore: boolean) => void;
  onDataLoadError?: (error: string) => void;
  onDataLoading?: (isLoading: boolean) => void;
}

export class HybridGridColumnsCommitState {
  public columns: number = 0;
  public targetFirstRowIndex: number = 0;
  public targetAnchorRowIndex: number = 0;
  public targetFirstPhotoIndex: number = 0;
  public targetAnchorPhotoIndex: number = 0;
  public targetScrollOffset: number = 0;
  public anchorItemIndex: number = 0;
  public extraOffset: number = 0;
}

class HybridPinchFreezeState {
  active: boolean = false;
  queuedVisibleStart: number = -1;
  queuedVisibleEnd: number = -1;
  queuedNeedsLoadMoreCheck: boolean = false;
  queuedDataLoaded: boolean = false;
  queuedLoadingDirty: boolean = false;
  queuedLoadingState: boolean = false;
  queuedError?: string = undefined;
}

/**
 * 滚动状态监听器
 */
export interface ScrollStateListener {
  onScrollStart?: () => void;
  onScrollStop?: () => void;
  onScrollIndex?: (firstIndex: number, lastIndex: number) => void;
}

/**
 * Pinch 手势监听器
 */
export interface PinchGestureListener {
  onPinchStart?: (centerX: number, centerY: number) => void;
  onPinchUpdate?: (scale: number, centerX: number, centerY: number) => void;
  onPinchEnd?: () => void;
}

/**
 * 日宫格视图模型
 */
export class HybridDayGridVm {
  private readonly tag: string = 'HybridDayGridVm';
  private readonly context: common.UIAbilityContext;

  // ========== 数据管理 ==========
  private yearBuckets: Array<HybridBucketInfo> = [];
  private monthBuckets: Array<HybridBucketInfo> = [];
  private groupDayGroups: Array<HybridGroupInfo> = [];
  private sections: Array<HybridPhotoSection> = [];
  private allTimelineItems: Array<HybridTimelineItem> = [];
  private windowStartOffset: number = 0;
  private windowEndOffset: number = 0;
  private nextOffset: number = 0;
  private hasMore: boolean = true;
  private isLoading: boolean = false;
  private isLoadingMore: boolean = false;
  private errorText: string = '';

  // ========== 滑窗机制 ==========
  private windowStartIndex: number = 0;
  private windowEndIndex: number = -1;
  private readonly windowBehindRows: number = Shared.HYBRID_WINDOW_BEHIND_ROWS;
  private readonly windowAheadRows: number = Shared.HYBRID_WINDOW_AHEAD_ROWS;

  // ========== 分页配置 ==========
  private readonly pageSize: number = Shared.HYBRID_PAGE_SIZE;
  private prefetchCursor: number = -1;
  private lastLoadMoreTriggerAt: number = 0;

  // ========== 缩略图预取 ==========
  private lastVisibleStart: number = 0;
  private lastVisibleEnd: number = 0;
  private loadedPhotoRowCount: number = 0;
  private visibleRowCapacity: number = 0;
  private runwayTopUpInFlight: boolean = false;
  private lastScrollPrefetchAt: number = 0;
  private lastForwardPrefetchEnd: number = -1;
  private lastBackwardPrefetchStart: number = Number.MAX_SAFE_INTEGER;
  private lastViewportPruneAt: number = 0;
  private requestSize: number = Shared.HYBRID_REQUEST_SIZE;

  // ========== 后台预下载 ==========
  private backgroundPredownloadToken: number = 0;
  private backgroundPredownloadRunning: boolean = false;
  private idleWorkToken: number = 0;
  private pendingWarmupSections: Array<HybridPhotoSection> = [];
  private prefetchOwnedByActiveRuntime: boolean = false;

  // ========== 工具类 ==========
  private readonly timelineBuilder: HybridPhotoTimelineBuilder = new HybridPhotoTimelineBuilder();

  // ========== 状态管理 ==========
  private formFsm: GridFormFsm;
  private pinchStateManager: PinchStateManager;
  private pinchObserverProxy: PinchObserverProxy;
  private currentForm: FormIndex = FormIndex.DAY;

  // ========== 监听器 ==========
  private dataLoadListeners: Array<DataLoadListener> = [];
  private scrollStateListeners: Array<ScrollStateListener> = [];
  private pinchGestureListeners: Array<PinchGestureListener> = [];

  // ========== Grid 配置 ==========
  private gridColumns: number = Shared.HYBRID_GRID_COLUMNS;
  private readonly pinchFreezeState: HybridPinchFreezeState = new HybridPinchFreezeState();

  public constructor(context: common.UIAbilityContext, persistentId: number = 0) {
    this.context = context;
    this.formFsm = new GridFormFsm(persistentId);
    this.pinchStateManager = new PinchStateManager(persistentId, this.formFsm);
    this.pinchObserverProxy = new PinchObserverProxy(this.pinchStateManager);
    this.initFsm();
  }

  // ========== 初始化 ==========

  private initFsm(): void {
    this.formFsm.initIsLastFormIsDayGroup(false);

    // 监听状态机状态变化
    this.formFsm.registerObserver({
      onStateChange: (oldState: FormStateType, newState: FormStateType, event: FormEventType): void => {
        console.log(`[${this.tag}] FSM state change: ${FormStateType[oldState]} -> ${FormStateType[newState]}, event: ${FormEventType[event]}`);
        this.currentForm = FormStateTypeUtils.getFormFromStateType(newState);
      }
    });

    // 监听缩放系数变化
    const scaleListener: PinchEventListener = {
      onPinchStateChange: (pinchState: PinchAction): void => {
        console.log(`[${this.tag}] Pinch state: ${PinchAction[pinchState]}`);
      }
    };
    this.pinchStateManager.addListener(scaleListener);
  }

  // ========== 数据加载 ==========

  /**
   * 重新加载数据
   */
  public async reload(): Promise<void> {
    this.backgroundPredownloadToken += 1;
    this.backgroundPredownloadRunning = false;
    this.yearBuckets = [];
    this.monthBuckets = [];
    this.sections = [];
    this.allTimelineItems = [];
    this.nextOffset = 0;
    this.hasMore = true;
    this.errorText = '';
    this.isLoading = true;
    this.prefetchCursor = -1;
    this.lastLoadMoreTriggerAt = 0;
    this.pendingWarmupSections = [];
    this.timelineBuilder.resetLayoutIds();
    this.windowStartIndex = 0;
    this.windowEndIndex = -1;
    this.lastVisibleStart = 0;
    this.lastVisibleEnd = 0;
    this.loadedPhotoRowCount = 0;
    this.visibleRowCapacity = 0;
    this.runwayTopUpInFlight = false;
    this.lastViewportPruneAt = 0;
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    this.idleWorkToken += 1;

    console.info(`[${this.tag}] reload start`);
    this.notifyDataLoading(true);

    try {
      await this.loadPage(true);
      // 提交数据加载事件
      this.formFsm.submitEvent(FormEventType.DATA_LOADED);
    } finally {
      this.isLoading = false;
      this.notifyDataLoading(false);
      console.info(`[${this.tag}] reload finalized: items=${this.allTimelineItems.length}, hasError=${this.errorText ? 1 : 0}`);
      void this.ensureLoadedRunway();
    }
  }

  public forcePruneThumbnailCache(): void {
    this.pruneThumbnailCacheAroundViewport(this.lastVisibleStart, this.lastVisibleEnd, true);
  }

  public beginPinchFreeze(): void {
    const freezeState = this.pinchFreezeState;
    freezeState.active = true;
    freezeState.queuedVisibleStart = this.lastVisibleStart;
    freezeState.queuedVisibleEnd = this.lastVisibleEnd;
    freezeState.queuedNeedsLoadMoreCheck = false;
    freezeState.queuedDataLoaded = false;
    freezeState.queuedLoadingDirty = false;
    freezeState.queuedLoadingState = false;
    freezeState.queuedError = undefined;
  }

  public endPinchFreeze(): number {
    const freezeState = this.pinchFreezeState;
    if (!freezeState.active) {
      return 0;
    }

    freezeState.active = false;
    let dispatchCount = 0;
    if (freezeState.queuedVisibleStart >= 0) {
      const nextStart = Math.max(0, freezeState.queuedVisibleStart);
      const nextEnd = Math.max(nextStart, freezeState.queuedVisibleEnd);
      this.lastVisibleStart = nextStart;
      this.lastVisibleEnd = nextEnd;
      this.updateSlidingWindow(nextStart);
      if (freezeState.queuedNeedsLoadMoreCheck) {
        this.maybeLoadMore(nextEnd);
      }
    }

    if (freezeState.queuedLoadingDirty) {
      dispatchCount += 1;
      this.dispatchDataLoadListeners('onDataLoading(deferred)', (listener: DataLoadListener) => {
        listener.onDataLoading?.(freezeState.queuedLoadingState);
      });
    }
    if (freezeState.queuedError !== undefined) {
      dispatchCount += 1;
      this.dispatchDataLoadListeners('onDataLoadError(deferred)', (listener: DataLoadListener) => {
        listener.onDataLoadError?.(freezeState.queuedError as string);
      });
    } else if (freezeState.queuedDataLoaded) {
      dispatchCount += 1;
      this.dispatchDataLoadListeners('onDataLoaded(deferred)', (listener: DataLoadListener) => {
        listener.onDataLoaded?.(this.allTimelineItems, this.hasMore);
      });
    }

    freezeState.queuedVisibleStart = -1;
    freezeState.queuedVisibleEnd = -1;
    freezeState.queuedNeedsLoadMoreCheck = false;
    freezeState.queuedDataLoaded = false;
    freezeState.queuedLoadingDirty = false;
    freezeState.queuedLoadingState = false;
    freezeState.queuedError = undefined;
    return dispatchCount;
  }

  /**
   * 加载更多数据
   */
  public async loadMore(): Promise<void> {
    if (!this.hasMore || this.isLoading || this.isLoadingMore) {
      return;
    }

    this.isLoadingMore = true;
    this.notifyDataLoading(true);

    try {
      await this.loadPage(false);
    } finally {
      this.isLoadingMore = false;
      this.notifyDataLoading(false);
    }
  }

  /**
   * 加载一页数据
   */
  private async loadPage(reset: boolean): Promise<void> {
    try {
      const payload = await HybridFlutterBridge.fetchTimelineWindow(
        reset ? 0 : this.nextOffset,
        this.pageSize,
      );
      const page = this.timelineBuilder.parsePageResult(payload);

      if (!page.ready) {
        this.errorText = page.reason ?? 'Hybrid photo data is unavailable';
        this.hasMore = false;
        this.notifyDataLoadError(this.errorText);
        return;
      }

      this.errorText = '';
      if (reset || page.yearBuckets.length > 0) {
        this.yearBuckets = page.yearBuckets.slice();
      }
      if (reset || page.monthBuckets.length > 0) {
        this.monthBuckets = page.monthBuckets.slice();
      }
      if (reset || page.groupDayGroups.length > 0) {
        this.groupDayGroups = page.groupDayGroups.slice();
      }
      this.windowStartOffset = page.windowStartOffset;
      this.windowEndOffset = page.windowEndOffset;
      this.nextOffset = page.nextOffset;
      this.hasMore = page.hasMore;
      const previousItemCount = this.allTimelineItems.length;

      if (reset || previousItemCount === 0) {
        // 首次加载或重置
        const normalizedSections = this.timelineBuilder.reflowSections(page.sections, this.gridColumns);
        const mergedSections = this.timelineBuilder.mergeSections([], normalizedSections, this.gridColumns).sections;
        this.sections = mergedSections;
        const timelineItems = this.timelineBuilder.buildTimelineItems(mergedSections, this.gridColumns);
        this.allTimelineItems = timelineItems;
        this.updateLoadedPhotoRowCount();
        console.info(`[${this.tag}] first page parsed: sections=${mergedSections.length}, items=${timelineItems.length}`);

        // 更新滑窗
        this.updateSlidingWindow(0);

        // 通知数据加载完成
        console.info(`[${this.tag}] first onDataLoaded dispatched`);
        this.notifyDataLoaded(timelineItems, this.hasMore);

        // 预取缩略图
        if (!this.prefetchOwnedByActiveRuntime && timelineItems.length > 0) {
          const initialRows = reset
            ? Shared.resolveInitialPrefetchRows(this.gridColumns)
            : Shared.resolveIncrementalPrefetchRows(this.gridColumns);
          this.prefetchTimelineRows(0, Math.min(timelineItems.length - 1, initialRows));
        }
        if (!this.prefetchOwnedByActiveRuntime) {
          this.pruneThumbnailCacheAroundViewport(
            0,
            Math.min(timelineItems.length - 1, Shared.resolveInitialPrefetchRows(this.gridColumns)),
            true,
          );
        }
      } else {
        // 增量加载
        const normalizedSections = this.timelineBuilder.reflowSections(page.sections, this.gridColumns);
        const mergeResult = this.timelineBuilder.mergeSections(this.sections, normalizedSections, this.gridColumns);
        this.sections = mergeResult.sections;
        this.updateLoadedPhotoRowCount();

        if (mergeResult.appendedEntries.length > 0) {
          const lastItem = this.allTimelineItems[previousItemCount - 1];
          const tailUpdate = this.timelineBuilder.buildAppendTail(
            lastItem,
            previousItemCount,
            mergeResult.appendedEntries,
            this.gridColumns,
          );

          // 增量更新数据
          this.allTimelineItems.splice(
            tailUpdate.startIndex,
            this.allTimelineItems.length - tailUpdate.startIndex,
            ...tailUpdate.items,
          );

          // 更新滑窗
          this.updateSlidingWindow(tailUpdate.startIndex);

          // 通知数据加载完成
          this.notifyDataLoaded(this.allTimelineItems, this.hasMore);

          if (!this.prefetchOwnedByActiveRuntime) {
            const totalCount = this.allTimelineItems.length;
            if (totalCount > 0) {
              const prefetchStart = Math.max(0, tailUpdate.startIndex - 1);
              const prefetchEnd = Math.min(totalCount - 1, prefetchStart + Shared.HYBRID_THUMBNAIL_PREFETCH_ROWS);
              this.prefetchTimelineRows(prefetchStart, prefetchEnd);
            }
            this.pruneThumbnailCacheAroundViewport(this.lastVisibleStart, this.lastVisibleEnd, true);
          }
        }
      }

      // 后台预下载
      if (!this.prefetchOwnedByActiveRuntime && !reset && Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
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
      if (!ThumbnailDisk.HybridScrollState.isScrolling && !this.pinchFreezeState.active) {
        void this.ensureLoadedRunway();
      }
    } catch (error) {
      console.error(`[${this.tag}] loadPage failed: ${this.describeListenerError(error)}`);
      this.errorText = 'Hybrid photo data load failed';
      this.hasMore = false;
      this.notifyDataLoadError(this.errorText);
    }
  }

  private updateLoadedPhotoRowCount(): void {
    let rowCount = 0;
    this.sections.forEach((section: HybridPhotoSection) => {
      rowCount += section.rows.length;
    });
    this.loadedPhotoRowCount = rowCount;
  }

  private resolveRunwayTargetRows(): number {
    const viewportRows = Math.max(
      1,
      this.visibleRowCapacity > 0 ? this.visibleRowCapacity : Shared.HYBRID_INITIAL_PREFETCH_ROWS,
    );
    return Math.max(Shared.HYBRID_MIN_RUNWAY_ROWS, viewportRows * Shared.HYBRID_RUNWAY_MULTIPLIER);
  }

  private shouldTopUpRunway(): boolean {
    return !this.pinchFreezeState.active &&
      !ThumbnailDisk.HybridScrollState.isScrolling &&
      this.hasMore &&
      !this.isLoading &&
      !this.isLoadingMore &&
      this.allTimelineItems.length - this.lastVisibleEnd < this.resolveRunwayTargetRows();
  }

  private async ensureLoadedRunway(): Promise<void> {
    if (this.runwayTopUpInFlight || !this.shouldTopUpRunway()) {
      return;
    }
    this.runwayTopUpInFlight = true;
    try {
      while (this.shouldTopUpRunway()) {
        await this.loadMore();
      }
    } finally {
      this.runwayTopUpInFlight = false;
    }
  }

  // ========== 滑窗机制 ==========

  /**
   * 更新滑窗
   * @param anchorIndex 锚点索引
   */
  public updateSlidingWindow(anchorIndex: number): void {
    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      this.windowStartIndex = 0;
      this.windowEndIndex = -1;
      return;
    }

    // 计算滑窗范围
    const safeAnchor = Math.max(0, Math.min(anchorIndex, totalCount - 1));
    const newStart = Math.max(0, safeAnchor - this.windowBehindRows);
    const newEnd = Math.min(totalCount - 1, safeAnchor + this.windowAheadRows);

    // 检查是否需要更新
    if (newStart !== this.windowStartIndex || newEnd !== this.windowEndIndex) {
      this.windowStartIndex = newStart;
      this.windowEndIndex = newEnd;
      console.log(`[${this.tag}] Sliding window updated: [${newStart}, ${newEnd}]`);
    }
  }

  /**
   * 获取滑窗内的数据
   */
  public getSlidingWindowItems(): Array<HybridTimelineItem> {
    if (this.windowEndIndex < 0 || this.windowStartIndex > this.windowEndIndex) {
      return this.allTimelineItems;
    }
    return this.allTimelineItems.slice(this.windowStartIndex, this.windowEndIndex + 1);
  }

  /**
   * 获取滑窗范围
   */
  public getSlidingWindowRange(): [number, number] {
    return [this.windowStartIndex, this.windowEndIndex];
  }

  public getLastVisibleStart(): number {
    return this.lastVisibleStart;
  }

  public getLastVisibleEnd(): number {
    return this.lastVisibleEnd;
  }

  public getVisibleRowCapacity(): number {
    return this.visibleRowCapacity;
  }

  public isPinchFreezeActive(): boolean {
    return this.pinchFreezeState.active;
  }

  // ========== 增量更新 ==========

  /**
   * 增量添加数据
   */
  public addItems(startIndex: number, items: Array<HybridTimelineItem>): void {
    const safeStart = Math.max(0, Math.min(startIndex, this.allTimelineItems.length));
    this.allTimelineItems.splice(safeStart, 0, ...items);
    this.updateSlidingWindow(safeStart);
    this.notifyDataLoaded(this.allTimelineItems, this.hasMore);
  }

  /**
   * 增量删除数据
   */
  public deleteItems(startIndex: number, count: number): void {
    const safeStart = Math.max(0, Math.min(startIndex, this.allTimelineItems.length - 1));
    const safeCount = Math.min(count, this.allTimelineItems.length - safeStart);
    this.allTimelineItems.splice(safeStart, safeCount);
    this.updateSlidingWindow(Math.max(0, safeStart - 1));
    this.notifyDataLoaded(this.allTimelineItems, this.hasMore);
  }

  /**
   * 更新单个数据项
   */
  public updateItem(index: number, item: HybridTimelineItem): void {
    if (index >= 0 && index < this.allTimelineItems.length) {
      this.allTimelineItems[index] = item;
    }
  }

  // ========== 滚动处理 ==========

  /**
   * 滚动开始
   */
  public onScrollStart(): void {
    ThumbnailDisk.HybridScrollState.isScrolling = true;
    this.idleWorkToken += 1;
    this.lastScrollPrefetchAt = 0;
    this.lastForwardPrefetchEnd = this.lastVisibleEnd;
    this.lastBackwardPrefetchStart = this.lastVisibleStart;

    if (this.pinchFreezeState.active) {
      this.scrollStateListeners.forEach(listener => listener.onScrollStart?.());
      return;
    }

    // 更新滑窗
    this.updateSlidingWindow(this.lastVisibleStart);

    // 通知监听器
    this.scrollStateListeners.forEach(listener => listener.onScrollStart?.());
  }

  /**
   * 滚动停止
   */
  public onScrollStop(): void {
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    if (this.pinchFreezeState.active) {
      this.scrollStateListeners.forEach(listener => listener.onScrollStop?.());
      return;
    }
    if (!this.prefetchOwnedByActiveRuntime) {
      this.pruneThumbnailCacheAroundViewport(this.lastVisibleStart, this.lastVisibleEnd, true);
      this.prefetchTimelineRows(
        this.lastVisibleStart,
        this.resolveScrollStopPrefetchEnd(this.lastVisibleEnd, this.allTimelineItems.length),
      );
      this.scheduleIdleWork();
    }
    void this.ensureLoadedRunway();

    // 通知监听器
    this.scrollStateListeners.forEach(listener => listener.onScrollStop?.());
  }

  /**
   * 滚动索引变化
   */
  public onScrollIndex(firstIndex: number, lastIndex: number): void {
    const previousStart = this.lastVisibleStart;
    const previousEnd = this.lastVisibleEnd;
    this.lastVisibleStart = firstIndex;
    this.lastVisibleEnd = lastIndex;
    this.visibleRowCapacity = Math.max(1, lastIndex - firstIndex + 1);
    if (this.pinchFreezeState.active) {
      this.pinchFreezeState.queuedVisibleStart = firstIndex;
      this.pinchFreezeState.queuedVisibleEnd = lastIndex;
      this.pinchFreezeState.queuedNeedsLoadMoreCheck = true;
      return;
    }

    // 更新滑窗
    this.updateSlidingWindow(firstIndex);

    // 检查是否需要加载更多
    this.maybeLoadMore(lastIndex);

    // 预取缩略图
    if (!this.prefetchOwnedByActiveRuntime) {
      this.prefetchAheadWhileScrolling(previousStart, previousEnd, firstIndex, lastIndex);
    }

    // 通知监听器
    this.scrollStateListeners.forEach(listener => listener.onScrollIndex?.(firstIndex, lastIndex));
  }

  /**
   * 检查是否需要加载更多
   */
  private maybeLoadMore(endIndex: number): void {
    if (!this.hasMore || this.isLoading || this.isLoadingMore) {
      return;
    }

    const loadedItems = this.allTimelineItems.length;
    if (loadedItems <= 0) {
      return;
    }

    const threshold = Math.max(
      Shared.HYBRID_LOAD_MORE_AHEAD_MIN_ROWS,
      Math.max(1, this.visibleRowCapacity) * Shared.HYBRID_LOAD_MORE_VIEWPORT_MULTIPLIER,
    );
    if (loadedItems - endIndex > threshold) {
      return;
    }

    if (this.prefetchCursor === this.nextOffset) {
      return;
    }

    this.triggerLoadMore();
  }

  /**
   * 触发加载更多
   */
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

  // ========== Pinch 手势处理 ==========

  /**
   * Pinch 开始
   */
  public handlePinchStart(centerX: number, centerY: number): void {
    // 提交捏合开始事件
    const startForm = this.currentForm;
    const switchStartInfo = new SwitchStartInfo(
      SwitchType.PINCH_GRID,
      startForm,
      centerX,
      centerY,
      0
    );

    const params = new PinchStateUpdateParams();
    params.pinchAction = PinchAction.START;
    params.pinchStartInfo = switchStartInfo;
    this.pinchStateManager.updatePinchState(params);

    this.formFsm.submitEvent(FormEventType.PINCH_START);

    // 通知监听器
    this.pinchGestureListeners.forEach(listener => listener.onPinchStart?.(centerX, centerY));
  }

  /**
   * Pinch 更新
   */
  public handlePinchUpdate(scale: number, centerX: number, centerY: number): void {
    // 通知监听器
    this.pinchGestureListeners.forEach(listener => listener.onPinchUpdate?.(scale, centerX, centerY));
  }

  /**
   * Pinch 结束
   */
  public handlePinchEnd(): void {
    // 提交捏合结束事件
    const params = new PinchStateUpdateParams();
    params.pinchAction = PinchAction.END;
    this.pinchStateManager.updatePinchState(params);

    this.formFsm.submitEvent(FormEventType.PINCH_END);
    this.pinchStateManager.clearStartInfo();

    // 通知监听器
    this.pinchGestureListeners.forEach(listener => listener.onPinchEnd?.());
  }

  // ========== 缩略图预取 ==========

  private prefetchTimelineRows(startIndex: number, endIndex: number): void {
    this.prefetchTimelineRowsInternal(startIndex, endIndex, false);
  }

  private prefetchTimelineRowsInternal(startIndex: number, endIndex: number, allowWhileScrolling: boolean): void {
    if (this.pinchFreezeState.active) {
      return;
    }

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

  private prefetchTimelineItem(item: HybridTimelineItem): void {
    item.assets.forEach((asset) => {
      Thumbnail.prefetchAssetThumbnail(this.context, asset, this.requestSize);
    });
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
      const targetEnd = this.resolveForwardPrefetchEnd(endIndex, totalCount);
      if (targetStart <= targetEnd && targetEnd > this.lastForwardPrefetchEnd) {
        this.prefetchTimelineRowsInternal(targetStart, targetEnd, true);
        this.lastForwardPrefetchEnd = targetEnd;
      }
      return;
    }

    if (startIndex < previousStart) {
      const targetStart = this.resolveBackwardPrefetchStart(startIndex);
      const targetEnd = Math.max(targetStart, startIndex - 1);
      if (targetStart <= targetEnd && targetStart < this.lastBackwardPrefetchStart) {
        this.prefetchTimelineRowsInternal(targetStart, targetEnd, true);
        this.lastBackwardPrefetchStart = targetStart;
      }
    }
  }

  private pruneThumbnailCacheAroundViewport(startIndex: number, endIndex: number, force: boolean = false): void {
    // Skip cache pruning during pinch to protect PixelMaps needed by both grids
    if (this.pinchFreezeState.active) {
      return;
    }

    const totalCount = this.allTimelineItems.length;
    if (totalCount <= 0) {
      return;
    }

    const now = Date.now();
    if (!force && now - this.lastViewportPruneAt < Shared.HYBRID_VIEWPORT_CACHE_PRUNE_INTERVAL_MS) {
      return;
    }
    this.lastViewportPruneAt = now;

    const keepStart = Math.max(0, startIndex - this.resolveKeepAboveRows());
    const keepEnd = Math.min(totalCount - 1, endIndex + this.resolveKeepBelowRows());
    const keepKeys: Set<string> = new Set();
    for (let index = keepStart; index <= keepEnd; index += 1) {
      const item = this.allTimelineItems[index];
      item.assets.forEach((asset: HybridPhotoAsset) => {
        if (asset.id) {
          keepKeys.add(Thumbnail.buildThumbnailCacheKey(asset.id, this.requestSize));
        }
      });
    }

    Thumbnail.HybridThumbnailCache.pruneOutsideKeys(keepKeys);
    console.info(
      `[${this.tag}] memory viewport=[${startIndex},${endIndex}] keep=[${keepStart},${keepEnd}] screenRows=${this.resolveViewportScreenRows()} cacheEntries=${Thumbnail.HybridThumbnailCache.entryCount()} sections=${this.sections.length} timelineItems=${this.allTimelineItems.length}`,
    );
  }

  private resolveViewportScreenRows(): number {
    return Math.max(
      1,
      this.visibleRowCapacity > 0 ? this.visibleRowCapacity : Shared.HYBRID_INITIAL_PREFETCH_ROWS,
    );
  }

  private resolveKeepAboveRows(): number {
    return this.resolveViewportScreenRows() * Shared.HYBRID_KEEP_ABOVE_SCREEN_MULTIPLIER;
  }

  private resolveKeepBelowRows(): number {
    return this.resolveViewportScreenRows() * Shared.HYBRID_KEEP_BELOW_SCREEN_MULTIPLIER;
  }

  private resolveForwardPrefetchEnd(endIndex: number, totalCount: number): number {
    return Math.min(
      totalCount - 1,
      endIndex + (this.resolveViewportScreenRows() * Shared.HYBRID_SCROLL_FORWARD_PREFETCH_SCREEN_MULTIPLIER),
    );
  }

  private resolveBackwardPrefetchStart(startIndex: number): number {
    return Math.max(
      0,
      startIndex - (this.resolveViewportScreenRows() * Shared.HYBRID_SCROLL_BACKWARD_PREFETCH_SCREEN_MULTIPLIER),
    );
  }

  private resolveScrollStopPrefetchEnd(endIndex: number, totalCount: number): number {
    return Math.min(
      totalCount - 1,
      endIndex + (this.resolveViewportScreenRows() * Shared.HYBRID_SCROLL_STOP_PREFETCH_SCREEN_MULTIPLIER),
    );
  }

  // ========== 后台预下载 ==========

  private shouldContinueBackgroundPredownload(): boolean {
    return (
      ThumbnailDisk.HybridRemoteThumbnailCacheIndex.totalTrackedBytes(this.context, true) <
      Shared.HYBRID_REMOTE_THUMBNAIL_CACHE_TRIM_TARGET_BYTES
    );
  }

  private async predownloadSections(sections: Array<HybridPhotoSection>, includeAllAssets: boolean): Promise<void> {
    if (sections.length === 0) {
      return;
    }

    const assets = this.timelineBuilder.collectPredownloadAssets(sections, includeAllAssets);
    for (let index = 0; index < assets.length; index += Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE) {
      // Back off while visible requests are in-flight
      while (Thumbnail.HybridThumbnailRequestLimiter.isUnderPressure()) {
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 2);
      }
      const batch = assets.slice(index, index + Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE);
      await Promise.all(
        batch.map((asset: HybridPhotoAsset) =>
          ThumbnailDisk.HybridRemoteThumbnailBackgroundPredownload.predownload(
            this.context,
            asset.thumbnailUrl as string,
            this.requestSize,
          ),
        ),
      );
      await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
    }
  }

  private startBackgroundPredownload(): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return;
    }

    if (ThumbnailDisk.HybridScrollState.isScrolling || this.backgroundPredownloadRunning || !this.shouldContinueBackgroundPredownload()
      || Thumbnail.HybridThumbnailRequestLimiter.isUnderPressure()) {
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
      // Pause when the system is under visible-request pressure
      if (Thumbnail.HybridThumbnailRequestLimiter.isUnderPressure()) {
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 4);
        continue;
      }
      try {
        const payload = await HybridFlutterBridge.fetchTimelineWindow(offset, Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE);
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
      } catch {
        break;
      }
    }
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

  // ========== 监听器管理 ==========

  public addDataLoadListener(listener: DataLoadListener): void {
    if (this.dataLoadListeners.indexOf(listener) >= 0) {
      return;
    }
    this.dataLoadListeners.push(listener);
  }

  public removeDataLoadListener(listener: DataLoadListener): void {
    this.dataLoadListeners = this.dataLoadListeners.filter(l => l !== listener);
  }

  public addScrollStateListener(listener: ScrollStateListener): void {
    if (this.scrollStateListeners.indexOf(listener) >= 0) {
      return;
    }
    this.scrollStateListeners.push(listener);
  }

  public removeScrollStateListener(listener: ScrollStateListener): void {
    this.scrollStateListeners = this.scrollStateListeners.filter(l => l !== listener);
  }

  public addPinchGestureListener(listener: PinchGestureListener): void {
    if (this.pinchGestureListeners.indexOf(listener) >= 0) {
      return;
    }
    this.pinchGestureListeners.push(listener);
  }

  public removePinchGestureListener(listener: PinchGestureListener): void {
    this.pinchGestureListeners = this.pinchGestureListeners.filter(l => l !== listener);
  }

  private describeListenerError(error: Error | string | number | boolean | Object | null | undefined): string {
    if (error instanceof Error) {
      return `${error.name}: ${error.message}`;
    }
    if (typeof error === 'string') {
      return error;
    }
    try {
      return JSON.stringify(error);
    } catch (_jsonError) {
      return String(error);
    }
  }

  private dispatchDataLoadListeners(
    dispatchLabel: string,
    dispatcher: (listener: DataLoadListener) => void,
  ): void {
    this.dataLoadListeners.forEach((listener: DataLoadListener, index: number) => {
      try {
        dispatcher(listener);
      } catch (error) {
        console.error(
          `[${this.tag}] DataLoadListener ${dispatchLabel} failed at index ${index}: ${this.describeListenerError(error)}`,
        );
      }
    });
  }

  private notifyDataLoaded(items: Array<HybridTimelineItem>, hasMore: boolean): void {
    if (this.pinchFreezeState.active) {
      this.pinchFreezeState.queuedDataLoaded = true;
      return;
    }
    this.dispatchDataLoadListeners('onDataLoaded', (listener: DataLoadListener) => {
      listener.onDataLoaded?.(items, hasMore);
    });
  }

  private notifyDataLoadError(error: string): void {
    if (this.pinchFreezeState.active) {
      this.pinchFreezeState.queuedError = error;
      return;
    }
    this.dispatchDataLoadListeners('onDataLoadError', (listener: DataLoadListener) => {
      listener.onDataLoadError?.(error);
    });
  }

  private notifyDataLoading(isLoading: boolean): void {
    if (this.pinchFreezeState.active) {
      this.pinchFreezeState.queuedLoadingDirty = true;
      this.pinchFreezeState.queuedLoadingState = isLoading;
      return;
    }
    this.dispatchDataLoadListeners('onDataLoading', (listener: DataLoadListener) => {
      listener.onDataLoading?.(isLoading);
    });
  }

  public setRequestSize(requestSize: number): void {
    this.requestSize = Math.max(96, requestSize);
  }

  public setPrefetchOwnedByActiveRuntime(enabled: boolean): void {
    this.prefetchOwnedByActiveRuntime = enabled;
  }

  // ========== Getter ==========

  public getSections(): Array<HybridPhotoSection> {
    return this.sections;
  }

  public getYearBuckets(): Array<HybridBucketInfo> {
    return this.yearBuckets;
  }

  public getMonthBuckets(): Array<HybridBucketInfo> {
    return this.monthBuckets;
  }

  public getGroupDayGroups(): Array<HybridGroupInfo> {
    return this.groupDayGroups;
  }

  public getWindowStartOffset(): number {
    return this.windowStartOffset;
  }

  public getWindowEndOffset(): number {
    return this.windowEndOffset;
  }

  public getNextOffset(): number {
    return this.nextOffset;
  }

  public adoptPrefetchedPageCursor(
    windowEndOffset: number,
    nextOffset: number,
    hasMore: boolean,
  ): void {
    const previousWindowEndOffset = this.windowEndOffset;
    const previousNextOffset = this.nextOffset;
    const advancedWindow = windowEndOffset > previousWindowEndOffset;
    const advancedNextOffset = nextOffset > previousNextOffset;

    if (advancedWindow) {
      this.windowEndOffset = windowEndOffset;
    }
    if (advancedNextOffset) {
      this.nextOffset = nextOffset;
    }

    if (!hasMore && (advancedWindow || advancedNextOffset)) {
      this.hasMore = false;
      return;
    }

    if (advancedWindow || advancedNextOffset) {
      this.hasMore = hasMore;
    }
  }

  public getAllTimelineItems(): Array<HybridTimelineItem> {
    return this.allTimelineItems;
  }

  public getHasMore(): boolean {
    return this.hasMore;
  }

  public getIsLoading(): boolean {
    return this.isLoading;
  }

  public getIsLoadingMore(): boolean {
    return this.isLoadingMore;
  }

  public getErrorText(): string {
    return this.errorText;
  }

  public getGridColumns(): number {
    return this.gridColumns;
  }

  private applyGridColumns(columns: number, commitState?: HybridGridColumnsCommitState): boolean {
    if (this.gridColumns === columns) {
      return false;
    }
    this.gridColumns = columns;
    this.sections = this.timelineBuilder.reflowSections(this.sections, this.gridColumns);
    this.timelineBuilder.resetLayoutIds();
    this.allTimelineItems = this.timelineBuilder.buildTimelineItems(this.sections, this.gridColumns);
    this.updateLoadedPhotoRowCount();
    if (commitState) {
      const maxRowIndex = Math.max(0, this.allTimelineItems.length - 1);
      const safeTargetFirstRowIndex = Math.max(0, Math.min(commitState.targetFirstRowIndex, maxRowIndex));
      const safeTargetAnchorRowIndex = Math.max(0, Math.min(commitState.targetAnchorRowIndex, maxRowIndex));
      this.lastVisibleStart = safeTargetFirstRowIndex;
      this.lastVisibleEnd = Math.max(safeTargetFirstRowIndex, safeTargetAnchorRowIndex);
      this.updateSlidingWindow(safeTargetFirstRowIndex);
    } else {
      this.updateSlidingWindow(this.lastVisibleStart);
    }
    return true;
  }

  public silentSetGridColumns(columns: number, commitState?: HybridGridColumnsCommitState): void {
    this.applyGridColumns(columns, commitState);
  }

  public setGridColumns(columns: number, commitState?: HybridGridColumnsCommitState): void {
    if (!this.applyGridColumns(columns, commitState)) {
      return;
    }
    this.notifyDataLoaded(this.allTimelineItems, this.hasMore);
  }

  public getFormFsm(): GridFormFsm {
    return this.formFsm;
  }

  public getPinchStateManager(): PinchStateManager {
    return this.pinchStateManager;
  }

  public getCurrentForm(): FormIndex {
    return this.currentForm;
  }

  // ========== 释放资源 ==========

  public release(): void {
    ThumbnailDisk.HybridScrollState.isScrolling = false;
    this.backgroundPredownloadToken += 1;
    this.backgroundPredownloadRunning = false;
    this.idleWorkToken += 1;
    this.pinchFreezeState.active = false;
    this.runwayTopUpInFlight = false;
    this.yearBuckets = [];
    this.monthBuckets = [];
    this.groupDayGroups = [];
    this.sections = [];
    this.allTimelineItems = [];
    this.pendingWarmupSections = [];
    this.windowStartOffset = 0;
    this.windowEndOffset = 0;
    this.nextOffset = 0;
    this.hasMore = true;
    this.isLoading = false;
    this.isLoadingMore = false;
    this.errorText = '';
    this.windowStartIndex = 0;
    this.windowEndIndex = -1;
    this.prefetchCursor = -1;
    this.lastLoadMoreTriggerAt = 0;
    this.lastVisibleStart = 0;
    this.lastVisibleEnd = 0;
    this.loadedPhotoRowCount = 0;
    this.visibleRowCapacity = 0;
    this.lastScrollPrefetchAt = 0;
    this.lastForwardPrefetchEnd = -1;
    this.lastBackwardPrefetchStart = Number.MAX_SAFE_INTEGER;
    this.lastViewportPruneAt = 0;
    this.pinchFreezeState.queuedVisibleStart = -1;
    this.pinchFreezeState.queuedVisibleEnd = -1;
    this.pinchFreezeState.queuedNeedsLoadMoreCheck = false;
    this.pinchFreezeState.queuedDataLoaded = false;
    this.pinchFreezeState.queuedLoadingDirty = false;
    this.pinchFreezeState.queuedLoadingState = false;
    this.pinchFreezeState.queuedError = undefined;
    this.dataLoadListeners = [];
    this.scrollStateListeners = [];
    this.pinchGestureListeners = [];
  }
}
