import { common } from '@kit.AbilityKit';
import * as Shared from '../HybridPhotoGridShared';
import * as Thumbnail from '../HybridPhotoThumbnail';
import { DataLoadListener, HybridDayGridVm, HybridGridColumnsCommitState } from './HybridDayGridVm';
import { HybridSwitchCalc } from './HybridSwitchCalc';
import {
  HybridFloatingSectionInfo,
  HybridPhotoGridDataAdapter,
} from '../adapter/HybridPhotoGridDataAdapter';
import { HybridPhotoGridActionAdapter } from '../adapter/HybridPhotoGridActionAdapter';
import {
  HybridPhotoGridAnchorAdapter,
  HybridPinchStateInfo,
  HybridPinchTargetDirection,
} from '../adapter/HybridPhotoGridAnchorAdapter';
import { HybridGridAttributeUpdater } from '../viewcontroller/HybridDayGridVc';
import { HybridGridSnapshotVc } from '../viewcontroller/HybridGridSnapshotVc';
import { HybridGridKind } from '../viewcontroller/HybridPhotoGridVc';

type HybridGridItem = Shared.HybridGridItem;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridTimelineItem = Shared.HybridTimelineItem;

const PINCH_RESET_DURATION_MS: number = 160;
const PINCH_STAGE_ONE_DURATION_MS: number = 90;
const PINCH_STAGE_TWO_DURATION_MS: number = 150;
const PINCH_COMMIT_FADE_DURATION_MS: number = 90;
const PINCH_COMMIT_RETRY_DELAY_MS: number = 16;
const PINCH_COMMIT_MAX_RETRIES: number = 24;
const PINCH_COMMIT_OFFSET_TOLERANCE: number = 1.5;
const PINCH_COMMIT_MAX_DURATION_MS: number = 160;
const IDLE_PREBUILD_DELAY_MS: number = 120;
const IDLE_PREBUILD_READY_RETRY_DELAY_MS: number = 32;
const IDLE_PREBUILD_OFFSET_TOLERANCE: number = 1.5;
const FADE_START_SCALE_DOWN: number = 1.06;
const FADE_START_SCALE_UP: number = 0.94;
const PINCH_SHRINK_ENTER_SCALE: number = 0.98;
const PINCH_SHRINK_CANCEL_SCALE: number = 1.01;
const PINCH_EXPAND_ENTER_SCALE: number = 1.02;
const PINCH_EXPAND_CANCEL_SCALE: number = 0.99;
const EXPAND_MIN_OPACITY: number = 0.15;

class HybridPreviewViewportRange {
  start: number = 0;
  end: number = -1;
}

enum HybridPinchCommitPhase {
  IDLE = 0,
  SETTLING = 1,
  SETTLED_WAIT_MAIN_READY = 2,
  FINALIZED = 3,
}

enum HybridCommitAlignPhase {
  INITIAL_ALIGN = 0,
  CORRECTIVE_ALIGN = 1,
  WAITING_READY = 2,
  FINALIZED = 3,
}

enum HybridCommittedLayerKind {
  MAIN = 0,
  PREVIEW = 1,
}

@Observed
export class HybridPhotoGridVm {
  private readonly context: common.UIAbilityContext;
  private readonly dataVm: HybridDayGridVm;
  private readonly dataAdapter: HybridPhotoGridDataAdapter = new HybridPhotoGridDataAdapter();
  public readonly actionAdapter: HybridPhotoGridActionAdapter = new HybridPhotoGridActionAdapter();
  private readonly anchorAdapter: HybridPhotoGridAnchorAdapter = new HybridPhotoGridAnchorAdapter();
  private stateListeners: Array<() => void> = [];

  // ── 3-Grid physical scrollers & data sources ──
  private scrollerA?: Scroller;
  private scrollerB?: Scroller;
  private scrollerC?: Scroller;
  private dataSourceA?: Shared.HybridGridDataSource;
  private dataSourceB?: Shared.HybridGridDataSource;
  private dataSourceC?: Shared.HybridGridDataSource;
  private timelineDataSource?: Shared.HybridTimelineDataSource;
  private snapshotController?: HybridGridSnapshotVc;
  private pinchState?: HybridPinchStateInfo;
  private initialized: boolean = false;
  private timelineInitialized: boolean = false;
  private lastAppliedColumns: number = Shared.HYBRID_GRID_COLUMNS;
  private stageOneTimeoutId?: number;
  private stageTwoTimeoutId?: number;
  private commitSyncTimeoutId?: number;
  private renderedGridVersion: number = 0;
  private previewVisibleStartIndex: number = -1;
  private previewVisibleEndIndex: number = -1;
  private idlePrebuildTimeoutId?: number;
  private idlePrebuildSyncTimeoutId?: number;
  private idlePrebuildToken: number = 0;
  private idlePrebuildColumns: number = Shared.HYBRID_GRID_COLUMNS;
  private idlePrebuildFillPosition: number = 0;
  private idlePrebuildTargetScrollOffset: number = 0;
  private idlePrebuildTargetFirstPhotoIndex: number = 0;
  private idlePrebuildTargetAnchorPhotoIndex: number = 0;
  private idlePrebuildTargetFirstRowIndex: number = 0;
  private idlePrebuildTargetAnchorRowIndex: number = 0;
  private idlePrebuildResolvedFocusX: number = 0;
  private idlePrebuildResolvedFocusY: number = 0;
  private idlePrebuildTargetBaseScale: number = 1;
  private idlePrebuildVersion: number = -1;
  private idlePrebuildStructureReady: boolean = false;
  private idlePrebuildVisibleRowsWarm: boolean = false;
  private idlePrebuildReady: boolean = false;
  private idlePrebuildBaselineScrollOffset: number = 0;
  private idlePrebuildInvalidatedByScroll: boolean = false;
  // ── Idle expand pre-build state ──
  private idleExpandTimeoutId?: number;
  private idleExpandSyncTimeoutId?: number;
  private idleExpandToken: number = 0;
  private idleExpandColumns: number = 0;
  private idleExpandFillPosition: number = 0;
  private idleExpandTargetScrollOffset: number = 0;
  private idleExpandTargetFirstPhotoIndex: number = 0;
  private idleExpandTargetAnchorPhotoIndex: number = 0;
  private idleExpandTargetFirstRowIndex: number = 0;
  private idleExpandTargetAnchorRowIndex: number = 0;
  private idleExpandResolvedFocusX: number = 0;
  private idleExpandResolvedFocusY: number = 0;
  private idleExpandTargetBaseScale: number = 1;
  private idleExpandVersion: number = -1;
  private idleExpandStructureReady: boolean = false;
  private idleExpandVisibleRowsWarm: boolean = false;
  private idleExpandReady: boolean = false;
  private idleExpandBaselineScrollOffset: number = 0;
  private idleExpandInvalidatedByScroll: boolean = false;
  private idleExpandGridItems: Array<HybridGridItem> = [];
  private lastIdleExpandVisiblePrefetchKey: string = '';
  private pendingCommit?: HybridGridColumnsCommitState;
  private pendingCommitRetryCount: number = 0;
  private pendingCommitScrollOffset: number = 0;
  private mainVisibleStartIndex: number = -1;
  private mainVisibleEndIndex: number = -1;
  private mainCommitOffsetReady: boolean = false;
  private mainCommitIndexReady: boolean = false;
  private mainVisibleRowsWarm: boolean = false;
  private mainFirstPaintArmed: boolean = false;
  private mainFirstPaintStableCount: number = 0;
  private mainFirstPaintReady: boolean = false;
  private mainGridCommitReady: boolean = false;
  private mainFirstPaintTimeoutId?: number;
  private commitPhase: HybridPinchCommitPhase = HybridPinchCommitPhase.IDLE;
  private commitStartedAt: number = 0;
  private commitDeadlineMs: number = 0;
  private commitAlignPhase: HybridCommitAlignPhase = HybridCommitAlignPhase.FINALIZED;
  private latchedTargetActive: boolean = false;
  private latchedTargetColumns: number = Shared.HYBRID_GRID_COLUMNS;
  private latchedTargetDirection: HybridPinchTargetDirection = HybridPinchTargetDirection.NONE;
  private latchedFillPosition: number = 0;
  private latchedTargetScrollOffset: number = 0;
  private latchedTargetFirstPhotoIndex: number = 0;
  private latchedTargetAnchorPhotoIndex: number = 0;
  private latchedTargetFirstRowIndex: number = 0;
  private latchedTargetAnchorRowIndex: number = 0;
  private latchedResolvedFocusX: number = 0;
  private latchedResolvedFocusY: number = 0;
  private latchedTargetBaseScale: number = 1;
  private lastPreviewOverscanPrefetchKey: string = '';
  private lastMainOverscanPrefetchKey: string = '';
  private lastIdleVisiblePrefetchKey: string = '';
  private lastIdleOverscanPrefetchKey: string = '';
  private lastShrinkPrewarmPrefetchKey: string = '';
  private visibleStateKey: string = '';
  private suppressDeferredDataVmSyncCount: number = 0;
  private committedFillPosition: number = 0;

  public sections: Array<HybridPhotoSection> = [];
  public currentItems: Array<HybridTimelineItem> = [];
  public previewItems: Array<HybridTimelineItem> = [];
  public currentGridItems: Array<HybridGridItem> = [];
  @Track public itemCount: number = 0;
  @Track public hasCompletedFirstLoad: boolean = false;
  @Track public isLoading: boolean = true;
  @Track public isLoadingMore: boolean = false;
  @Track public hasMore: boolean = true;
  @Track public errorText: string = '';
  @Track public floatingSectionTitle: string = '';
  @Track public floatingSectionCount: number = 0;
  @Track public listWidth: number = 0;
  @Track public listHeight: number = 0;
  @Track public gridColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @Track public currentScrollOffsetY: number = 0;
  @Track public pinchActive: boolean = false;
  @Track public pinchCenterX: number = 0;
  @Track public pinchCenterY: number = 0;
  @Track public hasPendingCommit: boolean = false;
  @Track public committedLayerKind: HybridCommittedLayerKind = HybridCommittedLayerKind.PREVIEW;

  // ── 3-Grid per-physical-grid @Track state ──
  // Grid A (initial role: shrinkTarget — dormant)
  @Track public gridColumnsA: number = Shared.HYBRID_GRID_COLUMNS;
  @Track public gridScaleA: number = 1;
  @Track public gridOpacityA: number = 0;
  @Track public gridVisibleA: boolean = false;
  @Track public gridWarmActiveA: boolean = false;
  @Track public gridInteractiveA: boolean = false;
  @Track public gridZIndexA: number = 100;
  // Grid B (initial role: currentGrid — active)
  @Track public gridColumnsB: number = Shared.HYBRID_GRID_COLUMNS;
  @Track public gridScaleB: number = 1;
  @Track public gridOpacityB: number = 1;
  @Track public gridVisibleB: boolean = true;
  @Track public gridWarmActiveB: boolean = false;
  @Track public gridInteractiveB: boolean = true;
  @Track public gridZIndexB: number = 200;
  // Grid C (initial role: expandTarget — dormant)
  @Track public gridColumnsC: number = 0;
  @Track public gridScaleC: number = 1;
  @Track public gridOpacityC: number = 0;
  @Track public gridVisibleC: boolean = false;
  @Track public gridWarmActiveC: boolean = false;
  @Track public gridInteractiveC: boolean = false;
  @Track public gridZIndexC: number = 100;

  // ── Role tracking ──
  @Track public currentGridKind: HybridGridKind = HybridGridKind.B;
  public shrinkTargetKind: HybridGridKind = HybridGridKind.A;
  public expandTargetKind: HybridGridKind = HybridGridKind.C;
  @Track public readonly gridAttributeUpdaterA: HybridGridAttributeUpdater = new HybridGridAttributeUpdater();
  @Track public readonly gridAttributeUpdaterB: HybridGridAttributeUpdater = new HybridGridAttributeUpdater();
  @Track public readonly gridAttributeUpdaterC: HybridGridAttributeUpdater = new HybridGridAttributeUpdater();

  private readonly dataLoadListener: DataLoadListener = {
    onDataLoaded: (): void => {
      this.syncFromDataVmSafely('onDataLoaded', this.shouldSuppressDeferredDataVmSync());
      this.hasCompletedFirstLoad = true;
    },
    onDataLoadError: (error: string): void => {
      this.syncFromDataVmSafely('onDataLoadError', this.shouldSuppressDeferredDataVmSync());
      this.errorText = error;
      this.notifyStateChanged();
      this.hasCompletedFirstLoad = true;
    },
    onDataLoading: (isLoading: boolean): void => {
      this.syncFromDataVmSafely(
        isLoading ? 'onDataLoading(true)' : 'onDataLoading(false)',
        this.shouldSuppressDeferredDataVmSync(),
      );
      if (!isLoading) {
        this.hasCompletedFirstLoad = true;
      }
    },
  };

  public constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.dataVm = new HybridDayGridVm(context, 0);
    this.initializeGridAttributeUpdaters();
    this.refreshGridRoleZIndices();
  }

  public bindSnapshotController(snapshotController: HybridGridSnapshotVc): void {
    this.snapshotController = snapshotController;
  }

  public bindTimelineDataSource(dataSource: Shared.HybridTimelineDataSource): void {
    this.timelineDataSource = dataSource;
    this.timelineDataSource.replaceAll(this.currentItems.slice());
    this.timelineInitialized = true;
    this.lastAppliedColumns = this.getActiveColumns();
  }

  public addStateListener(listener: () => void): void {
    if (this.stateListeners.indexOf(listener) >= 0) {
      return;
    }
    this.stateListeners.push(listener);
  }

  public removeStateListener(listener: () => void): void {
    this.stateListeners = this.stateListeners.filter((item: () => void) => item !== listener);
  }

  public async init(): Promise<void> {
    if (this.initialized) {
      return;
    }

    this.initialized = true;
    this.dataVm.addDataLoadListener(this.dataLoadListener);
    this.suppressDeferredDataVmSyncCount = 0;
    this.hasCompletedFirstLoad = false;
    this.isLoading = true;
    this.errorText = '';
    this.itemCount = 0;
    await this.reload();
  }

  public release(): void {
    this.cancelPendingAnimations();
    this.clearIdlePrebuildState(true);
    this.clearIdleExpandPrebuildState();
    this.itemCount = 0;
    this.hasCompletedFirstLoad = false;
    this.sections = [];
    this.currentItems = [];
    this.previewItems = [];
    this.currentGridItems = [];
    this.dataVm.removeDataLoadListener(this.dataLoadListener);
    this.dataVm.release();
    this.dataSourceA?.updateAllIfChanged([]);
    this.dataSourceB?.updateAllIfChanged([]);
    this.dataSourceC?.updateAllIfChanged([]);
    this.timelineDataSource?.replaceAll([]);
    this.snapshotController?.hideSnapshot();
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.pendingCommit = undefined;
    this.hasPendingCommit = false;
    this.pendingCommitRetryCount = 0;
    this.pendingCommitScrollOffset = 0;
    this.mainVisibleStartIndex = -1;
    this.mainVisibleEndIndex = -1;
    this.mainCommitOffsetReady = false;
    this.mainCommitIndexReady = false;
    this.mainVisibleRowsWarm = false;
    this.mainFirstPaintArmed = false;
    this.mainFirstPaintStableCount = 0;
    this.mainFirstPaintReady = false;
    this.mainGridCommitReady = false;
    this.commitPhase = HybridPinchCommitPhase.IDLE;
    this.commitStartedAt = 0;
    this.commitDeadlineMs = 0;
    this.commitAlignPhase = HybridCommitAlignPhase.FINALIZED;
    this.resetLatchedPinchTarget();
    this.resetPrefetchKeys();
    this.suppressDeferredDataVmSyncCount = 0;
    this.visibleStateKey = '';
    this.committedFillPosition = 0;
    this.dataSourceA = undefined;
    this.dataSourceB = undefined;
    this.dataSourceC = undefined;
    this.stateListeners = [];
    this.initialized = false;
    this.timelineInitialized = false;
  }

  public async reload(): Promise<void> {
    this.suppressDeferredDataVmSyncCount = 0;
    this.hasCompletedFirstLoad = false;
    this.isLoading = true;
    this.errorText = '';
    try {
      await this.dataVm.reload();
    } catch (error) {
      console.error(`[HybridPhotoGridVm] reload failed: ${this.describeSyncError(error)}`);
      this.isLoading = false;
      this.errorText = 'Hybrid photo data load failed';
      this.hasCompletedFirstLoad = true;
      this.notifyStateChanged();
      return;
    }
    this.syncFromDataVmSafely('reload', false);
    if (!this.isLoading) {
      this.hasCompletedFirstLoad = true;
    }
  }

  public onGridAreaChange(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }

    const widthChanged = Math.abs(this.listWidth - width) > 0.5;
    const heightChanged = Math.abs(this.listHeight - height) > 0.5;
    this.listWidth = width;
    this.listHeight = height;
    this.syncDataVmRequestSize();

    if (widthChanged || heightChanged) {
      this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
      if (
        this.commitPhase === HybridPinchCommitPhase.SETTLING ||
        this.commitPhase === HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY
      ) {
        this.schedulePendingCommitSync(0);
      }
      this.notifyStateChanged();
    }
  }

  public onScrollStart(): void {
    if (this.committedLayerKind !== HybridCommittedLayerKind.MAIN) {
      return;
    }
    this.syncCurrentScrollOffset();
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    if (this.idleExpandTimeoutId !== undefined) {
      clearTimeout(this.idleExpandTimeoutId);
      this.idleExpandTimeoutId = undefined;
    }
    this.dataVm.onScrollStart();
  }

  public onScrollStop(): void {
    if (this.committedLayerKind !== HybridCommittedLayerKind.MAIN) {
      return;
    }
    this.syncCurrentScrollOffset();
    this.dataVm.onScrollStop();
    this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
    this.scheduleIdleExpandPrebuild(IDLE_PREBUILD_DELAY_MS);
    this.logMemoryDebug('scroll-stop');
  }

  public onScrollIndex(start: number, end: number): void {
    if (this.committedLayerKind !== HybridCommittedLayerKind.MAIN) {
      return;
    }
    this.mainVisibleStartIndex = Math.max(0, start);
    this.mainVisibleEndIndex = Math.max(this.mainVisibleStartIndex, end);
    this.syncCurrentScrollOffset();
    const idleStateChanged = this.invalidateIdlePrebuildForScrollOffset();
    const idleExpandStateChanged = this.invalidateIdleExpandForScrollOffset();
    if (
      this.pendingCommit &&
      (this.commitPhase === HybridPinchCommitPhase.SETTLING ||
        this.commitPhase === HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY) &&
      this.commitSyncTimeoutId === undefined
    ) {
      this.schedulePendingCommitSync(0);
    }
    const rowStart = this.resolveTimelineRowIndexFromGridIndex(start, 0);
    const rowEnd = this.resolveTimelineRowIndexFromGridIndex(end, 0);
    this.updateFloatingSection(rowStart);
    this.dataVm.onScrollIndex(rowStart, rowEnd);
    if (idleStateChanged || idleExpandStateChanged) {
      this.notifyStateChanged();
      return;
    }
    this.notifyStateChanged();
  }

  public onPreviewScrollStart(): void {
    if (this.committedLayerKind !== HybridCommittedLayerKind.PREVIEW) {
      return;
    }
    this.syncCurrentScrollOffset();
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    if (this.idleExpandTimeoutId !== undefined) {
      clearTimeout(this.idleExpandTimeoutId);
      this.idleExpandTimeoutId = undefined;
    }
    this.dataVm.onScrollStart();
  }

  public onPreviewScrollStop(): void {
    if (this.committedLayerKind !== HybridCommittedLayerKind.PREVIEW) {
      return;
    }
    this.syncCurrentScrollOffset();
    this.dataVm.onScrollStop();
    this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
    this.scheduleIdleExpandPrebuild(IDLE_PREBUILD_DELAY_MS);
  }

  public onPreviewScrollIndex(start: number, end: number): void {
    this.previewVisibleStartIndex = Math.max(0, start);
    this.previewVisibleEndIndex = Math.max(this.previewVisibleStartIndex, end);
    if (this.committedLayerKind === HybridCommittedLayerKind.PREVIEW) {
      this.syncCurrentScrollOffset();
      const idleStateChanged = this.invalidateIdlePrebuildForScrollOffset();
      const idleExpandStateChanged = this.invalidateIdleExpandForScrollOffset();
      if (
        this.pendingCommit &&
        (this.commitPhase === HybridPinchCommitPhase.SETTLING ||
          this.commitPhase === HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY) &&
        this.commitSyncTimeoutId === undefined
      ) {
        this.schedulePendingCommitSync(0);
      }
      const fillPosition = this.resolveCommittedFillPosition();
      const rowStart = this.resolveTimelineRowIndexFromGridIndex(start, fillPosition);
      const rowEnd = this.resolveTimelineRowIndexFromGridIndex(end, fillPosition);
      this.updateFloatingSection(rowStart);
      this.dataVm.onScrollIndex(rowStart, rowEnd);
      this.notifyStateChanged();
    }
  }

  public onPinchStart(centerX: number, centerY: number): void {
    if (this.listWidth <= 0 || this.listHeight <= 0) {
      return;
    }

    const activeColumns = this.getActiveColumns();
    this.cancelPendingAnimations();
    this.suppressDeferredDataVmSyncCount = 0;
    this.syncCurrentScrollOffset();
    this.normalizeCommittedPreviewLayerForPinchStart();
    this.dataVm.beginPinchFreeze();
    this.syncCurrentScrollOffset();
    this.dataVm.handlePinchStart(centerX, centerY);
    const totalPhotoCount = this.dataAdapter.flattenAssets(this.sections).length;
    this.pinchState = this.anchorAdapter.createPinchState(
      activeColumns,
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      this.getBaseTopInsetHeight(),
      totalPhotoCount,
    );
    this.pinchActive = true;
    this.pinchCenterX = centerX;
    this.pinchCenterY = centerY;
    this.resetLatchedPinchTarget();
    this.resetPreviewTransactionState();
    this.setActiveVisible(true);
    this.setActiveOpacity(1);
    this.setActiveScale(1);
    this.setShrinkTargetVisible(false);
    this.setShrinkTargetOpacity(0);
    this.setShrinkTargetScale(1);
    this.setShrinkTargetWarmActive(false);
    this.setExpandTargetVisible(false);
    this.setExpandTargetOpacity(0);
    this.setExpandTargetScale(1);
    this.setExpandTargetWarmActive(false);
    this.refreshGridRoleZIndices();
    if (this.idleExpandTimeoutId !== undefined) {
      clearTimeout(this.idleExpandTimeoutId);
      this.idleExpandTimeoutId = undefined;
    }
    if (this.idleExpandSyncTimeoutId !== undefined) {
      clearTimeout(this.idleExpandSyncTimeoutId);
      this.idleExpandSyncTimeoutId = undefined;
    }
    this.pendingCommit = undefined;
    this.hasPendingCommit = false;
    this.pendingCommitRetryCount = 0;
    this.pendingCommitScrollOffset = 0;
    this.mainVisibleStartIndex = -1;
    this.mainVisibleEndIndex = -1;
    this.mainCommitOffsetReady = false;
    this.mainCommitIndexReady = false;
    this.mainVisibleRowsWarm = false;
    this.mainFirstPaintArmed = false;
    this.mainFirstPaintStableCount = 0;
    this.mainFirstPaintReady = false;
    this.mainGridCommitReady = false;
    this.commitPhase = HybridPinchCommitPhase.IDLE;
    this.commitStartedAt = 0;
    this.commitDeadlineMs = 0;
    this.commitAlignPhase = HybridCommitAlignPhase.FINALIZED;
    this.snapshotController?.hideSnapshot();

    this.notifyStateChanged();
  }

  public onPinchUpdate(scale: number, centerX: number, centerY: number): void {
    if (!this.pinchActive || !this.pinchState) {
      return;
    }

    this.dataVm.handlePinchUpdate(scale, centerX, centerY);
    this.anchorAdapter.updatePinchState(this.pinchState, scale, centerX, centerY);
    this.reconcileLatchedPinchTarget(this.pinchState);
    const activeColumns = this.getActiveColumns();
    // Cap the display scale at the one-step arrival boundary once the target is latched.
    // This prevents the gesture from visually overshooting into the next step;
    // further pinching has no effect until the user releases and starts a new gesture.
    const displayLiveScale = this.resolveDisplayLiveScale(this.pinchState);
    this.pinchCenterX = this.pinchState.sharedCenterX;
    this.pinchCenterY = this.pinchState.sharedCenterY;
    this.setActiveVisible(true);
    this.setActiveScale(displayLiveScale);
    this.setActiveOpacity(1);

    if (this.pinchState.targetColumns !== activeColumns) {
      if (this.pinchState.targetDirection === HybridPinchTargetDirection.EXPAND) {
        this.refreshGridRoleZIndices(this.expandTargetKind);
        if (!this.isDormantLayerPreparedForTarget(this.pinchState)) {
          if (
            this.idleExpandStructureReady &&
            this.idleExpandColumns === this.pinchState.targetColumns &&
            this.idleExpandGridItems.length > this.pinchState.fillPosition
          ) {
            const dormantScroller = this.resolveExpandTargetScroller();
            const dormantDataSource = this.resolveExpandTargetDataSource();
            if (dormantScroller && dormantDataSource) {
              dormantDataSource.updateAllIfChanged(this.idleExpandGridItems);
              try {
                dormantScroller.scrollTo({ xOffset: 0, yOffset: this.idleExpandTargetScrollOffset });
              } catch (_error) {}
              this.setExpandTargetColumns(this.pinchState.targetColumns);
              this.setExpandTargetWarmActive(true);
            }
          } else {
            this.buildTargetGridOnDormantLayer(this.pinchState);
          }
        }
        const displayDormantScale = this.pinchState.targetBaseScale * displayLiveScale;
        this.setExpandTargetVisible(true);
        this.setExpandTargetWarmActive(true);
        this.setExpandTargetScale(displayDormantScale);
        const expandFadeStart = this.pinchState.targetBaseScale;
        const expandFadeRange = Math.max(0.001, 1.0 - expandFadeStart);
        const rawOpacity = Math.min(1, Math.max(0, (displayDormantScale - expandFadeStart) / expandFadeRange));
        this.setExpandTargetOpacity(
          Math.min(1, EXPAND_MIN_OPACITY + (1.0 - EXPAND_MIN_OPACITY) * rawOpacity),
        );
        this.setShrinkTargetVisible(false);
        this.setShrinkTargetOpacity(0);
        this.notifyStateChanged();
        return;
      }

      if (this.pinchState.targetDirection !== HybridPinchTargetDirection.SHRINK) {
        this.resetLatchedPinchTarget();
        this.resetPreviewTransactionState();
        this.resetPinchTargetToCurrentGrid(this.pinchState);
        this.pinchCenterX = this.pinchState.pinchCenterX;
        this.pinchCenterY = this.pinchState.pinchCenterY;
        this.setActiveVisible(true);
        this.setActiveScale(1);
        this.setActiveOpacity(1);
        this.setShrinkTargetVisible(false);
        this.setShrinkTargetOpacity(0);
        this.setShrinkTargetScale(1);
        this.setExpandTargetVisible(false);
        this.setExpandTargetOpacity(0);
        this.setExpandTargetScale(1);
        this.refreshGridRoleZIndices();
        this.notifyStateChanged();
        return;
      }

      if (!this.ensureIdlePrebuildStructureForPinch(this.pinchState)) {
        this.resetLatchedPinchTarget();
        this.resetPreviewTransactionState();
        this.resetPinchTargetToCurrentGrid(this.pinchState);
        this.pinchCenterX = this.pinchState.pinchCenterX;
        this.pinchCenterY = this.pinchState.pinchCenterY;
        this.setActiveVisible(true);
        this.setActiveScale(1);
        this.setActiveOpacity(1);
        this.setShrinkTargetVisible(false);
        this.setShrinkTargetOpacity(0);
        this.setShrinkTargetScale(1);
        this.setExpandTargetVisible(false);
        this.setExpandTargetOpacity(0);
        this.setExpandTargetScale(1);
        this.refreshGridRoleZIndices();
        this.notifyStateChanged();
        return;
      }

      this.refreshGridRoleZIndices(this.shrinkTargetKind);
      const shrinkProgress = Math.min(
        1,
        Math.max(0, (PINCH_SHRINK_ENTER_SCALE - this.pinchState.liveScale) / Math.max(0.001, PINCH_SHRINK_ENTER_SCALE - 0.75)),
      );
      this.setShrinkTargetVisible(true);
      this.setShrinkTargetWarmActive(true);
      this.setShrinkTargetScale(this.pinchState.targetBaseScale * displayLiveScale);
      this.setShrinkTargetOpacity(shrinkProgress);
      this.setExpandTargetVisible(false);
      this.setExpandTargetOpacity(0);
      this.notifyStateChanged();
      return;
    }

    this.resetLatchedPinchTarget();
    this.resetPreviewTransactionState();
    this.pinchCenterX = this.pinchState.pinchCenterX;
    this.pinchCenterY = this.pinchState.pinchCenterY;
    this.setActiveVisible(true);
    this.setActiveOpacity(1);
    this.setActiveScale(1);
    this.setShrinkTargetVisible(false);
    this.setShrinkTargetOpacity(0);
    this.setShrinkTargetScale(1);
    this.setExpandTargetVisible(false);
    this.setExpandTargetOpacity(0);
    this.setExpandTargetScale(1);
    this.refreshGridRoleZIndices();
    this.notifyStateChanged();
  }

  public onPinchEnd(): void {
    if (!this.pinchActive) {
      return;
    }

    this.dataVm.handlePinchEnd();
    this.pinchActive = false;

    const activePinchState = this.pinchState;
    if (activePinchState && activePinchState.targetColumns !== this.getActiveColumns()) {
      this.runPinchTransition(activePinchState);
      return;
    }

    this.animateResetToCurrentGrid();
  }

  public async openAssetViewer(assetIndex: number): Promise<void> {
    const item = this.currentGridItems[assetIndex];
    if (!item || !item.asset) {
      return;
    }
    await this.actionAdapter.openAssetViewer(this.sections, item.asset);
  }

  public async openPreviewAssetViewer(asset: Shared.HybridPhotoAsset): Promise<void> {
    await this.actionAdapter.openAssetViewer(this.sections, asset);
  }

  public shouldShowInitialLoading(): boolean {
    return !this.hasCompletedFirstLoad && this.isLoading;
  }

  public shouldShowInitialError(): boolean {
    return this.hasCompletedFirstLoad && !!this.errorText && this.itemCount <= 0;
  }

  public shouldShowNoData(): boolean {
    return this.hasCompletedFirstLoad && !this.isLoading && !this.errorText && this.itemCount <= 0;
  }

  public isNoDataVisible(): boolean {
    return this.shouldShowNoData();
  }

  public resolveRequestSizeForKind(kind: HybridGridKind): number {
    const cols = Math.max(1, this.resolveColumns(kind) > 0 ? this.resolveColumns(kind) : this.getCurrentColumns());
    const role = kind === this.currentGridKind
      ? Shared.HybridThumbnailLayerRole.ACTIVE
      : Shared.HybridThumbnailLayerRole.WARM;
    return Shared.resolveHybridRequestSizeBucket(cols, this.listWidth, role);
  }

  private resolveActiveRequestSize(): number {
    return Shared.resolveHybridRequestSizeBucket(
      Math.max(1, this.getActiveColumns()),
      this.listWidth,
      Shared.HybridThumbnailLayerRole.ACTIVE,
    );
  }

  private resolveTargetKindForDirection(direction: HybridPinchTargetDirection): HybridGridKind {
    if (direction === HybridPinchTargetDirection.SHRINK) {
      return this.shrinkTargetKind;
    }
    return this.expandTargetKind;
  }

  private resolveTargetScrollerForDirection(direction: HybridPinchTargetDirection): Scroller | undefined {
    return this.resolveScroller(this.resolveTargetKindForDirection(direction));
  }

  private resolveTargetDataSourceForDirection(direction: HybridPinchTargetDirection): Shared.HybridGridDataSource | undefined {
    return this.resolveDataSource(this.resolveTargetKindForDirection(direction));
  }

  private resolveTargetColumnsForDirection(direction: HybridPinchTargetDirection): number {
    return this.resolveColumns(this.resolveTargetKindForDirection(direction));
  }

  private setTargetColumnsForDirection(direction: HybridPinchTargetDirection, value: number): void {
    this.setColumns(this.resolveTargetKindForDirection(direction), value);
  }

  private setTargetWarmActiveForDirection(direction: HybridPinchTargetDirection, value: boolean): void {
    this.setWarmActive(this.resolveTargetKindForDirection(direction), value);
  }

  private setTargetVisibleForDirection(direction: HybridPinchTargetDirection, value: boolean): void {
    this.setVisible(this.resolveTargetKindForDirection(direction), value);
  }

  private setTargetOpacityForDirection(direction: HybridPinchTargetDirection, value: number): void {
    this.setOpacity(this.resolveTargetKindForDirection(direction), value);
  }

  private setTargetScaleForDirection(direction: HybridPinchTargetDirection, value: number): void {
    this.setScale(this.resolveTargetKindForDirection(direction), value);
  }

  private isDormantLayerPreparedForTarget(state: HybridPinchStateInfo): boolean {
    if (this.resolveTargetColumnsForDirection(state.targetDirection) !== state.targetColumns) {
      return false;
    }
    const dormantDataSource = this.resolveTargetDataSourceForDirection(state.targetDirection);
    return (dormantDataSource?.totalCount() ?? 0) > state.fillPosition;
  }

  private buildTargetGridOnDormantLayer(state: HybridPinchStateInfo): void {
    const previewGridItems = this.dataAdapter.buildGridItemsForColumns(
      this.sections,
      state.targetColumns,
      0,
      this.hasMore,
      state.fillPosition,
      true,
    );

    const dormantScroller = this.resolveTargetScrollerForDirection(state.targetDirection);
    const dormantDataSource = this.resolveTargetDataSourceForDirection(state.targetDirection);
    if (!dormantScroller || !dormantDataSource) {
      return;
    }
    dormantDataSource.updateAllIfChanged(previewGridItems);
    try {
      dormantScroller.scrollTo({ xOffset: 0, yOffset: state.targetScrollOffset });
    } catch (_error) {}
    this.setTargetColumnsForDirection(state.targetDirection, state.targetColumns);
    this.setTargetWarmActiveForDirection(state.targetDirection, true);
  }

  private syncDataVmRequestSize(): void {
    this.dataVm.setRequestSize(this.resolveActiveRequestSize());
  }

  private resetPreviewTransactionState(): void {
    this.previewItems = [];
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.lastPreviewOverscanPrefetchKey = '';
    this.lastMainOverscanPrefetchKey = '';
  }

  private resetLatchedPinchTarget(): void {
    this.latchedTargetActive = false;
    this.latchedTargetColumns = this.getActiveColumns();
    this.latchedTargetDirection = HybridPinchTargetDirection.NONE;
    this.latchedFillPosition = 0;
    this.latchedTargetScrollOffset = 0;
    this.latchedTargetFirstPhotoIndex = 0;
    this.latchedTargetAnchorPhotoIndex = 0;
    this.latchedTargetFirstRowIndex = 0;
    this.latchedTargetAnchorRowIndex = 0;
    this.latchedResolvedFocusX = 0;
    this.latchedResolvedFocusY = 0;
    this.latchedTargetBaseScale = 1;
  }

  private clearIdlePrebuildState(clearDataSource: boolean = false): void {
    const hadIdleDormantColumns = this.idlePrebuildColumns > 0;
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    if (this.idlePrebuildSyncTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildSyncTimeoutId);
      this.idlePrebuildSyncTimeoutId = undefined;
    }
    this.idlePrebuildToken += 1;
    this.idlePrebuildColumns = 0;
    this.idlePrebuildFillPosition = 0;
    this.idlePrebuildTargetScrollOffset = 0;
    this.idlePrebuildTargetFirstPhotoIndex = 0;
    this.idlePrebuildTargetAnchorPhotoIndex = 0;
    this.idlePrebuildTargetFirstRowIndex = 0;
    this.idlePrebuildTargetAnchorRowIndex = 0;
    this.idlePrebuildResolvedFocusX = 0;
    this.idlePrebuildResolvedFocusY = 0;
    this.idlePrebuildTargetBaseScale = 1;
    this.idlePrebuildVersion = -1;
    this.idlePrebuildStructureReady = false;
    this.idlePrebuildVisibleRowsWarm = false;
    this.idlePrebuildReady = false;
    this.idlePrebuildBaselineScrollOffset = 0;
    this.idlePrebuildInvalidatedByScroll = false;
    this.setShrinkTargetWarmActive(false);
    if (hadIdleDormantColumns) {
      this.setShrinkTargetColumns(0);
    }
    this.lastIdleVisiblePrefetchKey = '';
    this.lastIdleOverscanPrefetchKey = '';
    this.lastShrinkPrewarmPrefetchKey = '';
    this.resolveShrinkTargetDataSource()?.updateAllIfChanged([]);
    if (clearDataSource) {
      this.logMemoryDebug('idle-prebuild-cleared');
    }
  }

  private clearIdleExpandPrebuildState(): void {
    if (this.idleExpandTimeoutId !== undefined) {
      clearTimeout(this.idleExpandTimeoutId);
      this.idleExpandTimeoutId = undefined;
    }
    if (this.idleExpandSyncTimeoutId !== undefined) {
      clearTimeout(this.idleExpandSyncTimeoutId);
      this.idleExpandSyncTimeoutId = undefined;
    }
    this.idleExpandToken += 1;
    this.idleExpandColumns = 0;
    this.idleExpandFillPosition = 0;
    this.idleExpandTargetScrollOffset = 0;
    this.idleExpandTargetFirstPhotoIndex = 0;
    this.idleExpandTargetAnchorPhotoIndex = 0;
    this.idleExpandTargetFirstRowIndex = 0;
    this.idleExpandTargetAnchorRowIndex = 0;
    this.idleExpandResolvedFocusX = 0;
    this.idleExpandResolvedFocusY = 0;
    this.idleExpandTargetBaseScale = 1;
    this.idleExpandVersion = -1;
    this.idleExpandStructureReady = false;
    this.idleExpandVisibleRowsWarm = false;
    this.idleExpandReady = false;
    this.idleExpandBaselineScrollOffset = 0;
    this.idleExpandInvalidatedByScroll = false;
    this.idleExpandGridItems = [];
    this.lastIdleExpandVisiblePrefetchKey = '';
    this.setExpandTargetWarmActive(false);
    this.resolveExpandTargetDataSource()?.updateAllIfChanged([]);
  }

  private resetPrefetchKeys(): void {
    this.lastPreviewOverscanPrefetchKey = '';
    this.lastMainOverscanPrefetchKey = '';
    this.lastIdleVisiblePrefetchKey = '';
    this.lastIdleOverscanPrefetchKey = '';
    this.lastShrinkPrewarmPrefetchKey = '';
    this.lastIdleExpandVisiblePrefetchKey = '';
  }

  private resolveIdlePrebuildOffsetTolerance(columns: number): number {
    const itemSize = HybridSwitchCalc.calcItemSize(columns, this.listWidth);
    const itemExtent = itemSize + Shared.HYBRID_GRID_GAP;
    if (itemExtent <= 0) {
      return IDLE_PREBUILD_OFFSET_TOLERANCE;
    }
    return Math.max(IDLE_PREBUILD_OFFSET_TOLERANCE, itemExtent * 1.5);
  }

  private resolveIdlePrebuildAnchorTolerance(columns: number): number {
    return Math.max(1, columns * 2);
  }

  private isIdlePrebuildStructureReusable(state: HybridPinchStateInfo): boolean {
    if (
      !this.idlePrebuildStructureReady ||
      this.idlePrebuildInvalidatedByScroll ||
      !this.resolveShrinkTargetScroller() ||
      !this.resolveShrinkTargetDataSource() ||
      state.targetDirection !== HybridPinchTargetDirection.SHRINK
    ) {
      return false;
    }

    return this.isIdlePrebuildStateCompatible(
      state,
      this.resolveIdlePrebuildOffsetTolerance(state.targetColumns),
      this.resolveIdlePrebuildAnchorTolerance(state.targetColumns),
    );
  }

  private isIdlePrebuildStructureSynced(state: HybridPinchStateInfo): boolean {
    if (!this.isIdlePrebuildStructureReusable(state)) {
      return false;
    }

    return Math.abs(this.idlePrebuildTargetScrollOffset - state.targetScrollOffset) <= 0.5 &&
      this.idlePrebuildTargetFirstPhotoIndex === state.targetFirstPhotoIndex &&
      this.idlePrebuildTargetAnchorPhotoIndex === state.targetAnchorPhotoIndex &&
      this.idlePrebuildTargetFirstRowIndex === state.targetFirstRowIndex &&
      this.idlePrebuildTargetAnchorRowIndex === state.targetAnchorRowIndex;
  }

  private isIdlePrebuildStateCompatible(
    state: HybridPinchStateInfo,
    offsetTolerance: number,
    anchorTolerance: number,
  ): boolean {
    return this.idlePrebuildVersion === this.renderedGridVersion &&
      this.idlePrebuildColumns === state.targetColumns &&
      this.idlePrebuildFillPosition === state.fillPosition &&
      Math.abs(this.idlePrebuildTargetScrollOffset - state.targetScrollOffset) <= offsetTolerance &&
      Math.abs(this.idlePrebuildTargetAnchorPhotoIndex - state.targetAnchorPhotoIndex) <= anchorTolerance;
  }

  private invalidateIdlePrebuildForScrollOffset(): boolean {
    if (
      this.pinchActive ||
      this.pendingCommit !== undefined ||
      !this.idlePrebuildStructureReady ||
      this.idlePrebuildInvalidatedByScroll ||
      this.idlePrebuildColumns <= 0
    ) {
      return false;
    }

    const invalidationDistance = Math.abs(this.currentScrollOffsetY - this.idlePrebuildBaselineScrollOffset);
    if (invalidationDistance <= this.resolveIdlePrebuildOffsetTolerance(this.idlePrebuildColumns)) {
      return false;
    }

    this.idlePrebuildInvalidatedByScroll = true;
    this.idlePrebuildReady = false;
    this.idlePrebuildVisibleRowsWarm = false;
    return true;
  }

  private applyIdlePrebuildState(
    state: HybridPinchStateInfo,
    refreshDataSource: boolean,
  ): boolean {
    const dormantScroller = this.resolveShrinkTargetScroller();
    const dormantDataSource = this.resolveShrinkTargetDataSource();
    if (
      !dormantScroller ||
      !dormantDataSource ||
      state.targetDirection !== HybridPinchTargetDirection.SHRINK ||
      state.targetColumns === this.getActiveColumns()
    ) {
      return false;
    }

    if (refreshDataSource) {
      const previewGridItems = this.dataAdapter.buildGridItemsForColumns(
        this.sections,
        state.targetColumns,
        0,
        this.hasMore,
        state.fillPosition,
        true,
      );
      dormantDataSource.updateAllIfChanged(previewGridItems);
    }

    const offsetChanged = Math.abs(this.idlePrebuildTargetScrollOffset - state.targetScrollOffset) > 0.5;
    const didRebuildStructure = refreshDataSource ||
      !this.idlePrebuildStructureReady ||
      this.idlePrebuildVersion !== this.renderedGridVersion ||
      this.idlePrebuildColumns !== state.targetColumns ||
      this.idlePrebuildFillPosition !== state.fillPosition ||
      offsetChanged;

    this.idlePrebuildColumns = state.targetColumns;
  this.setShrinkTargetColumns(state.targetColumns);
    this.idlePrebuildFillPosition = state.fillPosition;
    this.idlePrebuildTargetScrollOffset = state.targetScrollOffset;
    this.idlePrebuildTargetFirstPhotoIndex = state.targetFirstPhotoIndex;
    this.idlePrebuildTargetAnchorPhotoIndex = state.targetAnchorPhotoIndex;
    this.idlePrebuildTargetFirstRowIndex = state.targetFirstRowIndex;
    this.idlePrebuildTargetAnchorRowIndex = state.targetAnchorRowIndex;
    this.idlePrebuildResolvedFocusX = state.resolvedFocusX;
    this.idlePrebuildResolvedFocusY = state.resolvedFocusY;
    this.idlePrebuildTargetBaseScale = state.targetBaseScale;
    this.idlePrebuildVersion = this.renderedGridVersion;
    this.idlePrebuildStructureReady = true;
    this.idlePrebuildBaselineScrollOffset = state.targetScrollOffset;
    this.idlePrebuildInvalidatedByScroll = false;
    if (didRebuildStructure) {
      this.idlePrebuildVisibleRowsWarm = false;
      this.idlePrebuildReady = false;
    }

    try {
      dormantScroller.scrollTo({ xOffset: 0, yOffset: this.idlePrebuildTargetScrollOffset });
    } catch (_error) {}

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      this.idlePrebuildStructureReady = false;
      this.idlePrebuildReady = false;
      return false;
    }

    const previewRange = this.resolveIdlePreviewPhotoRange(
      state.targetColumns,
      state.fillPosition,
      state.targetScrollOffset,
      assets.length,
    );
    const visibleKey = this.buildPrefetchRangeKey(
      'idle_preview',
      state.targetColumns,
      state.fillPosition,
      state.targetScrollOffset,
      previewRange,
    );
    if (visibleKey !== this.lastIdleVisiblePrefetchKey) {
      this.lastIdleVisiblePrefetchKey = visibleKey;
      this.prefetchPhotoRange(assets, previewRange, this.resolveRequestSizeForKind(this.shrinkTargetKind));
    }

    const token = ++this.idlePrebuildToken;
    this.scheduleIdlePrebuildReadinessCheck(token, this.idlePrebuildTargetScrollOffset);
    this.notifyStateChanged();
    return true;
  }

  private ensureIdlePrebuildStructureForPinch(state: HybridPinchStateInfo): boolean {
    if (state.targetDirection !== HybridPinchTargetDirection.SHRINK) {
      return false;
    }
    if (this.isIdlePrebuildStructureSynced(state)) {
      return true;
    }
    return this.applyIdlePrebuildState(state, !this.isIdlePrebuildStructureReusable(state));
  }

  private syncWarmLayerState(): void {
    const idleTargetActive = this.idlePrebuildColumns > 0 && this.idlePrebuildColumns !== this.getActiveColumns();
    const idlePrebuildPrepared =
      idleTargetActive &&
      this.idlePrebuildStructureReady &&
      !this.idlePrebuildInvalidatedByScroll &&
      this.idlePrebuildVersion >= 0 &&
      this.idlePrebuildColumns === this.getShrinkTargetColumns() &&
      this.idlePrebuildColumns !== this.getActiveColumns();
    this.setShrinkTargetWarmActive(
      idleTargetActive &&
      (
        idlePrebuildPrepared ||
        this.idlePrebuildReady ||
        this.pendingCommit !== undefined
      ),
    );
  }

  private resolveCommittedScroller(): Scroller | undefined {
    return this.resolveCurrentScroller();
  }

  private resolveCommittedGridDataSource(): Shared.HybridGridDataSource | undefined {
    return this.resolveCurrentDataSource();
  }

  private resolveCommittedVisibleStartIndex(): number {
    if (this.committedLayerKind === HybridCommittedLayerKind.PREVIEW) {
      return this.previewVisibleStartIndex;
    }
    return this.mainVisibleStartIndex;
  }

  private resolveCommittedVisibleEndIndex(): number {
    if (this.committedLayerKind === HybridCommittedLayerKind.PREVIEW) {
      return this.previewVisibleEndIndex;
    }
    return this.mainVisibleEndIndex;
  }

  private resolveCommittedFillPosition(): number {
    return 0;
  }

  private resolveCommittedExpectedFirstGridIndex(commitState: HybridGridColumnsCommitState): number {
    return Math.max(0, commitState.targetFirstPhotoIndex + this.resolveCommittedFillPosition());
  }

  private resolveCommittedRequestSize(): number {
    return this.resolveActiveRequestSize();
  }

  private buildCommittedGridItems(): Array<HybridGridItem> {
    return this.dataAdapter.buildGridItemsForColumns(
      this.sections,
      this.getCurrentColumns(),
      this.getBaseTopInsetHeight(),
      this.hasMore,
      this.resolveCommittedFillPosition(),
      true,
    );
  }

  private updateCommittedGridDataSource(items: Array<HybridGridItem>): void {
    this.currentGridItems = items.slice();
    this.resolveCurrentDataSource()?.updateAllIfChanged(this.currentGridItems);
  }

  private normalizeCommittedPreviewLayerForPinchStart(): void {
    this.committedFillPosition = 0;
  }

  // ── Active / Dormant routing helpers ──

  private setActiveScale(value: number): void {
    this.setCurrentScale(value);
  }

  private setActiveOpacity(value: number): void {
    this.setCurrentOpacity(value);
  }

  private setActiveVisible(value: boolean): void {
    this.setCurrentVisible(value);
  }

  private setActiveColumns(value: number): void {
    this.setCurrentColumns(value);
  }

  private getActiveColumns(): number {
    return this.getCurrentColumns();
  }

  // ── 3-Grid resolution functions ──

  public resolveScroller(kind: HybridGridKind): Scroller | undefined {
    switch (kind) {
      case HybridGridKind.A: return this.scrollerA;
      case HybridGridKind.B: return this.scrollerB;
      case HybridGridKind.C: return this.scrollerC;
    }
  }

  public resolveDataSource(kind: HybridGridKind): Shared.HybridGridDataSource | undefined {
    switch (kind) {
      case HybridGridKind.A: return this.dataSourceA;
      case HybridGridKind.B: return this.dataSourceB;
      case HybridGridKind.C: return this.dataSourceC;
    }
  }

  public resolveColumns(kind: HybridGridKind): number {
    switch (kind) {
      case HybridGridKind.A: return this.gridColumnsA;
      case HybridGridKind.B: return this.gridColumnsB;
      case HybridGridKind.C: return this.gridColumnsC;
    }
  }

  public setColumns(kind: HybridGridKind, value: number): void {
    switch (kind) {
      case HybridGridKind.A: this.gridColumnsA = value; break;
      case HybridGridKind.B: this.gridColumnsB = value; break;
      case HybridGridKind.C: this.gridColumnsC = value; break;
    }
  }

  public setScale(kind: HybridGridKind, value: number): void {
    switch (kind) {
      case HybridGridKind.A: this.gridScaleA = value; break;
      case HybridGridKind.B: this.gridScaleB = value; break;
      case HybridGridKind.C: this.gridScaleC = value; break;
    }
    this.resolveAttributeUpdater(kind).updateScale({
      x: value,
      y: value,
      centerX: this.pinchCenterX,
      centerY: this.pinchCenterY,
    });
  }

  public setOpacity(kind: HybridGridKind, value: number): void {
    switch (kind) {
      case HybridGridKind.A: this.gridOpacityA = value; break;
      case HybridGridKind.B: this.gridOpacityB = value; break;
      case HybridGridKind.C: this.gridOpacityC = value; break;
    }
    this.resolveAttributeUpdater(kind).updateOpacity(value);
  }

  public setVisible(kind: HybridGridKind, value: boolean): void {
    switch (kind) {
      case HybridGridKind.A: this.gridVisibleA = value; break;
      case HybridGridKind.B: this.gridVisibleB = value; break;
      case HybridGridKind.C: this.gridVisibleC = value; break;
    }
    this.resolveAttributeUpdater(kind).updateVisibility(value ? Visibility.Visible : Visibility.Hidden);
  }

  public setWarmActive(kind: HybridGridKind, value: boolean): void {
    switch (kind) {
      case HybridGridKind.A: this.gridWarmActiveA = value; break;
      case HybridGridKind.B: this.gridWarmActiveB = value; break;
      case HybridGridKind.C: this.gridWarmActiveC = value; break;
    }
  }

  public setInteractive(kind: HybridGridKind, value: boolean): void {
    switch (kind) {
      case HybridGridKind.A: this.gridInteractiveA = value; break;
      case HybridGridKind.B: this.gridInteractiveB = value; break;
      case HybridGridKind.C: this.gridInteractiveC = value; break;
    }
  }

  public setZIndex(kind: HybridGridKind, value: number): void {
    switch (kind) {
      case HybridGridKind.A: this.gridZIndexA = value; break;
      case HybridGridKind.B: this.gridZIndexB = value; break;
      case HybridGridKind.C: this.gridZIndexC = value; break;
    }
    this.resolveAttributeUpdater(kind).updateZIndex(value);
  }

  private resolveAttributeUpdater(kind: HybridGridKind): HybridGridAttributeUpdater {
    switch (kind) {
      case HybridGridKind.A:
        return this.gridAttributeUpdaterA;
      case HybridGridKind.B:
        return this.gridAttributeUpdaterB;
      case HybridGridKind.C:
        return this.gridAttributeUpdaterC;
    }
  }

  private initializeGridAttributeUpdaters(): void {
    this.gridAttributeUpdaterA.updateScale({ x: this.gridScaleA, y: this.gridScaleA, centerX: 0, centerY: 0 });
    this.gridAttributeUpdaterA.updateOpacity(this.gridOpacityA);
    this.gridAttributeUpdaterA.updateVisibility(this.gridVisibleA ? Visibility.Visible : Visibility.Hidden);
    this.gridAttributeUpdaterA.updateZIndex(this.gridZIndexA);

    this.gridAttributeUpdaterB.updateScale({ x: this.gridScaleB, y: this.gridScaleB, centerX: 0, centerY: 0 });
    this.gridAttributeUpdaterB.updateOpacity(this.gridOpacityB);
    this.gridAttributeUpdaterB.updateVisibility(this.gridVisibleB ? Visibility.Visible : Visibility.Hidden);
    this.gridAttributeUpdaterB.updateZIndex(this.gridZIndexB);

    this.gridAttributeUpdaterC.updateScale({ x: this.gridScaleC, y: this.gridScaleC, centerX: 0, centerY: 0 });
    this.gridAttributeUpdaterC.updateOpacity(this.gridOpacityC);
    this.gridAttributeUpdaterC.updateVisibility(this.gridVisibleC ? Visibility.Visible : Visibility.Hidden);
    this.gridAttributeUpdaterC.updateZIndex(this.gridZIndexC);
  }

  private resolveBaseZIndex(kind: HybridGridKind): number {
    switch (kind) {
      case HybridGridKind.A: return 100;
      case HybridGridKind.B: return 90;
      case HybridGridKind.C: return 80;
    }
  }

  private refreshGridRoleZIndices(targetFrontKind?: HybridGridKind): void {
    this.setZIndex(HybridGridKind.A, this.resolveBaseZIndex(HybridGridKind.A));
    this.setZIndex(HybridGridKind.B, this.resolveBaseZIndex(HybridGridKind.B));
    this.setZIndex(HybridGridKind.C, this.resolveBaseZIndex(HybridGridKind.C));
    this.setZIndex(this.currentGridKind, 200);
    if (targetFrontKind !== undefined && targetFrontKind !== this.currentGridKind) {
      this.setZIndex(targetFrontKind, 210);
    }
  }

  private resolveOtherKinds(kind: HybridGridKind): Array<HybridGridKind> {
    return [HybridGridKind.A, HybridGridKind.B, HybridGridKind.C].filter(
      (candidate: HybridGridKind) => candidate !== kind,
    );
  }

  // ── Role-based convenience wrappers ──

  public resolveCurrentScroller(): Scroller | undefined {
    return this.resolveScroller(this.currentGridKind);
  }

  public resolveCurrentDataSource(): Shared.HybridGridDataSource | undefined {
    return this.resolveDataSource(this.currentGridKind);
  }

  public getCurrentColumns(): number {
    return this.resolveColumns(this.currentGridKind);
  }

  public setCurrentScale(value: number): void {
    this.setScale(this.currentGridKind, value);
  }

  public setCurrentOpacity(value: number): void {
    this.setOpacity(this.currentGridKind, value);
  }

  public setCurrentVisible(value: boolean): void {
    this.setVisible(this.currentGridKind, value);
  }

  public setCurrentColumns(value: number): void {
    this.setColumns(this.currentGridKind, value);
  }

  public setCurrentInteractive(value: boolean): void {
    this.setInteractive(this.currentGridKind, value);
  }

  public resolveShrinkTargetScroller(): Scroller | undefined {
    return this.resolveScroller(this.shrinkTargetKind);
  }

  public resolveShrinkTargetDataSource(): Shared.HybridGridDataSource | undefined {
    return this.resolveDataSource(this.shrinkTargetKind);
  }

  public getShrinkTargetColumns(): number {
    return this.resolveColumns(this.shrinkTargetKind);
  }

  public setShrinkTargetScale(value: number): void {
    this.setScale(this.shrinkTargetKind, value);
  }

  public setShrinkTargetOpacity(value: number): void {
    this.setOpacity(this.shrinkTargetKind, value);
  }

  public setShrinkTargetVisible(value: boolean): void {
    this.setVisible(this.shrinkTargetKind, value);
  }

  public setShrinkTargetColumns(value: number): void {
    this.setColumns(this.shrinkTargetKind, value);
  }

  public setShrinkTargetWarmActive(value: boolean): void {
    this.setWarmActive(this.shrinkTargetKind, value);
  }

  public resolveExpandTargetScroller(): Scroller | undefined {
    return this.resolveScroller(this.expandTargetKind);
  }

  public resolveExpandTargetDataSource(): Shared.HybridGridDataSource | undefined {
    return this.resolveDataSource(this.expandTargetKind);
  }

  public getExpandTargetColumns(): number {
    return this.resolveColumns(this.expandTargetKind);
  }

  public setExpandTargetScale(value: number): void {
    this.setScale(this.expandTargetKind, value);
  }

  public setExpandTargetOpacity(value: number): void {
    this.setOpacity(this.expandTargetKind, value);
  }

  public setExpandTargetVisible(value: boolean): void {
    this.setVisible(this.expandTargetKind, value);
  }

  public setExpandTargetColumns(value: number): void {
    this.setColumns(this.expandTargetKind, value);
  }

  public setExpandTargetWarmActive(value: boolean): void {
    this.setWarmActive(this.expandTargetKind, value);
  }

  // ── Bind methods for 3-grid ──

  public bindScrollerA(scroller: Scroller): void {
    this.scrollerA = scroller;
    if (this.currentGridKind === HybridGridKind.A) {
      this.schedulePendingCommitSync(0);
    }
  }

  public bindScrollerB(scroller: Scroller): void {
    this.scrollerB = scroller;
    if (this.currentGridKind === HybridGridKind.B) {
      this.schedulePendingCommitSync(0);
    }
  }

  public bindScrollerC(scroller: Scroller): void {
    this.scrollerC = scroller;
    if (this.currentGridKind === HybridGridKind.C) {
      this.schedulePendingCommitSync(0);
    }
  }

  public bindDataSourceA(dataSource: Shared.HybridGridDataSource): void {
    this.dataSourceA = dataSource;
    this.dataSourceA.updateAllIfChanged(this.currentGridKind === HybridGridKind.A ? this.currentGridItems.slice() : []);
  }

  public bindDataSourceB(dataSource: Shared.HybridGridDataSource): void {
    this.dataSourceB = dataSource;
    this.dataSourceB.updateAllIfChanged(this.currentGridKind === HybridGridKind.B ? this.currentGridItems.slice() : []);
  }

  public bindDataSourceC(dataSource: Shared.HybridGridDataSource): void {
    this.dataSourceC = dataSource;
    this.dataSourceC.updateAllIfChanged(this.currentGridKind === HybridGridKind.C ? this.currentGridItems.slice() : []);
  }

  private forcePruneVisibleThumbnailCache(): void {
    this.dataVm.forcePruneThumbnailCache();
  }

  private buildPrefetchRangeKey(
    prefix: string,
    columns: number,
    fillPosition: number,
    scrollOffset: number,
    range: HybridPreviewViewportRange,
  ): string {
    return `${prefix}:${this.renderedGridVersion}:${columns}:${fillPosition}:${Math.round(scrollOffset)}:${range.start}:${range.end}`;
  }

  private scheduleIdleShrinkPrebuild(delayMs: number): void {
    if (
      this.pinchActive ||
      this.pendingCommit !== undefined ||
      this.commitPhase !== HybridPinchCommitPhase.IDLE ||
      this.listWidth <= 0 ||
      this.listHeight <= 0
    ) {
      return;
    }
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    this.idlePrebuildTimeoutId = setTimeout((): void => {
      this.idlePrebuildTimeoutId = undefined;
      this.prepareIdleShrinkPrebuild();
    }, Math.max(0, delayMs));
  }

  private prepareIdleShrinkPrebuild(): void {
    if (
      this.pinchActive ||
      this.pendingCommit !== undefined ||
      !this.resolveShrinkTargetScroller() ||
      !this.resolveShrinkTargetDataSource() ||
      this.listWidth <= 0 ||
      this.listHeight <= 0
    ) {
      return;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      this.clearIdlePrebuildState(true);
      return;
    }

    const centerX = this.listWidth * 0.5;
    const centerY = this.getBaseTopInsetHeight() + this.listHeight * 0.5;
    const idleState = this.anchorAdapter.createPinchState(
      this.getActiveColumns(),
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      this.getBaseTopInsetHeight(),
      assets.length,
    );
    this.anchorAdapter.updatePinchState(idleState, PINCH_SHRINK_ENTER_SCALE, centerX, centerY);

    if (
      idleState.targetDirection !== HybridPinchTargetDirection.SHRINK ||
      idleState.targetColumns === this.getActiveColumns()
    ) {
      this.clearIdlePrebuildState(false);
      return;
    }

    this.applyIdlePrebuildState(idleState, !this.isIdlePrebuildStructureReusable(idleState));
  }

  // ── Idle Expand Pre-build ──

  private scheduleIdleExpandPrebuild(delayMs: number): void {
    if (
      this.pinchActive ||
      this.pendingCommit !== undefined ||
      this.commitPhase !== HybridPinchCommitPhase.IDLE ||
      this.listWidth <= 0 ||
      this.listHeight <= 0
    ) {
      return;
    }
    if (this.idleExpandTimeoutId !== undefined) {
      clearTimeout(this.idleExpandTimeoutId);
      this.idleExpandTimeoutId = undefined;
    }
    this.idleExpandTimeoutId = setTimeout((): void => {
      this.idleExpandTimeoutId = undefined;
      this.prepareIdleExpandPrebuild();
    }, Math.max(0, delayMs));
  }

  private prepareIdleExpandPrebuild(): void {
    if (
      this.pinchActive ||
      this.pendingCommit !== undefined ||
      this.listWidth <= 0 ||
      this.listHeight <= 0
    ) {
      return;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      this.clearIdleExpandPrebuildState();
      return;
    }

    const centerX = this.listWidth * 0.5;
    const centerY = this.getBaseTopInsetHeight() + this.listHeight * 0.5;
    const idleState = this.anchorAdapter.createPinchState(
      this.getActiveColumns(),
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      this.getBaseTopInsetHeight(),
      assets.length,
    );
    this.anchorAdapter.updatePinchState(idleState, PINCH_EXPAND_ENTER_SCALE, centerX, centerY);

    if (
      idleState.targetDirection !== HybridPinchTargetDirection.EXPAND ||
      idleState.targetColumns === this.getActiveColumns()
    ) {
      this.clearIdleExpandPrebuildState();
      return;
    }

    this.applyIdleExpandPrebuildState(idleState);
  }

  private isIdleExpandPrebuildReusable(state: HybridPinchStateInfo): boolean {
    return this.idleExpandStructureReady &&
      this.idleExpandVersion === this.renderedGridVersion &&
      this.idleExpandColumns === state.targetColumns &&
      this.idleExpandFillPosition === state.fillPosition;
  }

  private applyIdleExpandPrebuildState(state: HybridPinchStateInfo): void {
    if (
      state.targetDirection !== HybridPinchTargetDirection.EXPAND ||
      state.targetColumns === this.getActiveColumns()
    ) {
      return;
    }

    const needsRebuild = !this.isIdleExpandPrebuildReusable(state);
    if (needsRebuild) {
      this.idleExpandGridItems = this.dataAdapter.buildGridItemsForColumns(
        this.sections,
        state.targetColumns,
        0,
        this.hasMore,
        state.fillPosition,
        true,
      );
    }

    const offsetChanged = Math.abs(this.idleExpandTargetScrollOffset - state.targetScrollOffset) > 0.5;
    const didRebuild = needsRebuild ||
      this.idleExpandVersion !== this.renderedGridVersion ||
      this.idleExpandColumns !== state.targetColumns ||
      this.idleExpandFillPosition !== state.fillPosition ||
      offsetChanged;

    this.idleExpandColumns = state.targetColumns;
    this.idleExpandFillPosition = state.fillPosition;
    this.idleExpandTargetScrollOffset = state.targetScrollOffset;
    this.idleExpandTargetFirstPhotoIndex = state.targetFirstPhotoIndex;
    this.idleExpandTargetAnchorPhotoIndex = state.targetAnchorPhotoIndex;
    this.idleExpandTargetFirstRowIndex = state.targetFirstRowIndex;
    this.idleExpandTargetAnchorRowIndex = state.targetAnchorRowIndex;
    this.idleExpandResolvedFocusX = state.resolvedFocusX;
    this.idleExpandResolvedFocusY = state.resolvedFocusY;
    this.idleExpandTargetBaseScale = state.targetBaseScale;
    this.idleExpandVersion = this.renderedGridVersion;
    this.idleExpandStructureReady = true;
    this.idleExpandBaselineScrollOffset = this.currentScrollOffsetY;
    this.idleExpandInvalidatedByScroll = false;
    if (didRebuild) {
      this.idleExpandVisibleRowsWarm = false;
      this.idleExpandReady = false;
    }

    if (didRebuild && this.idleExpandGridItems.length > 0) {
      const expandDataSource = this.resolveExpandTargetDataSource();
      const expandScroller = this.resolveExpandTargetScroller();
      if (expandDataSource) {
        expandDataSource.updateAllIfChanged(this.idleExpandGridItems);
      }
      this.setExpandTargetColumns(state.targetColumns);
      this.setExpandTargetWarmActive(true);
      try {
        expandScroller?.scrollTo({ xOffset: 0, yOffset: state.targetScrollOffset });
      } catch (_error) {}
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      this.idleExpandStructureReady = false;
      this.idleExpandReady = false;
      return;
    }

    const expandRequestSize = this.resolveIdleExpandRequestSize(state.targetColumns);
    const previewRange = this.resolveIdlePreviewPhotoRange(
      state.targetColumns,
      state.fillPosition,
      state.targetScrollOffset,
      assets.length,
    );
    const visibleKey = this.buildPrefetchRangeKey(
      'idle_expand',
      state.targetColumns,
      state.fillPosition,
      state.targetScrollOffset,
      previewRange,
    );
    if (visibleKey !== this.lastIdleExpandVisiblePrefetchKey) {
      this.lastIdleExpandVisiblePrefetchKey = visibleKey;
      this.prefetchPhotoRange(assets, previewRange, expandRequestSize);
    }

    const token = ++this.idleExpandToken;
    this.scheduleIdleExpandReadinessCheck(token);
  }

  private resolveIdleExpandRequestSize(targetColumns: number): number {
    return Shared.resolveHybridRequestSizeBucket(
      Math.max(1, targetColumns),
      this.listWidth,
      Shared.HybridThumbnailLayerRole.WARM,
    );
  }

  private scheduleIdleExpandReadinessCheck(token: number): void {
    if (this.idleExpandSyncTimeoutId !== undefined) {
      clearTimeout(this.idleExpandSyncTimeoutId);
      this.idleExpandSyncTimeoutId = undefined;
    }
    this.idleExpandSyncTimeoutId = setTimeout((): void => {
      this.idleExpandSyncTimeoutId = undefined;
      this.checkIdleExpandReadiness(token);
    }, IDLE_PREBUILD_READY_RETRY_DELAY_MS);
  }

  private checkIdleExpandReadiness(token: number): void {
    if (
      token !== this.idleExpandToken ||
      this.pinchActive ||
      !this.idleExpandStructureReady ||
      this.idleExpandInvalidatedByScroll ||
      this.idleExpandVersion !== this.renderedGridVersion
    ) {
      return;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    const expandRequestSize = this.resolveIdleExpandRequestSize(this.idleExpandColumns);
    const previewRange = this.resolveIdlePreviewPhotoRange(
      this.idleExpandColumns,
      this.idleExpandFillPosition,
      this.idleExpandTargetScrollOffset,
      assets.length,
    );
    const visibleRowsWarm = this.ensurePhotoRangeWarm(assets, previewRange, expandRequestSize);

    const nextReady = visibleRowsWarm;
    const stateChanged =
      nextReady !== this.idleExpandReady ||
      visibleRowsWarm !== this.idleExpandVisibleRowsWarm;
    this.idleExpandVisibleRowsWarm = visibleRowsWarm;
    this.idleExpandReady = nextReady;
    if (stateChanged) {
      this.notifyStateChanged();
    }
    if (!this.idleExpandReady && !this.pinchActive) {
      this.scheduleIdleExpandReadinessCheck(token);
    }
  }

  private invalidateIdleExpandForScrollOffset(): boolean {
    if (
      this.pinchActive ||
      this.pendingCommit !== undefined ||
      !this.idleExpandStructureReady ||
      this.idleExpandInvalidatedByScroll ||
      this.idleExpandColumns <= 0
    ) {
      return false;
    }

    const invalidationDistance = Math.abs(this.currentScrollOffsetY - this.idleExpandBaselineScrollOffset);
    if (invalidationDistance <= this.resolveIdlePrebuildOffsetTolerance(this.idleExpandColumns)) {
      return false;
    }

    this.idleExpandInvalidatedByScroll = true;
    this.idleExpandReady = false;
    this.idleExpandVisibleRowsWarm = false;
    return true;
  }

  private resolveIdlePreviewPhotoRange(
    columns: number,
    fillPosition: number,
    scrollOffset: number,
    totalPhotoCount: number,
  ): HybridPreviewViewportRange {
    return this.resolvePhotoRangeForOffsetWithOverscan(
      columns,
      fillPosition,
      scrollOffset,
      totalPhotoCount,
      this.resolveIdlePreviewOverscanAboveRows(columns),
      this.resolveIdlePreviewOverscanBelowRows(columns),
    );
  }

  private resolveViewportRowsForColumns(columns: number): number {
    if (columns <= 0 || this.listHeight <= 0 || this.listWidth <= 0) {
      return 1;
    }

    const itemSize = HybridSwitchCalc.calcItemSize(columns, this.listWidth);
    const itemExtent = itemSize + Shared.HYBRID_GRID_GAP;
    if (itemExtent <= 0) {
      return 1;
    }

    return Math.max(1, Math.ceil(this.listHeight / itemExtent));
  }

  private resolveIdlePreviewOverscanAboveRows(columns: number): number {
    const screenRows = this.resolveViewportRowsForColumns(columns);
    return Math.max(
      0,
      Math.floor(screenRows * Shared.HYBRID_IDLE_PREVIEW_OVERSCAN_ABOVE_SCREEN_MULTIPLIER),
    );
  }

  private resolveIdlePreviewOverscanBelowRows(columns: number): number {
    const screenRows = this.resolveViewportRowsForColumns(columns);
    return Math.max(
      0,
      Math.ceil(screenRows * Shared.HYBRID_IDLE_PREVIEW_OVERSCAN_BELOW_SCREEN_MULTIPLIER),
    );
  }

  private scheduleIdlePrebuildReadinessCheck(token: number, targetScrollOffset: number): void {
    if (this.idlePrebuildSyncTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildSyncTimeoutId);
      this.idlePrebuildSyncTimeoutId = undefined;
    }
    this.idlePrebuildSyncTimeoutId = setTimeout((): void => {
      this.idlePrebuildSyncTimeoutId = undefined;
      this.checkIdlePrebuildReadiness(token, targetScrollOffset);
    }, IDLE_PREBUILD_READY_RETRY_DELAY_MS);
  }

  private checkIdlePrebuildReadiness(token: number, targetScrollOffset: number): void {
    const dormantScroller = this.resolveShrinkTargetScroller();
    if (
      token !== this.idlePrebuildToken ||
      this.pinchActive ||
      !dormantScroller ||
      !this.idlePrebuildStructureReady ||
      this.idlePrebuildInvalidatedByScroll ||
      this.idlePrebuildVersion !== this.renderedGridVersion
    ) {
      return;
    }

    let currentOffset = Number.NaN;
    try {
      currentOffset = Math.max(0, dormantScroller.currentOffset().yOffset);
    } catch (_error) {}

    const assets = this.dataAdapter.flattenAssets(this.sections);
    const offsetReady =
      !Number.isNaN(currentOffset) &&
      Math.abs(currentOffset - targetScrollOffset) <= IDLE_PREBUILD_OFFSET_TOLERANCE;
    const previewRange = this.resolveIdlePreviewPhotoRange(
      this.idlePrebuildColumns,
      this.idlePrebuildFillPosition,
      this.idlePrebuildTargetScrollOffset,
      assets.length,
    );
    const visibleRowsWarm = offsetReady &&
      this.ensurePhotoRangeWarm(assets, previewRange, this.resolveRequestSizeForKind(this.shrinkTargetKind));
    this.lastIdleOverscanPrefetchKey = '';

    const nextVisibleRowsWarm = visibleRowsWarm;
    const nextIdleReady = offsetReady && visibleRowsWarm;
    const idleStateChanged =
      nextVisibleRowsWarm !== this.idlePrebuildVisibleRowsWarm ||
      nextIdleReady !== this.idlePrebuildReady;
    this.idlePrebuildVisibleRowsWarm = nextVisibleRowsWarm;
    this.idlePrebuildReady = nextIdleReady;
    if (idleStateChanged) {
      this.notifyStateChanged();
    }
    if (nextIdleReady) {
      this.logMemoryDebug('idle-prebuild-ready');
    }
    if (!this.idlePrebuildReady && !this.pinchActive) {
      this.scheduleIdlePrebuildReadinessCheck(token, targetScrollOffset);
    }
  }

  private canReuseIdlePrebuild(state: HybridPinchStateInfo): boolean {
    return this.idlePrebuildReady && this.isIdlePrebuildStructureReusable(state);
  }

  private reconcileLatchedPinchTarget(state: HybridPinchStateInfo): void {
    if (!this.latchedTargetActive) {
      const enterShrink =
        state.targetDirection === HybridPinchTargetDirection.SHRINK &&
        state.targetColumns !== this.getActiveColumns() &&
        state.liveScale <= PINCH_SHRINK_ENTER_SCALE;
      const enterExpand =
        state.targetDirection === HybridPinchTargetDirection.EXPAND &&
        state.targetColumns !== this.getActiveColumns() &&
        state.liveScale >= PINCH_EXPAND_ENTER_SCALE;
      if (enterShrink || enterExpand) {
        this.latchPinchTarget(state);
        this.applyLatchedPinchTarget(state);
        return;
      }
      this.resetPinchTargetToCurrentGrid(state);
      return;
    }

    const cancelShrink =
      this.latchedTargetDirection === HybridPinchTargetDirection.SHRINK &&
      state.liveScale >= PINCH_SHRINK_CANCEL_SCALE;
    const cancelExpand =
      this.latchedTargetDirection === HybridPinchTargetDirection.EXPAND &&
      state.liveScale <= PINCH_EXPAND_CANCEL_SCALE;
    if (cancelShrink || cancelExpand) {
      this.resetLatchedPinchTarget();
      this.resetPreviewTransactionState();
      this.resetPinchTargetToCurrentGrid(state);
      return;
    }

    this.applyLatchedPinchTarget(state);
  }

  private latchPinchTarget(state: HybridPinchStateInfo): void {
    this.latchedTargetActive = true;
    this.latchedTargetColumns = state.targetColumns;
    this.latchedTargetDirection = state.targetDirection;
    this.latchedFillPosition = state.fillPosition;
    this.latchedTargetScrollOffset = state.targetScrollOffset;
    this.latchedTargetFirstPhotoIndex = state.targetFirstPhotoIndex;
    this.latchedTargetAnchorPhotoIndex = state.targetAnchorPhotoIndex;
    this.latchedTargetFirstRowIndex = state.targetFirstRowIndex;
    this.latchedTargetAnchorRowIndex = state.targetAnchorRowIndex;
    this.latchedResolvedFocusX = state.resolvedFocusX;
    this.latchedResolvedFocusY = state.resolvedFocusY;
    this.latchedTargetBaseScale = state.targetBaseScale;
    this.resetPreviewTransactionState();
  }

  private applyLatchedPinchTarget(state: HybridPinchStateInfo): void {
    state.targetColumns = this.latchedTargetColumns;
    state.targetDirection = this.latchedTargetDirection;
    state.fillPosition = this.latchedFillPosition;
    state.targetScrollOffset = this.latchedTargetScrollOffset;
    state.targetFirstPhotoIndex = this.latchedTargetFirstPhotoIndex;
    state.targetAnchorPhotoIndex = this.latchedTargetAnchorPhotoIndex;
    state.targetFirstRowIndex = this.latchedTargetFirstRowIndex;
    state.targetAnchorRowIndex = this.latchedTargetAnchorRowIndex;
    state.resolvedFocusX = this.latchedResolvedFocusX;
    state.resolvedFocusY = this.latchedResolvedFocusY;
    state.sharedCenterX = this.latchedResolvedFocusX;
    state.sharedCenterY = this.latchedResolvedFocusY;
    state.targetBaseScale = this.latchedTargetBaseScale;
    state.targetVisualScale = this.latchedTargetBaseScale * state.liveScale;
  }

  private hasReusableIdleShrinkPrebuild(): boolean {
    return this.idlePrebuildReady &&
      this.idlePrebuildVersion === this.renderedGridVersion &&
      this.idlePrebuildColumns > 0 &&
      this.idlePrebuildColumns !== this.getActiveColumns() &&
      this.resolveShrinkTargetScroller() !== undefined &&
      this.resolveShrinkTargetDataSource() !== undefined;
  }

  private resetPinchTargetToCurrentGrid(state: HybridPinchStateInfo): void {
    state.targetColumns = this.getActiveColumns();
    state.targetDirection = HybridPinchTargetDirection.NONE;
    state.fillPosition = 0;
    state.targetScrollOffset = Math.max(0, this.currentScrollOffsetY);
    state.targetFirstPhotoIndex = Math.max(0, state.anchor.itemIndex);
    state.targetAnchorPhotoIndex = Math.max(0, state.anchor.itemIndex);
    state.targetFirstRowIndex = Math.floor(state.targetFirstPhotoIndex / Math.max(1, this.getActiveColumns()));
    state.targetAnchorRowIndex = state.targetFirstRowIndex;
    state.resolvedFocusX = state.pinchCenterX;
    state.resolvedFocusY = state.pinchCenterY;
    state.sharedCenterX = state.pinchCenterX;
    state.sharedCenterY = state.pinchCenterY;
    state.targetBaseScale = 1;
    state.targetVisualScale = 1;
  }

  private prewarmAdjacentPinchTargets(centerX: number, centerY: number, totalPhotoCount: number): void {
    if (this.listWidth <= 0 || this.listHeight <= 0 || totalPhotoCount <= 0) {
      return;
    }
    this.prewarmTargetForScale(PINCH_SHRINK_ENTER_SCALE, centerX, centerY, totalPhotoCount);
  }

  private prewarmTargetForScale(
    scale: number,
    centerX: number,
    centerY: number,
    totalPhotoCount: number,
  ): void {
    const tempState = this.anchorAdapter.createPinchState(
      this.getActiveColumns(),
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      this.getBaseTopInsetHeight(),
      totalPhotoCount,
    );
    this.anchorAdapter.updatePinchState(tempState, scale, centerX, centerY);
    if (tempState.targetColumns === this.getActiveColumns()) {
      return;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      return;
    }

    const visibleRange = this.resolvePreviewViewportPhotoRange(tempState, assets.length, 0);
    const prewarmKey = this.buildPrefetchRangeKey(
      'pinch_shrink_prewarm',
      tempState.targetColumns,
      tempState.fillPosition,
      tempState.targetScrollOffset,
      visibleRange,
    );
    if (prewarmKey !== this.lastShrinkPrewarmPrefetchKey) {
      this.lastShrinkPrewarmPrefetchKey = prewarmKey;
      this.prefetchPhotoRange(
        assets,
        visibleRange,
        Shared.resolveHybridRequestSizeBucket(
          tempState.targetColumns,
          this.listWidth,
          Shared.HybridThumbnailLayerRole.WARM,
        ),
      );
    }
  }

  private describeSyncError(error: Error | string | number | boolean | Object | null | undefined): string {
    if (error instanceof Error) {
      return error.stack ?? error.message;
    }
    try {
      return JSON.stringify(error);
    } catch (_jsonError) {
      return String(error);
    }
  }

  private syncFromDataVmSafely(dispatchLabel: string, metaOnly: boolean): void {
    try {
      if (metaOnly) {
        this.syncMetaFromDataVm();
      } else {
        this.syncFromDataVm();
      }
      return;
    } catch (error) {
      console.error(`[HybridPhotoGridVm] ${dispatchLabel} sync failed: ${this.describeSyncError(error)}`);
    }

    try {
      this.syncMetaFromDataVm();
    } catch (fallbackError) {
      console.error(`[HybridPhotoGridVm] ${dispatchLabel} meta fallback failed: ${this.describeSyncError(fallbackError)}`);
      this.isLoading = this.dataVm.getIsLoading();
      this.isLoadingMore = this.dataVm.getIsLoadingMore();
      this.hasMore = this.dataVm.getHasMore();
      this.errorText = this.dataVm.getErrorText() || 'Hybrid photo sync failed';
      this.itemCount = this.dataVm.getAllTimelineItems().length;
      this.notifyStateChanged();
    }
  }

  private syncFromDataVm(): void {
    this.sections = this.dataAdapter.cloneSections(this.dataVm.getSections());
    this.isLoading = this.dataVm.getIsLoading();
    this.isLoadingMore = this.dataVm.getIsLoadingMore();
    this.hasMore = this.dataVm.getHasMore();
    this.errorText = this.dataVm.getErrorText();
    this.syncDataVmRequestSize();
    this.syncRenderedData();
    this.notifyStateChanged();
  }

  private syncMetaFromDataVm(): void {
    this.isLoading = this.dataVm.getIsLoading();
    this.isLoadingMore = this.dataVm.getIsLoadingMore();
    this.hasMore = this.dataVm.getHasMore();
    this.errorText = this.dataVm.getErrorText();
    this.itemCount = this.dataVm.getAllTimelineItems().length;
    this.notifyStateChanged();
  }

  private shouldSuppressDeferredDataVmSync(): boolean {
    if (this.suppressDeferredDataVmSyncCount <= 0 || !this.hasCompletedFirstLoad) {
      return false;
    }

    this.suppressDeferredDataVmSyncCount -= 1;
    return this.getActiveColumns() === this.dataVm.getGridColumns() &&
      this.currentItems.length === this.dataVm.getAllTimelineItems().length &&
      this.sections.length === this.dataVm.getSections().length;
  }

  private syncSilentColumnsFromDataVm(promotedGridItems?: Array<HybridGridItem>): void {
    this.sections = this.dataAdapter.cloneSections(this.dataVm.getSections());
    this.isLoading = this.dataVm.getIsLoading();
    this.isLoadingMore = this.dataVm.getIsLoadingMore();
    this.hasMore = this.dataVm.getHasMore();
    this.errorText = this.dataVm.getErrorText();
    this.syncDataVmRequestSize();

    const nextItems = this.dataVm.getAllTimelineItems().slice();
    this.applyTimelineItems(nextItems);
    this.currentItems = nextItems;
    this.itemCount = nextItems.length;
    this.renderedGridVersion += 1;
    this.resetPrefetchKeys();

    const nextGridItems = promotedGridItems && promotedGridItems.length > 0
      ? promotedGridItems.slice()
      : this.buildCommittedGridItems();
    this.updateCommittedGridDataSource(nextGridItems);

    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
  }

  private syncRenderedData(): void {
    const nextItems = this.dataVm.getAllTimelineItems().slice();
    this.applyTimelineItems(nextItems);
    this.currentItems = nextItems;
    this.itemCount = nextItems.length;
    this.renderedGridVersion += 1;
    this.resetPrefetchKeys();
    this.updateCommittedGridDataSource(this.buildCommittedGridItems());

    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
    if (!this.pinchActive) {
      this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
      this.scheduleIdleExpandPrebuild(IDLE_PREBUILD_DELAY_MS);
    }
    this.schedulePendingCommitSync(0);
  }

  private applyTimelineItems(nextItems: Array<HybridTimelineItem>): void {
    if (!this.timelineDataSource) {
      return;
    }

    if (
      !this.timelineInitialized ||
      nextItems.length < this.currentItems.length ||
      this.lastAppliedColumns !== this.getActiveColumns()
    ) {
      this.timelineDataSource.replaceAll(nextItems);
      this.timelineInitialized = true;
      this.lastAppliedColumns = this.getActiveColumns();
      return;
    }

    this.timelineDataSource.reconcile(nextItems);
    this.lastAppliedColumns = this.getActiveColumns();
  }

  private updateFloatingSection(startIndex: number): void {
    const info = this.dataAdapter.buildFloatingSectionInfo(this.currentItems, startIndex);
    this.applyFloatingSection(info);
  }

  private applyFloatingSection(info: HybridFloatingSectionInfo): void {
    this.floatingSectionTitle = info.title;
    this.floatingSectionCount = info.count;
  }

  private resolveVisibleTimelineRowIndex(): number {
    const rowHeight = this.resolveTimelineRowHeight(this.getActiveColumns());
    if (rowHeight <= 0) {
      return 0;
    }
    return Math.max(0, Math.floor(this.currentScrollOffsetY / rowHeight));
  }

  private resolveTimelineRowHeight(columns: number): number {
    if (this.listWidth <= 0 || columns <= 0) {
      return 0;
    }
    const totalGap = Shared.HYBRID_GRID_GAP * Math.max(0, columns - 1);
    return Math.max(0, (this.listWidth - totalGap) / columns);
  }

  private resolveTimelineRowIndexFromGridIndex(gridIndex: number, fillPosition: number = 0): number {
    const safeIndex = Math.max(0, gridIndex - Math.max(0, fillPosition));
    return Math.floor(safeIndex / Math.max(1, this.getActiveColumns()));
  }

  private syncCurrentScrollOffset(): void {
    try {
      this.currentScrollOffsetY = Math.max(0, this.resolveCommittedScroller()?.currentOffset().yOffset ?? 0);
    } catch (_error) {}
  }

  private runPinchTransition(state: HybridPinchStateInfo): void {
    if (state.targetColumns === this.getActiveColumns()) {
      this.animateResetToCurrentGrid();
      return;
    }

    if (state.targetDirection === HybridPinchTargetDirection.SHRINK && !this.ensureIdlePrebuildStructureForPinch(state)) {
      this.animateResetToCurrentGrid();
      return;
    }

    if (!this.isDormantLayerPreparedForTarget(state)) {
      this.buildTargetGridOnDormantLayer(state);
    }
    if (!this.isDormantLayerPreparedForTarget(state)) {
      this.animateResetToCurrentGrid();
      return;
    }

    const targetKind = this.resolveTargetKindForDirection(state.targetDirection);
    this.refreshGridRoleZIndices(targetKind);
    this.setActiveVisible(true);
    this.setTargetVisibleForDirection(state.targetDirection, true);
    this.animateFastOutSlowIn(PINCH_STAGE_TWO_DURATION_MS, (): void => {
      this.setActiveScale(1);
      this.setActiveOpacity(0);
      this.setTargetScaleForDirection(state.targetDirection, 1);
      this.setTargetOpacityForDirection(state.targetDirection, 1);
    });
    this.stageTwoTimeoutId = setTimeout((): void => {
      this.stageTwoTimeoutId = undefined;
      this.promoteGridLayer(state);
    }, PINCH_STAGE_TWO_DURATION_MS);
  }

  private promoteGridLayer(state: HybridPinchStateInfo): void {
    const previousCurrentKind = this.currentGridKind;
    const targetKind = this.resolveTargetKindForDirection(state.targetDirection);
    const promotedGridItems = this.resolveDataSource(targetKind)?.getItemsSnapshot() ?? [];
    const finalScrollOffset = this.anchorAdapter.resolveFinalScrollOffset(state);
    const remainingKinds = this.resolveOtherKinds(targetKind);
    const carryOverKind = remainingKinds.find((kind: HybridGridKind) => kind === previousCurrentKind);
    const idleRebuildKind = remainingKinds.find((kind: HybridGridKind) => kind !== carryOverKind) ?? remainingKinds[0];

    this.currentGridKind = targetKind;
    if (state.targetDirection === HybridPinchTargetDirection.SHRINK) {
      this.expandTargetKind = carryOverKind ?? remainingKinds[0];
      this.shrinkTargetKind = idleRebuildKind;
    } else {
      this.shrinkTargetKind = carryOverKind ?? remainingKinds[0];
      this.expandTargetKind = idleRebuildKind;
    }
    this.committedLayerKind = this.currentGridKind === HybridGridKind.B
      ? HybridCommittedLayerKind.PREVIEW
      : HybridCommittedLayerKind.MAIN;
    this.currentScrollOffsetY = finalScrollOffset;
    this.pinchCenterX = state.sharedCenterX;
    this.pinchCenterY = state.sharedCenterY;
    this.committedFillPosition = 0;
    this.pendingCommit = undefined;
    this.hasPendingCommit = false;
    this.pendingCommitRetryCount = 0;
    this.pendingCommitScrollOffset = finalScrollOffset;
    this.mainGridCommitReady = false;
    this.commitPhase = HybridPinchCommitPhase.IDLE;
    this.commitAlignPhase = HybridCommitAlignPhase.FINALIZED;
    this.commitStartedAt = 0;
    this.commitDeadlineMs = 0;
    this.mainVisibleStartIndex = -1;
    this.mainVisibleEndIndex = -1;
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.dataVm.silentSetGridColumns(state.targetColumns);
    this.syncSilentColumnsFromDataVm(promotedGridItems);
    this.setVisible(HybridGridKind.A, false);
    this.setVisible(HybridGridKind.B, false);
    this.setVisible(HybridGridKind.C, false);
    this.setOpacity(HybridGridKind.A, 0);
    this.setOpacity(HybridGridKind.B, 0);
    this.setOpacity(HybridGridKind.C, 0);
    this.setScale(HybridGridKind.A, 1);
    this.setScale(HybridGridKind.B, 1);
    this.setScale(HybridGridKind.C, 1);
    this.setWarmActive(HybridGridKind.A, false);
    this.setWarmActive(HybridGridKind.B, false);
    this.setWarmActive(HybridGridKind.C, false);
    this.setInteractive(HybridGridKind.A, false);
    this.setInteractive(HybridGridKind.B, false);
    this.setInteractive(HybridGridKind.C, false);
    this.setCurrentVisible(true);
    this.setCurrentOpacity(1);
    this.setCurrentScale(1);
    this.setCurrentInteractive(true);
    this.resolveDataSource(this.shrinkTargetKind)?.updateAllIfChanged([]);
    this.resolveDataSource(this.expandTargetKind)?.updateAllIfChanged([]);
    this.setColumns(this.currentGridKind, state.targetColumns);
    this.refreshGridRoleZIndices();
    this.idlePrebuildReady = false;
    this.idlePrebuildVisibleRowsWarm = false;
    this.idlePrebuildInvalidatedByScroll = false;
    this.idleExpandReady = false;
    this.idleExpandVisibleRowsWarm = false;
    this.idleExpandInvalidatedByScroll = false;
    this.resetLatchedPinchTarget();
    this.resetPrefetchKeys();
    this.pinchState = undefined;
    this.suppressDeferredDataVmSyncCount = this.dataVm.endPinchFreeze();
    // Retain PixelMaps near the viewport at the OLD column count so reverse-pinch is instant
    this.retainCrossScalePixelMaps(state);
    this.snapshotController?.hideSnapshot();
    this.forcePruneVisibleThumbnailCache();
    this.clearIdleExpandPrebuildState();
    this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
    this.scheduleIdleExpandPrebuild(IDLE_PREBUILD_DELAY_MS);
    this.notifyStateChanged();
  }

  private animateResetToCurrentGrid(): void {
    this.animateEaseOut(PINCH_RESET_DURATION_MS, (): void => {
      this.setActiveScale(1);
      this.setActiveOpacity(1);
      this.setShrinkTargetOpacity(0);
      this.setShrinkTargetScale(1);
      this.setExpandTargetOpacity(0);
      this.setExpandTargetScale(1);
    });
    this.stageTwoTimeoutId = setTimeout((): void => {
      this.stageTwoTimeoutId = undefined;
      this.previewItems = [];
      this.previewVisibleStartIndex = -1;
      this.previewVisibleEndIndex = -1;
      this.setActiveVisible(true);
      this.setActiveOpacity(1);
      this.setActiveScale(1);
      this.setShrinkTargetVisible(false);
      this.setShrinkTargetOpacity(0);
      this.setShrinkTargetScale(1);
      this.setShrinkTargetWarmActive(false);
      this.setExpandTargetVisible(false);
      this.setExpandTargetOpacity(0);
      this.setExpandTargetScale(1);
      this.setExpandTargetWarmActive(false);
      this.refreshGridRoleZIndices();
      this.committedFillPosition = 0;
      this.pendingCommit = undefined;
      this.hasPendingCommit = false;
      this.pendingCommitRetryCount = 0;
      this.pendingCommitScrollOffset = 0;
      this.mainVisibleStartIndex = -1;
      this.mainVisibleEndIndex = -1;
      this.mainCommitOffsetReady = false;
      this.mainCommitIndexReady = false;
      this.mainVisibleRowsWarm = false;
      this.mainFirstPaintArmed = false;
      this.mainFirstPaintStableCount = 0;
      this.mainFirstPaintReady = false;
      this.mainGridCommitReady = false;
      this.commitPhase = HybridPinchCommitPhase.IDLE;
      this.commitStartedAt = 0;
      this.commitDeadlineMs = 0;
      this.commitAlignPhase = HybridCommitAlignPhase.FINALIZED;
      this.resetLatchedPinchTarget();
      this.resetPrefetchKeys();
      this.pinchState = undefined;
      this.suppressDeferredDataVmSyncCount = this.dataVm.endPinchFreeze();
      this.snapshotController?.hideSnapshot();
      this.forcePruneVisibleThumbnailCache();
      this.clearIdleExpandPrebuildState();
      this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
      this.scheduleIdleExpandPrebuild(IDLE_PREBUILD_DELAY_MS);
      this.notifyStateChanged();
    }, PINCH_RESET_DURATION_MS + 16);
  }

  /**
   * Returns liveScale clamped to the one-step arrival scale once the target is latched.
   * Arrival scale = 1 / targetBaseScale (the liveScale at which the dormant grid reaches scale=1).
   * - EXPAND: cap liveScale from above (don't spread beyond arrival)
   * - SHRINK: floor liveScale from below (don't pinch beyond arrival)
   */
  private resolveDisplayLiveScale(state: HybridPinchStateInfo): number {
    if (!this.latchedTargetActive || state.targetBaseScale <= 0 || state.targetBaseScale === 1) {
      return state.liveScale;
    }
    const arrivalLiveScale = 1.0 / state.targetBaseScale;
    if (state.targetDirection === HybridPinchTargetDirection.EXPAND) {
      return Math.min(state.liveScale, arrivalLiveScale);
    }
    if (state.targetDirection === HybridPinchTargetDirection.SHRINK) {
      return Math.max(state.liveScale, arrivalLiveScale);
    }
    return state.liveScale;
  }

  private retainCrossScalePixelMaps(state: HybridPinchStateInfo): void {
    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0 || this.listWidth <= 0 || this.listHeight <= 0) {
      return;
    }
    const oldColumns = state.startColumns;
    const oldRequestSize = Shared.resolveHybridRequestSizeBucket(
      Math.max(1, oldColumns),
      this.listWidth,
      Shared.HybridThumbnailLayerRole.WARM,
    );
    const retainRange = this.resolvePhotoRangeForOffsetWithOverscan(
      oldColumns,
      0,
      this.currentScrollOffsetY,
      assets.length,
      this.resolveViewportRowsForColumns(oldColumns),
      this.resolveViewportRowsForColumns(oldColumns),
    );
    const retainKeys: Array<string> = [];
    for (let i = retainRange.start; i <= retainRange.end; i += 1) {
      const asset = assets[i];
      if (asset) {
        retainKeys.push(Thumbnail.buildThumbnailCacheKey(asset.id, oldRequestSize));
      }
    }
    if (retainKeys.length > 0) {
      Thumbnail.HybridThumbnailCache.touchRetainedKeys(retainKeys);
    }
  }

  private resolveFadeStartVisualScale(state: HybridPinchStateInfo): number {
    if (state.targetDirection === HybridPinchTargetDirection.SHRINK) {
      return FADE_START_SCALE_DOWN;
    }
    if (state.targetDirection === HybridPinchTargetDirection.EXPAND) {
      return FADE_START_SCALE_UP;
    }
    return 1;
  }

  private ensureMainVisibleRowsWarm(commitState: HybridGridColumnsCommitState): boolean {
    if (this.gridColumns <= 0) {
      return true;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      return true;
    }

    const range = this.resolveMainViewportPhotoRange(commitState, assets.length, 0);
    if (range.end < range.start) {
      return true;
    }

    return this.ensurePhotoRangeWarm(assets, range, this.resolveCommittedRequestSize());
  }

  private prefetchMainOverscan(commitState: HybridGridColumnsCommitState): boolean {
    if (this.gridColumns <= 0) {
      return true;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      return true;
    }

    const range = this.resolveMainViewportPhotoRange(commitState, assets.length, 2);
    if (range.end < range.start) {
      return true;
    }

    const key = this.buildPrefetchRangeKey(
      'main_overscan',
      commitState.columns,
      0,
      commitState.targetScrollOffset,
      range,
    );
    if (key !== this.lastMainOverscanPrefetchKey) {
      this.lastMainOverscanPrefetchKey = key;
      return this.prefetchPhotoRange(assets, range, this.resolveCommittedRequestSize());
    }
    return this.ensurePhotoRangeWarm(assets, range, this.resolveCommittedRequestSize());
  }

  private resolvePreviewViewportPhotoRange(
    pinchState: HybridPinchStateInfo,
    totalPhotoCount: number,
    overscanRows: number,
  ): HybridPreviewViewportRange {
    return this.resolvePhotoRangeForOffset(
      pinchState.targetColumns,
      pinchState.fillPosition,
      pinchState.targetScrollOffset,
      totalPhotoCount,
      overscanRows,
    );
  }

  private resolvePhotoRangeForOffset(
    columns: number,
    fillPosition: number,
    scrollOffset: number,
    totalPhotoCount: number,
    overscanRows: number,
  ): HybridPreviewViewportRange {
    return this.resolvePhotoRangeForOffsetWithOverscan(
      columns,
      fillPosition,
      scrollOffset,
      totalPhotoCount,
      overscanRows,
      overscanRows,
    );
  }

  private resolvePhotoRangeForOffsetWithOverscan(
    columns: number,
    fillPosition: number,
    scrollOffset: number,
    totalPhotoCount: number,
    overscanAboveRows: number,
    overscanBelowRows: number,
  ): HybridPreviewViewportRange {
    const range = new HybridPreviewViewportRange();
    if (columns <= 0 || this.listHeight <= 0 || this.listWidth <= 0 || totalPhotoCount <= 0) {
      return range;
    }

    const itemSize = HybridSwitchCalc.calcItemSize(columns, this.listWidth);
    const itemExtent = itemSize + Shared.HYBRID_GRID_GAP;
    if (itemExtent <= 0) {
      return range;
    }

    const firstVisibleGridRow = Math.max(0, Math.floor(scrollOffset / itemExtent));
    const visibleRows = Math.max(1, Math.ceil(this.listHeight / itemExtent));
    const startGridRow = Math.max(0, firstVisibleGridRow - Math.max(0, overscanAboveRows));
    const endGridRow = firstVisibleGridRow + visibleRows + Math.max(0, overscanBelowRows);
    const startGridIndex = startGridRow * columns;
    const endGridIndex = Math.max(startGridIndex, (endGridRow * columns) - 1);
    range.start = Math.max(0, startGridIndex - fillPosition);
    range.end = Math.min(totalPhotoCount - 1, Math.max(range.start, endGridIndex - fillPosition));
    return range;
  }

  private resolveMainViewportPhotoRange(
    commitState: HybridGridColumnsCommitState,
    totalPhotoCount: number,
    overscanRows: number,
  ): HybridPreviewViewportRange {
    const range = new HybridPreviewViewportRange();
    const columns = Math.max(1, commitState.columns);
    const fillPosition = this.resolveCommittedFillPosition();
    if (columns <= 0 || totalPhotoCount <= 0) {
      return range;
    }

    const startIndex = Math.max(
      0,
      (this.resolveCommittedVisibleStartIndex() >= 0
        ? this.resolveCommittedVisibleStartIndex()
        : this.resolveCommittedExpectedFirstGridIndex(commitState)) - fillPosition,
    );
    const endIndex = Math.max(
      startIndex,
      (this.resolveCommittedVisibleEndIndex() >= 0 ? this.resolveCommittedVisibleEndIndex() : startIndex) - fillPosition,
    );
    const visibleRows = Math.max(1, Math.ceil((endIndex - startIndex + 1) / columns));
    const startRow = Math.max(0, Math.floor(startIndex / columns) - overscanRows);
    const endRow = Math.floor(endIndex / columns) + visibleRows + overscanRows;
    range.start = Math.max(0, startRow * columns);
    range.end = Math.min(totalPhotoCount - 1, Math.max(range.start, ((endRow + 1) * columns) - 1));
    return range;
  }

  private ensurePhotoRangeWarm(
    assets: Array<Shared.HybridPhotoAsset>,
    range: HybridPreviewViewportRange,
    requestSize: number,
  ): boolean {
    let allReady = true;
    for (let index = range.start; index <= range.end; index += 1) {
      const asset = assets[index];
      if (!asset) {
        continue;
      }
      const cacheKey = Thumbnail.buildThumbnailCacheKey(asset.id, requestSize);
      if (!Thumbnail.HybridThumbnailCache.hasReady(cacheKey)) {
        allReady = false;
        Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize);
      }
    }
    return allReady;
  }

  private prefetchPhotoRange(
    assets: Array<Shared.HybridPhotoAsset>,
    range: HybridPreviewViewportRange,
    requestSize: number,
  ): boolean {
    let allReady = true;
    for (let index = range.start; index <= range.end; index += 1) {
      const asset = assets[index];
      if (!asset) {
        continue;
      }
      const cacheKey = Thumbnail.buildThumbnailCacheKey(asset.id, requestSize);
      if (!Thumbnail.HybridThumbnailCache.hasReady(cacheKey)) {
        allReady = false;
        Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize);
      }
    }
    return allReady;
  }

  private schedulePendingCommitSync(delayMs: number): void {
    if (
      !this.pendingCommit ||
      (this.commitPhase !== HybridPinchCommitPhase.SETTLING &&
        this.commitPhase !== HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY)
    ) {
      return;
    }
    if (this.commitSyncTimeoutId !== undefined) {
      clearTimeout(this.commitSyncTimeoutId);
      this.commitSyncTimeoutId = undefined;
    }
    this.commitSyncTimeoutId = setTimeout((): void => {
      this.commitSyncTimeoutId = undefined;
      this.syncPendingCommit();
    }, Math.max(0, delayMs));
  }

  private syncPendingCommit(): void {
    const pendingCommit = this.pendingCommit;
    if (
      !pendingCommit ||
      this.mainGridCommitReady ||
      (this.commitPhase !== HybridPinchCommitPhase.SETTLING &&
        this.commitPhase !== HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY)
    ) {
      return;
    }
    const deadlineExceeded = Date.now() >= this.commitDeadlineMs;
    if (this.gridColumns !== pendingCommit.columns) {
      if (deadlineExceeded) {
        this.commitPhase = HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY;
        this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
        return;
      }
      this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
      return;
    }

    const committedFillPosition = this.resolveCommittedFillPosition();
    const committedGridItemCount = this.resolveCommittedGridDataSource()?.totalCount() ?? 0;
    if (
      committedGridItemCount <= 0 ||
      committedGridItemCount <= pendingCommit.targetAnchorPhotoIndex + committedFillPosition
    ) {
      if (deadlineExceeded) {
        this.commitPhase = HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY;
        this.commitAlignPhase = HybridCommitAlignPhase.WAITING_READY;
        this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
        return;
      }
      this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
      return;
    }

    let currentOffset = this.currentScrollOffsetY;
    try {
      currentOffset = Math.max(0, this.resolveCommittedScroller()?.currentOffset().yOffset ?? currentOffset);
    } catch (_error) {}
    this.currentScrollOffsetY = currentOffset;

    const offsetReady = Math.abs(currentOffset - this.pendingCommitScrollOffset) <= PINCH_COMMIT_OFFSET_TOLERANCE;
    const expectedFirstGridIndex = this.resolveCommittedExpectedFirstGridIndex(pendingCommit);
    const indexTolerance = Math.max(1, pendingCommit.columns);
    const indexReady =
      this.resolveCommittedVisibleStartIndex() >= 0 &&
      Math.abs(this.resolveCommittedVisibleStartIndex() - expectedFirstGridIndex) <= indexTolerance;
    const visibleRowsWarm = offsetReady && indexReady && this.ensureMainVisibleRowsWarm(pendingCommit);
    this.prefetchMainOverscan(pendingCommit);
    const commitVisualReady = offsetReady && indexReady && visibleRowsWarm;
    this.mainCommitOffsetReady = offsetReady;
    this.mainCommitIndexReady = indexReady;
    this.mainVisibleRowsWarm = visibleRowsWarm;

    if (this.commitPhase === HybridPinchCommitPhase.SETTLING) {
      if (!offsetReady && this.commitAlignPhase === HybridCommitAlignPhase.INITIAL_ALIGN) {
        try {
          this.resolveCommittedScroller()?.scrollTo({ xOffset: 0, yOffset: this.pendingCommitScrollOffset });
        } catch (_error) {}
        this.commitAlignPhase = HybridCommitAlignPhase.CORRECTIVE_ALIGN;
        this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
        return;
      }

      if (!offsetReady && this.commitAlignPhase === HybridCommitAlignPhase.CORRECTIVE_ALIGN) {
        try {
          this.resolveCommittedScroller()?.scrollTo({ xOffset: 0, yOffset: this.pendingCommitScrollOffset });
        } catch (_error) {}
        this.commitAlignPhase = HybridCommitAlignPhase.WAITING_READY;
        this.commitPhase = HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY;
        this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
        return;
      }

      if (offsetReady || this.commitAlignPhase === HybridCommitAlignPhase.CORRECTIVE_ALIGN) {
        this.commitAlignPhase = HybridCommitAlignPhase.WAITING_READY;
        this.commitPhase = HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY;
      }
    }

    if (commitVisualReady) {
      if (!this.mainFirstPaintArmed) {
        this.mainFirstPaintArmed = true;
        this.mainFirstPaintStableCount = 0;
        this.mainFirstPaintReady = false;
        if (this.mainFirstPaintTimeoutId !== undefined) {
          clearTimeout(this.mainFirstPaintTimeoutId);
        }
        this.mainFirstPaintTimeoutId = setTimeout((): void => {
          this.mainFirstPaintTimeoutId = undefined;
          if (!this.pendingCommit) {
            return;
          }
          this.syncPendingCommit();
        }, PINCH_COMMIT_RETRY_DELAY_MS);
      } else {
        this.mainFirstPaintStableCount = Math.min(3, this.mainFirstPaintStableCount + 1);
        this.mainFirstPaintReady = this.mainFirstPaintStableCount >= 3;
        if (!this.mainFirstPaintReady && this.mainFirstPaintTimeoutId === undefined) {
          this.mainFirstPaintTimeoutId = setTimeout((): void => {
            this.mainFirstPaintTimeoutId = undefined;
            if (!this.pendingCommit) {
              return;
            }
            this.syncPendingCommit();
          }, PINCH_COMMIT_RETRY_DELAY_MS);
        }
      }
    } else {
      this.mainFirstPaintArmed = false;
      this.mainFirstPaintStableCount = 0;
      this.mainFirstPaintReady = false;
      if (this.mainFirstPaintTimeoutId !== undefined) {
        clearTimeout(this.mainFirstPaintTimeoutId);
        this.mainFirstPaintTimeoutId = undefined;
      }
    }

    const isReady = commitVisualReady && this.mainFirstPaintReady;
    this.mainGridCommitReady = isReady;
    if (isReady) {
      this.finalizePendingCommit();
      return;
    }

    this.pendingCommitRetryCount += 1;
    if (deadlineExceeded) {
      this.commitPhase = HybridPinchCommitPhase.SETTLED_WAIT_MAIN_READY;
      this.commitAlignPhase = HybridCommitAlignPhase.WAITING_READY;
    }
    this.schedulePendingCommitSync(PINCH_COMMIT_RETRY_DELAY_MS);
  }

  private finalizePendingCommit(): void {
    if (!this.pendingCommit) {
      return;
    }

    if (this.commitSyncTimeoutId !== undefined) {
      clearTimeout(this.commitSyncTimeoutId);
      this.commitSyncTimeoutId = undefined;
    }
    if (this.mainFirstPaintTimeoutId !== undefined) {
      clearTimeout(this.mainFirstPaintTimeoutId);
      this.mainFirstPaintTimeoutId = undefined;
    }
    this.commitPhase = HybridPinchCommitPhase.FINALIZED;
    this.commitAlignPhase = HybridCommitAlignPhase.FINALIZED;
    this.syncCurrentScrollOffset();
    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());

    // Crossfade: animate main grid in and preview grid out to avoid white flash
    this.setCurrentVisible(true);
    this.animateFastOutSlowIn(PINCH_COMMIT_FADE_DURATION_MS, (): void => {
      this.setCurrentOpacity(1);
    });

    // Defer full cleanup until crossfade finishes
    this.stageTwoTimeoutId = setTimeout((): void => {
      this.stageTwoTimeoutId = undefined;
      this.committedLayerKind = HybridCommittedLayerKind.MAIN;
      this.committedFillPosition = 0;
      this.pendingCommit = undefined;
      this.hasPendingCommit = false;
      this.pendingCommitRetryCount = 0;
      this.pendingCommitScrollOffset = 0;
      this.mainVisibleStartIndex = -1;
      this.mainVisibleEndIndex = -1;
      this.mainCommitOffsetReady = false;
      this.mainCommitIndexReady = false;
      this.mainVisibleRowsWarm = false;
      this.mainFirstPaintArmed = false;
      this.mainFirstPaintStableCount = 0;
      this.mainFirstPaintReady = false;
      this.mainGridCommitReady = false;
      this.commitPhase = HybridPinchCommitPhase.IDLE;
      this.commitStartedAt = 0;
      this.commitDeadlineMs = 0;
      this.commitAlignPhase = HybridCommitAlignPhase.FINALIZED;
      this.resetLatchedPinchTarget();
      this.resetPrefetchKeys();
      this.pinchState = undefined;
      this.suppressDeferredDataVmSyncCount = this.dataVm.endPinchFreeze();
      this.snapshotController?.hideSnapshot();
      this.forcePruneVisibleThumbnailCache();
      this.clearIdleExpandPrebuildState();
      this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
      this.scheduleIdleExpandPrebuild(IDLE_PREBUILD_DELAY_MS);
      this.notifyStateChanged();
    }, PINCH_COMMIT_FADE_DURATION_MS + 16);
  }

  private animateLinear(duration: number, action: () => void): void {
    const uiContext = AppStorage.get<UIContext>('uiContext');
    if (uiContext) {
      uiContext.animateTo(
        {
          duration: duration,
          curve: Curve.Linear,
        },
        action,
      );
      return;
    }
    action();
  }

  private animateFastOutSlowIn(duration: number, action: () => void): void {
    const uiContext = AppStorage.get<UIContext>('uiContext');
    if (uiContext) {
      uiContext.animateTo(
        {
          duration: duration,
          curve: Curve.FastOutSlowIn,
        },
        action,
      );
      return;
    }
    action();
  }

  private animateEaseOut(duration: number, action: () => void): void {
    const uiContext = AppStorage.get<UIContext>('uiContext');
    if (uiContext) {
      uiContext.animateTo(
        {
          duration: duration,
          curve: Curve.EaseOut,
        },
        action,
      );
      return;
    }
    action();
  }

  private cancelPendingAnimations(): void {
    if (this.stageOneTimeoutId !== undefined) {
      clearTimeout(this.stageOneTimeoutId);
      this.stageOneTimeoutId = undefined;
    }
    if (this.stageTwoTimeoutId !== undefined) {
      clearTimeout(this.stageTwoTimeoutId);
      this.stageTwoTimeoutId = undefined;
    }
    if (this.mainFirstPaintTimeoutId !== undefined) {
      clearTimeout(this.mainFirstPaintTimeoutId);
      this.mainFirstPaintTimeoutId = undefined;
    }
    if (this.commitSyncTimeoutId !== undefined) {
      clearTimeout(this.commitSyncTimeoutId);
      this.commitSyncTimeoutId = undefined;
    }
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    if (this.idlePrebuildSyncTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildSyncTimeoutId);
      this.idlePrebuildSyncTimeoutId = undefined;
    }
  }

  private getBaseTopInsetHeight(): number {
    return 0;
  }

  private formatVisibleNumber(value: number): string {
    if (!Number.isFinite(value)) {
      return 'nan';
    }
    return value.toFixed(3);
  }

  private buildVisibleStateKey(): string {
    return [
      this.itemCount,
      this.hasCompletedFirstLoad ? 1 : 0,
      this.isLoading ? 1 : 0,
      this.errorText,
    ].join('|');
  }

  private notifyStateChanged(): void {
    this.syncWarmLayerState();
    if (this.stateListeners.length <= 0) {
      return;
    }
    const nextVisibleStateKey = this.buildVisibleStateKey();
    if (nextVisibleStateKey === this.visibleStateKey) {
      return;
    }
    this.visibleStateKey = nextVisibleStateKey;
    this.stateListeners.forEach((listener: () => void) => {
      listener();
    });
  }

  private logMemoryDebug(reason: string): void {
    const shrinkItems = this.resolveShrinkTargetDataSource()?.totalCount() ?? 0;
    const expandItems = this.resolveExpandTargetDataSource()?.totalCount() ?? 0;
    console.info(
      `[HybridPhotoGridVm] memory ${reason}: currentItems=${this.resolveCurrentDataSource()?.totalCount() ?? 0}, shrinkItems=${shrinkItems}, expandItems=${expandItems}, cacheEntries=${Thumbnail.HybridThumbnailCache.entryCount()}, sections=${this.sections.length}, timelineItems=${this.currentItems.length}`,
    );
  }
}
