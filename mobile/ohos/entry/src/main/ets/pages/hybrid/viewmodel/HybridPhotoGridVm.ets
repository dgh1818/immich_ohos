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
import { HybridGridSnapshotVc } from '../viewcontroller/HybridGridSnapshotVc';

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
const PINCH_PREVIEW_READY_RETRY_DELAY_MS: number = 16;
const PINCH_PREVIEW_READY_MAX_RETRIES: number = 24;
const PINCH_PREVIEW_READY_OFFSET_TOLERANCE: number = 1.5;
const IDLE_PREBUILD_DELAY_MS: number = 120;
const IDLE_PREBUILD_READY_RETRY_DELAY_MS: number = 32;
const IDLE_PREBUILD_OFFSET_TOLERANCE: number = 1.5;
const FADE_START_SCALE_DOWN: number = 1.06;
const FADE_START_SCALE_UP: number = 0.94;
const PINCH_SHRINK_ENTER_SCALE: number = 0.98;
const PINCH_SHRINK_CANCEL_SCALE: number = 1.01;
const PINCH_EXPAND_ENTER_SCALE: number = 1.02;
const PINCH_EXPAND_CANCEL_SCALE: number = 0.99;
const PINCH_PREVIEW_BOOTSTRAP_FRAME_DELAY_MS: number = 16;

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

enum HybridPreviewScrollPhase {
  IDLE = 0,
  COMMANDED = 1,
  OBSERVING = 2,
  READY = 3,
}

enum HybridCommitAlignPhase {
  INITIAL_ALIGN = 0,
  CORRECTIVE_ALIGN = 1,
  WAITING_READY = 2,
  FINALIZED = 3,
}

enum HybridCommittedLayerKind {
  MAIN = 0,
}

@Observed
export class HybridPhotoGridVm {
  private readonly context: common.UIAbilityContext;
  private readonly dataVm: HybridDayGridVm;
  private readonly dataAdapter: HybridPhotoGridDataAdapter = new HybridPhotoGridDataAdapter();
  public readonly actionAdapter: HybridPhotoGridActionAdapter = new HybridPhotoGridActionAdapter();
  private readonly anchorAdapter: HybridPhotoGridAnchorAdapter = new HybridPhotoGridAnchorAdapter();
  private stateListeners: Array<() => void> = [];
  private mainScroller?: Scroller;
  private previewScroller?: Scroller;
  private idlePreviewScroller?: Scroller;
  private mainGridDataSource?: Shared.HybridGridDataSource;
  private previewGridDataSource?: Shared.HybridGridDataSource;
  private idlePreviewGridDataSource?: Shared.HybridGridDataSource;
  private timelineDataSource?: Shared.HybridTimelineDataSource;
  private snapshotController?: HybridGridSnapshotVc;
  private pinchState?: HybridPinchStateInfo;
  private initialized: boolean = false;
  private timelineInitialized: boolean = false;
  private lastAppliedColumns: number = Shared.HYBRID_GRID_COLUMNS;
  private stageOneTimeoutId?: number;
  private stageTwoTimeoutId?: number;
  private previewSyncTimeoutId?: number;
  private commitSyncTimeoutId?: number;
  private renderedGridVersion: number = 0;
  private previewPreparedColumns: number = 0;
  private previewPreparedFillPosition: number = 0;
  private previewPreparedGridVersion: number = -1;
  private previewPreparedScrollOffset: number = 0;
  private previewVisibleStartIndex: number = -1;
  private previewVisibleEndIndex: number = -1;
  private previewAreaReady: boolean = false;
  private idlePreviewAreaReady: boolean = false;
  private previewPreparing: boolean = false;
  private previewDataReady: boolean = false;
  private previewPositionReady: boolean = false;
  private previewVisibleRowsWarm: boolean = false;
  private previewViewportWarm: boolean = false;
  private previewReady: boolean = false;
  private previewBootstrapReady: boolean = false;
  private previewLatchedVisible: boolean = false;
  private previewCommitReady: boolean = false;
  private previewBootstrapFrame: boolean = false;
  private previewCoverageReady: boolean = false;
  private previewSyncToken: number = 0;
  private previewSyncRetryCount: number = 0;
  private previewBootstrapTimeoutId?: number;
  private previewBootstrapToken: number = 0;
  private previewScrollPhase: HybridPreviewScrollPhase = HybridPreviewScrollPhase.IDLE;
  private previewScrollIssuedForToken: number = -1;
  private previewBootstrapFrozen: boolean = false;
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
  private idlePrebuildVisibleRowsWarm: boolean = false;
  private idlePrebuildReady: boolean = false;
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
  @Track public mainGridScale: number = 1;
  @Track public mainGridOpacity: number = 1;
  @Track public mainGridVisible: boolean = true;
  @Track public pinchActive: boolean = false;
  @Track public pinchCenterX: number = 0;
  @Track public pinchCenterY: number = 0;
  @Track public previewVisible: boolean = false;
  @Track public previewWarmActive: boolean = false;
  @Track public previewOpacity: number = 0;
  @Track public previewColumns: number = 0;
  @Track public idlePreviewColumns: number = 0;
  @Track public idlePreviewWarmActive: boolean = false;
  @Track public useIdlePrebuiltPreview: boolean = false;
  @Track public previewScale: number = 1;
  @Track public previewTranslateX: number = 0;
  @Track public previewTranslateY: number = 0;
  @Track public hasPendingCommit: boolean = false;
  @Track public committedLayerKind: HybridCommittedLayerKind = HybridCommittedLayerKind.MAIN;

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
  }

  public bindSnapshotController(snapshotController: HybridGridSnapshotVc): void {
    this.snapshotController = snapshotController;
  }

  public bindMainScroller(scroller: Scroller): void {
    this.mainScroller = scroller;
    this.schedulePendingCommitSync(0);
  }

  public bindPreviewScroller(scroller: Scroller): void {
    this.previewScroller = scroller;
    this.syncPreviewLayer();
  }

  public bindIdlePreviewScroller(scroller: Scroller): void {
    this.idlePreviewScroller = scroller;
    this.scheduleIdleShrinkPrebuild(0);
  }

  public bindMainGridDataSource(dataSource: Shared.HybridGridDataSource): void {
    this.mainGridDataSource = dataSource;
    this.mainGridDataSource.updateAllIfChanged(this.currentGridItems.slice());
  }

  public bindPreviewGridDataSource(dataSource: Shared.HybridGridDataSource): void {
    this.previewGridDataSource = dataSource;
    this.syncPreviewLayer();
  }

  public bindIdlePreviewGridDataSource(dataSource: Shared.HybridGridDataSource): void {
    this.idlePreviewGridDataSource = dataSource;
    this.scheduleIdleShrinkPrebuild(0);
  }

  public bindTimelineDataSource(dataSource: Shared.HybridTimelineDataSource): void {
    this.timelineDataSource = dataSource;
    this.timelineDataSource.replaceAll(this.currentItems.slice());
    this.timelineInitialized = true;
    this.lastAppliedColumns = this.gridColumns;
  }

  public onPreviewAreaChange(width: number, height: number): void {
    const ready = width > 0 && height > 0;
    if (this.previewAreaReady === ready) {
      return;
    }
    this.previewAreaReady = ready;
    this.syncPreviewLayer();
  }

  public onIdlePreviewAreaChange(width: number, height: number): void {
    const ready = width > 0 && height > 0;
    if (this.idlePreviewAreaReady === ready) {
      return;
    }
    this.idlePreviewAreaReady = ready;
    this.scheduleIdleShrinkPrebuild(0);
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
    this.clearIdlePrebuildState(false);
    this.itemCount = 0;
    this.hasCompletedFirstLoad = false;
    this.sections = [];
    this.currentItems = [];
    this.currentGridItems = [];
    this.dataVm.removeDataLoadListener(this.dataLoadListener);
    this.dataVm.release();
    this.mainGridDataSource?.updateAllIfChanged([]);
    this.previewGridDataSource?.updateAllIfChanged([]);
    this.idlePreviewGridDataSource?.updateAllIfChanged([]);
    this.timelineDataSource?.replaceAll([]);
    this.snapshotController?.hideSnapshot();
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.previewPreparing = false;
    this.previewDataReady = false;
    this.previewPositionReady = false;
    this.previewVisibleRowsWarm = false;
    this.previewViewportWarm = false;
    this.previewReady = false;
    this.previewBootstrapReady = false;
    this.previewLatchedVisible = false;
    this.previewCommitReady = false;
    this.previewBootstrapFrame = false;
    this.previewCoverageReady = false;
    this.previewWarmActive = false;
    this.previewAreaReady = false;
    this.idlePreviewAreaReady = false;
    this.previewSyncToken += 1;
    this.previewSyncRetryCount = 0;
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
    this.idlePreviewWarmActive = false;
    this.visibleStateKey = '';
    this.committedFillPosition = 0;
    this.mainScroller = undefined;
    this.previewScroller = undefined;
    this.idlePreviewScroller = undefined;
    this.mainGridDataSource = undefined;
    this.previewGridDataSource = undefined;
    this.idlePreviewGridDataSource = undefined;
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
    this.syncCurrentScrollOffset();
    let idleStateChanged = false;
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    if (
      !this.pinchActive &&
      this.pendingCommit === undefined &&
      this.commitPhase === HybridPinchCommitPhase.IDLE
    ) {
      this.clearIdlePrebuildState(false);
      idleStateChanged = true;
    }
    this.dataVm.onScrollStart();
    if (idleStateChanged) {
      this.notifyStateChanged();
    }
  }

  public onScrollStop(): void {
    this.syncCurrentScrollOffset();
    this.dataVm.onScrollStop();
    this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
  }

  public onScrollIndex(start: number, end: number): void {
    this.mainVisibleStartIndex = Math.max(0, start);
    this.mainVisibleEndIndex = Math.max(this.mainVisibleStartIndex, end);
    this.syncCurrentScrollOffset();
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
    this.notifyStateChanged();
  }

  public onPreviewScrollStart(): void {
    if (!this.isPreviewLayerInteractive()) {
      return;
    }
    this.syncCurrentScrollOffset();
    let idleStateChanged = false;
    if (this.idlePrebuildTimeoutId !== undefined) {
      clearTimeout(this.idlePrebuildTimeoutId);
      this.idlePrebuildTimeoutId = undefined;
    }
    if (!this.pinchActive && this.pendingCommit === undefined && this.commitPhase === HybridPinchCommitPhase.IDLE) {
      this.clearIdlePrebuildState(false);
      idleStateChanged = true;
    }
    this.dataVm.onScrollStart();
    if (idleStateChanged) {
      this.notifyStateChanged();
    }
  }

  public onPreviewScrollStop(): void {
    if (!this.isPreviewLayerInteractive()) {
      return;
    }
    this.syncCurrentScrollOffset();
    this.dataVm.onScrollStop();
    this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
  }

  public onPreviewScrollIndex(start: number, end: number): void {
    this.previewVisibleStartIndex = Math.max(0, start);
    this.previewVisibleEndIndex = Math.max(this.previewVisibleStartIndex, end);
    if (this.isPreviewLayerInteractive()) {
      this.syncCurrentScrollOffset();
      const fillPosition = this.resolveCommittedFillPosition();
      const rowStart = this.resolveTimelineRowIndexFromGridIndex(start, fillPosition);
      const rowEnd = this.resolveTimelineRowIndexFromGridIndex(end, fillPosition);
      this.updateFloatingSection(rowStart);
      this.dataVm.onScrollIndex(rowStart, rowEnd);
      this.notifyStateChanged();
      return;
    }
    if (this.previewPreparing && this.pinchState && this.previewSyncTimeoutId === undefined) {
      this.schedulePreviewReadinessCheck(
        this.previewSyncToken,
        Math.max(0, this.pinchState.targetScrollOffset),
        this.pinchState.fillPosition,
        0,
      );
    }
  }

  public onPinchStart(centerX: number, centerY: number): void {
    if (this.listWidth <= 0 || this.listHeight <= 0) {
      return;
    }

    this.cancelPendingAnimations();
    this.suppressDeferredDataVmSyncCount = 0;
    this.syncCurrentScrollOffset();
    this.normalizeCommittedPreviewLayerForPinchStart();
    this.dataVm.beginPinchFreeze();
    this.syncCurrentScrollOffset();
    this.dataVm.handlePinchStart(centerX, centerY);
    const totalPhotoCount = this.dataAdapter.flattenAssets(this.sections).length;
    this.pinchState = this.anchorAdapter.createPinchState(
      this.gridColumns,
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
    this.mainGridVisible = true;
    this.mainGridOpacity = 1;
    this.mainGridScale = 1;
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
    if (!this.hasReusableIdleShrinkPrebuild()) {
      this.prewarmAdjacentPinchTargets(centerX, centerY, totalPhotoCount);
    }
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
    this.pinchCenterX = this.pinchState.sharedCenterX;
    this.pinchCenterY = this.pinchState.sharedCenterY;
    this.mainGridVisible = true;
    this.mainGridScale = this.pinchState.liveScale;

    if (this.pinchState.targetColumns !== this.gridColumns) {
      const reuseIdlePrebuild =
        this.useIdlePrebuiltPreview || (!this.previewLatchedVisible && this.canReuseIdlePrebuild(this.pinchState));
      if (!reuseIdlePrebuild && this.previewColumns !== this.pinchState.targetColumns) {
        this.previewColumns = this.pinchState.targetColumns;
      }
      if (this.shouldSyncPreviewForCurrentPinch(this.pinchState, reuseIdlePrebuild)) {
        this.syncPreviewLayer();
      }
      this.syncPreviewPresentation();
      this.notifyStateChanged();
      return;
    }

    this.resetLatchedPinchTarget();
    this.resetPreviewTransactionState();
    this.pinchCenterX = this.pinchState.pinchCenterX;
    this.pinchCenterY = this.pinchState.pinchCenterY;
    this.mainGridVisible = true;
    this.mainGridOpacity = 1;
    this.notifyStateChanged();
  }

  public onPinchEnd(): void {
    if (!this.pinchActive) {
      return;
    }

    this.dataVm.handlePinchEnd();
    this.pinchActive = false;

    const activePinchState = this.pinchState;
    if (activePinchState && activePinchState.targetColumns !== this.gridColumns) {
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

  public isMainLayerVisible(): boolean {
    return this.mainGridVisible;
  }

  public isPreviewLayerInteractive(): boolean {
    return false;
  }

  public resolveMainRequestSize(): number {
    return Shared.resolveHybridRequestSizeBucket(
      this.gridColumns,
      this.listWidth,
      Shared.HybridThumbnailLayerRole.ACTIVE,
    );
  }

  public resolvePreviewRequestSize(): number {
    return Shared.resolveHybridRequestSizeBucket(
      Math.max(1, this.previewColumns > 0 ? this.previewColumns : this.gridColumns),
      this.listWidth,
      Shared.HybridThumbnailLayerRole.PREVIEW,
    );
  }

  public resolveIdlePreviewRequestSize(): number {
    return Shared.resolveHybridRequestSizeBucket(
      Math.max(1, this.idlePreviewColumns > 0 ? this.idlePreviewColumns : this.gridColumns),
      this.listWidth,
      Shared.HybridThumbnailLayerRole.WARM,
    );
  }

  private syncDataVmRequestSize(): void {
    this.dataVm.setRequestSize(this.resolveMainRequestSize());
  }

  private resetPreviewTransactionState(): void {
    if (this.previewSyncTimeoutId !== undefined) {
      clearTimeout(this.previewSyncTimeoutId);
      this.previewSyncTimeoutId = undefined;
    }
    if (this.previewBootstrapTimeoutId !== undefined) {
      clearTimeout(this.previewBootstrapTimeoutId);
      this.previewBootstrapTimeoutId = undefined;
    }
    this.previewPreparing = false;
    this.previewDataReady = false;
    this.previewPositionReady = false;
    this.previewVisibleRowsWarm = false;
    this.previewViewportWarm = false;
    this.previewReady = false;
    this.previewBootstrapReady = false;
    this.previewLatchedVisible = false;
    this.previewCommitReady = false;
    this.previewBootstrapFrame = false;
    this.previewCoverageReady = false;
    this.previewSyncToken += 1;
    this.previewSyncRetryCount = 0;
    this.previewBootstrapToken += 1;
    this.previewScrollPhase = HybridPreviewScrollPhase.IDLE;
    this.previewScrollIssuedForToken = -1;
    this.previewBootstrapFrozen = false;
    this.previewVisible = false;
    this.previewWarmActive = false;
    this.previewOpacity = 0;
    this.previewColumns = 0;
    this.idlePreviewColumns = 0;
    this.idlePreviewWarmActive = false;
    this.useIdlePrebuiltPreview = false;
    this.previewItems = [];
    this.previewPreparedColumns = 0;
    this.previewPreparedFillPosition = 0;
    this.previewPreparedGridVersion = -1;
    this.previewPreparedScrollOffset = Number.NaN;
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.previewScale = 1;
    this.previewTranslateX = 0;
    this.previewTranslateY = 0;
    this.lastPreviewOverscanPrefetchKey = '';
    this.lastMainOverscanPrefetchKey = '';
  }

  private resetLatchedPinchTarget(): void {
    this.latchedTargetActive = false;
    this.latchedTargetColumns = this.gridColumns;
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
    this.idlePrebuildVisibleRowsWarm = false;
    this.idlePrebuildReady = false;
    this.idlePreviewColumns = 0;
    this.idlePreviewWarmActive = false;
    this.lastIdleVisiblePrefetchKey = '';
    this.lastIdleOverscanPrefetchKey = '';
    this.lastShrinkPrewarmPrefetchKey = '';
    if (clearDataSource) {
      this.idlePreviewGridDataSource?.updateAllIfChanged([]);
    }
  }

  private resetPrefetchKeys(): void {
    this.lastPreviewOverscanPrefetchKey = '';
    this.lastMainOverscanPrefetchKey = '';
    this.lastIdleVisiblePrefetchKey = '';
    this.lastIdleOverscanPrefetchKey = '';
    this.lastShrinkPrewarmPrefetchKey = '';
  }

  private syncWarmLayerState(): void {
    const previewTargetActive = this.previewColumns > 0 && this.previewColumns !== this.gridColumns;
    const idleTargetActive = this.idlePreviewColumns > 0 && this.idlePreviewColumns !== this.gridColumns;
    const idlePrebuildPrepared =
      idleTargetActive &&
      this.idlePrebuildVersion >= 0 &&
      this.idlePrebuildColumns === this.idlePreviewColumns &&
      this.idlePrebuildColumns !== this.gridColumns;
    this.previewWarmActive =
      previewTargetActive &&
      !this.useIdlePrebuiltPreview &&
      (this.previewPreparing || this.previewLatchedVisible || this.previewVisible || this.pendingCommit !== undefined);
    this.idlePreviewWarmActive =
      idleTargetActive &&
      (
        idlePrebuildPrepared ||
        this.idlePrebuildReady ||
        (this.useIdlePrebuiltPreview &&
          (this.previewPreparing || this.previewLatchedVisible || this.previewVisible || this.pendingCommit !== undefined))
      );
  }

  private resolveCommittedScroller(): Scroller | undefined {
    return this.mainScroller;
  }

  private resolveCommittedGridDataSource(): Shared.HybridGridDataSource | undefined {
    return this.mainGridDataSource;
  }

  private resolveCommittedVisibleStartIndex(): number {
    return this.mainVisibleStartIndex;
  }

  private resolveCommittedVisibleEndIndex(): number {
    return this.mainVisibleEndIndex;
  }

  private resolveCommittedFillPosition(): number {
    return 0;
  }

  private resolveCommittedExpectedFirstGridIndex(commitState: HybridGridColumnsCommitState): number {
    return Math.max(0, commitState.targetFirstPhotoIndex + this.resolveCommittedFillPosition());
  }

  private resolveCommittedRequestSize(): number {
    return this.resolveMainRequestSize();
  }

  private buildCommittedGridItems(): Array<HybridGridItem> {
    return this.dataAdapter.buildGridItemsForColumns(
      this.sections,
      this.gridColumns,
      this.getBaseTopInsetHeight(),
      this.hasMore,
      this.resolveCommittedFillPosition(),
      true,
    );
  }

  private updateCommittedGridDataSource(items: Array<HybridGridItem>): void {
    this.currentGridItems = items.slice();
    this.mainGridDataSource?.updateAllIfChanged(this.currentGridItems);
  }

  private normalizeCommittedPreviewLayerForPinchStart(): void {
    this.committedLayerKind = HybridCommittedLayerKind.MAIN;
    this.committedFillPosition = 0;
    this.useIdlePrebuiltPreview = false;
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
      !this.idlePreviewScroller ||
      !this.idlePreviewGridDataSource ||
      !this.idlePreviewAreaReady ||
      this.listWidth <= 0 ||
      this.listHeight <= 0
    ) {
      return;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      this.clearIdlePrebuildState(false);
      return;
    }

    const centerX = this.listWidth * 0.5;
    const centerY = this.getBaseTopInsetHeight() + this.listHeight * 0.5;
    const idleState = this.anchorAdapter.createPinchState(
      this.gridColumns,
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
      idleState.targetColumns === this.gridColumns
    ) {
      this.clearIdlePrebuildState(false);
      return;
    }

    const needsRefresh =
      this.idlePrebuildVersion !== this.renderedGridVersion ||
      this.idlePrebuildColumns !== idleState.targetColumns ||
      this.idlePrebuildFillPosition !== idleState.fillPosition;

    if (needsRefresh) {
      const previewGridItems = this.dataAdapter.buildGridItemsForColumns(
        this.sections,
        idleState.targetColumns,
        0,
        this.hasMore,
        idleState.fillPosition,
        true,
      );
      this.idlePreviewGridDataSource.updateAllIfChanged(previewGridItems);
    }

    this.idlePrebuildColumns = idleState.targetColumns;
    this.idlePreviewColumns = idleState.targetColumns;
    this.idlePrebuildFillPosition = idleState.fillPosition;
    this.idlePrebuildTargetScrollOffset = idleState.targetScrollOffset;
    this.idlePrebuildTargetFirstPhotoIndex = idleState.targetFirstPhotoIndex;
    this.idlePrebuildTargetAnchorPhotoIndex = idleState.targetAnchorPhotoIndex;
    this.idlePrebuildTargetFirstRowIndex = idleState.targetFirstRowIndex;
    this.idlePrebuildTargetAnchorRowIndex = idleState.targetAnchorRowIndex;
    this.idlePrebuildResolvedFocusX = idleState.resolvedFocusX;
    this.idlePrebuildResolvedFocusY = idleState.resolvedFocusY;
    this.idlePrebuildTargetBaseScale = idleState.targetBaseScale;
    this.idlePrebuildVersion = this.renderedGridVersion;
    this.idlePrebuildVisibleRowsWarm = false;
    this.idlePrebuildReady = false;
    this.notifyStateChanged();

    try {
      this.idlePreviewScroller.scrollTo({ xOffset: 0, yOffset: this.idlePrebuildTargetScrollOffset });
    } catch (_error) {}

    const visibleRange = this.resolvePhotoRangeForOffset(
      idleState.targetColumns,
      idleState.fillPosition,
      idleState.targetScrollOffset,
      assets.length,
      0,
    );
    const visibleKey = this.buildPrefetchRangeKey(
      'idle_visible',
      idleState.targetColumns,
      idleState.fillPosition,
      idleState.targetScrollOffset,
      visibleRange,
    );
    if (visibleKey !== this.lastIdleVisiblePrefetchKey) {
      this.lastIdleVisiblePrefetchKey = visibleKey;
      this.prefetchPhotoRange(assets, visibleRange, this.resolveIdlePreviewRequestSize());
    }

    const token = ++this.idlePrebuildToken;
    this.scheduleIdlePrebuildReadinessCheck(token, this.idlePrebuildTargetScrollOffset);
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
    if (
      token !== this.idlePrebuildToken ||
      this.pinchActive ||
      !this.idlePreviewScroller ||
      this.idlePrebuildVersion !== this.renderedGridVersion
    ) {
      return;
    }

    let currentOffset = Number.NaN;
    try {
      currentOffset = Math.max(0, this.idlePreviewScroller.currentOffset().yOffset);
    } catch (_error) {}

    const assets = this.dataAdapter.flattenAssets(this.sections);
    const offsetReady =
      !Number.isNaN(currentOffset) &&
      Math.abs(currentOffset - targetScrollOffset) <= IDLE_PREBUILD_OFFSET_TOLERANCE;
    const visibleRange = this.resolvePhotoRangeForOffset(
      this.idlePrebuildColumns,
      this.idlePrebuildFillPosition,
      this.idlePrebuildTargetScrollOffset,
      assets.length,
      0,
    );
    const visibleRowsWarm = offsetReady &&
      this.ensurePhotoRangeWarm(assets, visibleRange, this.resolveIdlePreviewRequestSize());
    const overscanRange = this.resolvePhotoRangeForOffset(
      this.idlePrebuildColumns,
      this.idlePrebuildFillPosition,
      this.idlePrebuildTargetScrollOffset,
      assets.length,
      2,
    );
    const overscanKey = this.buildPrefetchRangeKey(
      'idle_overscan',
      this.idlePrebuildColumns,
      this.idlePrebuildFillPosition,
      this.idlePrebuildTargetScrollOffset,
      overscanRange,
    );
    if (overscanKey !== this.lastIdleOverscanPrefetchKey) {
      this.lastIdleOverscanPrefetchKey = overscanKey;
      this.prefetchPhotoRange(assets, overscanRange, this.resolveIdlePreviewRequestSize());
    }

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
    if (!this.idlePrebuildReady && !this.pinchActive) {
      this.scheduleIdlePrebuildReadinessCheck(token, targetScrollOffset);
    }
  }

  private canReuseIdlePrebuild(state: HybridPinchStateInfo): boolean {
    if (
      !this.idlePrebuildReady ||
      !this.idlePreviewScroller ||
      !this.idlePreviewGridDataSource ||
      !this.idlePreviewAreaReady ||
      state.targetDirection !== HybridPinchTargetDirection.SHRINK
    ) {
      return false;
    }
    const itemSize = HybridSwitchCalc.calcItemSize(state.targetColumns, this.listWidth);
    const itemExtent = itemSize + Shared.HYBRID_GRID_GAP;
    const offsetTolerance = Math.max(IDLE_PREBUILD_OFFSET_TOLERANCE, itemExtent * 1.5);
    const anchorTolerance = Math.max(1, state.targetColumns * 2);
    return (
      this.idlePrebuildVersion === this.renderedGridVersion &&
      this.idlePrebuildColumns === state.targetColumns &&
      this.idlePrebuildFillPosition === state.fillPosition &&
      Math.abs(this.idlePrebuildTargetScrollOffset - state.targetScrollOffset) <= offsetTolerance &&
      Math.abs(this.idlePrebuildTargetAnchorPhotoIndex - state.targetAnchorPhotoIndex) <= anchorTolerance
    );
  }

  private reconcileLatchedPinchTarget(state: HybridPinchStateInfo): void {
    if (!this.latchedTargetActive) {
      const enterShrink =
        state.targetDirection === HybridPinchTargetDirection.SHRINK &&
        state.targetColumns !== this.gridColumns &&
        state.liveScale <= PINCH_SHRINK_ENTER_SCALE;
      const enterExpand =
        state.targetDirection === HybridPinchTargetDirection.EXPAND &&
        state.targetColumns !== this.gridColumns &&
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
      this.idlePrebuildColumns !== this.gridColumns &&
      this.idlePreviewAreaReady &&
      this.idlePreviewScroller !== undefined &&
      this.idlePreviewGridDataSource !== undefined;
  }

  private shouldSyncPreviewForCurrentPinch(
    state: HybridPinchStateInfo,
    reuseIdlePrebuild: boolean,
  ): boolean {
    if (state.targetColumns === this.gridColumns) {
      return false;
    }

    if (reuseIdlePrebuild) {
      return !this.useIdlePrebuiltPreview ||
        this.previewPreparedColumns !== this.idlePrebuildColumns ||
        this.previewPreparedFillPosition !== this.idlePrebuildFillPosition ||
        this.previewPreparedGridVersion < 0 ||
        (this.previewScrollPhase === HybridPreviewScrollPhase.IDLE && !this.previewLatchedVisible);
    }

    return this.previewPreparedColumns !== state.targetColumns ||
      this.previewPreparedFillPosition !== state.fillPosition ||
      this.previewPreparedGridVersion < 0 ||
      (
        this.previewScrollPhase === HybridPreviewScrollPhase.IDLE &&
        !this.previewLatchedVisible &&
        !this.previewPreparing
      );
  }

  private resetPinchTargetToCurrentGrid(state: HybridPinchStateInfo): void {
    state.targetColumns = this.gridColumns;
    state.targetDirection = HybridPinchTargetDirection.NONE;
    state.fillPosition = 0;
    state.targetScrollOffset = Math.max(0, this.currentScrollOffsetY);
    state.targetFirstPhotoIndex = Math.max(0, state.anchor.itemIndex);
    state.targetAnchorPhotoIndex = Math.max(0, state.anchor.itemIndex);
    state.targetFirstRowIndex = Math.floor(state.targetFirstPhotoIndex / Math.max(1, this.gridColumns));
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
      this.gridColumns,
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      this.getBaseTopInsetHeight(),
      totalPhotoCount,
    );
    this.anchorAdapter.updatePinchState(tempState, scale, centerX, centerY);
    if (tempState.targetColumns === this.gridColumns) {
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

  private isPreparedPreviewDataReady(targetColumns: number, targetFillPosition: number): boolean {
    const previewItemCount = this.previewGridDataSource?.totalCount() ?? 0;
    return this.previewPreparedColumns === targetColumns &&
      this.previewPreparedFillPosition === targetFillPosition &&
      this.previewPreparedGridVersion >= 0 &&
      previewItemCount > targetFillPosition;
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
    return this.gridColumns === this.dataVm.getGridColumns() &&
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

    if (
      this.pinchState &&
      this.previewColumns > 0 &&
      this.previewColumns !== this.gridColumns &&
      !this.pinchActive &&
      !this.previewPreparing &&
      !this.previewLatchedVisible &&
      !this.pendingCommit
    ) {
      this.syncPreviewLayer();
    }

    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
    if (!this.pinchActive) {
      this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
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
      this.lastAppliedColumns !== this.gridColumns
    ) {
      this.timelineDataSource.replaceAll(nextItems);
      this.timelineInitialized = true;
      this.lastAppliedColumns = this.gridColumns;
      return;
    }

    this.timelineDataSource.reconcile(nextItems);
    this.lastAppliedColumns = this.gridColumns;
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
    const rowHeight = this.resolveTimelineRowHeight(this.gridColumns);
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
    return Math.floor(safeIndex / Math.max(1, this.gridColumns));
  }

  private syncPreviewLayer(): void {
    if (!this.pinchState || this.pinchState.targetColumns === this.gridColumns) {
      return;
    }

    const targetColumns = this.pinchState.targetColumns;
    const targetFillPosition = this.pinchState.fillPosition;
    const reuseIdlePrebuild = this.useIdlePrebuiltPreview || (!this.previewLatchedVisible && this.canReuseIdlePrebuild(this.pinchState));
    this.useIdlePrebuiltPreview = reuseIdlePrebuild;
    if (reuseIdlePrebuild) {
      this.idlePreviewColumns = this.idlePrebuildColumns;
      this.previewPreparedColumns = this.idlePrebuildColumns;
      this.previewPreparedFillPosition = this.idlePrebuildFillPosition;
      this.previewPreparedGridVersion = this.idlePrebuildVersion;
      this.previewPreparedScrollOffset = this.idlePrebuildTargetScrollOffset;
      this.previewBootstrapToken = this.previewSyncToken;
      this.previewScrollIssuedForToken = this.previewBootstrapToken;
      this.previewScrollPhase = this.idlePrebuildReady
        ? HybridPreviewScrollPhase.READY
        : HybridPreviewScrollPhase.OBSERVING;
      this.previewPreparing = !this.idlePrebuildReady;
      this.previewDataReady = true;
      this.previewPositionReady = this.idlePrebuildReady;
      this.previewVisibleRowsWarm = this.idlePrebuildVisibleRowsWarm;
      this.previewViewportWarm = true;
      this.previewReady = this.idlePrebuildReady;
      this.previewBootstrapReady = this.idlePrebuildReady;
      this.previewCoverageReady = this.idlePrebuildReady;
      this.previewBootstrapFrozen = this.idlePrebuildReady;
      if (this.idlePrebuildReady) {
        this.latchPreviewVisible();
      }
      this.syncPreviewPresentation();
      return;
    }

    const previewTransactionLocked =
      this.pinchActive ||
      this.previewPreparing ||
      this.previewLatchedVisible ||
      this.pendingCommit !== undefined;
    const needsGridRefresh =
      this.previewPreparedColumns !== targetColumns ||
      this.previewPreparedFillPosition !== targetFillPosition ||
      this.previewPreparedGridVersion < 0 ||
      (!previewTransactionLocked &&
        !this.previewBootstrapFrozen &&
        this.previewPreparedGridVersion !== this.renderedGridVersion);

    if (needsGridRefresh) {
      const previewGridItems = this.dataAdapter.buildGridItemsForColumns(
        this.sections,
        targetColumns,
        0,
        this.hasMore,
        targetFillPosition,
        true,
      );
      this.previewGridDataSource?.updateAllIfChanged(previewGridItems);
      this.previewPreparedColumns = targetColumns;
      this.previewPreparedFillPosition = targetFillPosition;
      this.previewPreparedGridVersion = this.renderedGridVersion;
      this.previewPreparedScrollOffset = Number.NaN;
      this.previewVisibleStartIndex = -1;
      this.previewVisibleEndIndex = -1;
      this.previewScrollPhase = HybridPreviewScrollPhase.IDLE;
      this.previewScrollIssuedForToken = -1;
      this.previewBootstrapFrozen = false;
      this.previewDataReady = previewGridItems.length > targetFillPosition;
      if (!this.previewLatchedVisible) {
        this.previewPreparing = true;
        this.previewPositionReady = false;
        this.previewVisibleRowsWarm = false;
        this.previewViewportWarm = false;
        this.previewReady = false;
        this.previewBootstrapReady = false;
        this.previewCoverageReady = false;
      }
    }

    if (!this.previewScroller || !this.previewAreaReady) {
      if (!this.previewLatchedVisible) {
        this.previewPreparing = true;
        this.previewDataReady = this.isPreparedPreviewDataReady(targetColumns, targetFillPosition);
        this.previewPositionReady = false;
        this.previewVisibleRowsWarm = false;
        this.previewViewportWarm = false;
        this.previewReady = false;
        this.previewBootstrapReady = false;
        this.previewCoverageReady = false;
      }
      return;
    }

    if (this.previewPreparing && !needsGridRefresh) {
      return;
    }

    if (this.previewLatchedVisible && !needsGridRefresh) {
      return;
    }

    const targetScrollOffset = Math.max(0, this.pinchState.targetScrollOffset);
    if (
      !needsGridRefresh &&
      Math.abs(this.previewPreparedScrollOffset - targetScrollOffset) <= 0.5 &&
      this.previewBootstrapReady
    ) {
      return;
    }

    this.previewPreparing = true;
    this.previewDataReady = this.isPreparedPreviewDataReady(targetColumns, targetFillPosition);
    this.previewPositionReady = false;
    this.previewVisibleRowsWarm = false;
    this.previewViewportWarm = false;
    this.previewReady = false;
    this.previewBootstrapReady = false;
    this.previewCoverageReady = false;
    if (this.previewSyncTimeoutId !== undefined) {
      clearTimeout(this.previewSyncTimeoutId);
      this.previewSyncTimeoutId = undefined;
    }
    const syncToken = ++this.previewSyncToken;
    this.previewSyncRetryCount = 0;
    this.schedulePreviewReadinessCheck(syncToken, targetScrollOffset, targetFillPosition, 0);
  }

  private syncCurrentScrollOffset(): void {
    try {
      this.currentScrollOffsetY = Math.max(0, this.resolveCommittedScroller()?.currentOffset().yOffset ?? 0);
    } catch (_error) {}
  }

  private runPinchTransition(state: HybridPinchStateInfo): void {
    this.syncPreviewLayer();
    const fadeStartVisualScale = this.resolveFadeStartVisualScale(state);
    const currentVisualScale = state.targetVisualScale;
    const needsStageOne =
      state.targetDirection === HybridPinchTargetDirection.SHRINK
        ? currentVisualScale > fadeStartVisualScale
        : currentVisualScale < fadeStartVisualScale;

    this.previewVisible = this.previewLatchedVisible;
    this.previewOpacity = this.previewLatchedVisible ? 1 : 0;
    this.mainGridVisible = true;

    if (!needsStageOne) {
      this.runFadeAndSettleStage(state);
      return;
    }

    const sharedScaleAtFadeStart = this.anchorAdapter.resolveSharedScaleForVisualScale(state, fadeStartVisualScale);
    const stageOneTransform = this.anchorAdapter.resolvePreviewTransformForVisualScale(state, fadeStartVisualScale);
    this.animateLinear(PINCH_STAGE_ONE_DURATION_MS, (): void => {
      this.mainGridScale = sharedScaleAtFadeStart;
      this.mainGridOpacity = 1;
      this.previewScale = stageOneTransform.scale;
      this.previewTranslateX = stageOneTransform.translateX;
      this.previewTranslateY = stageOneTransform.translateY;
    });
    this.stageOneTimeoutId = setTimeout((): void => {
      this.stageOneTimeoutId = undefined;
      this.runFadeAndSettleStage(state);
    }, PINCH_STAGE_ONE_DURATION_MS);
  }

  private runFadeAndSettleStage(state: HybridPinchStateInfo): void {
    this.syncPreviewLayer();
    if (!this.previewCoverageReady) {
      this.stageTwoTimeoutId = setTimeout((): void => {
        this.stageTwoTimeoutId = undefined;
        this.runFadeAndSettleStage(state);
      }, 16);
      return;
    }
    const settledTransform = this.anchorAdapter.resolveSettledPreviewTransform(state);
    this.animateFastOutSlowIn(PINCH_STAGE_TWO_DURATION_MS, (): void => {
      this.previewScale = 1;
      this.previewTranslateX = settledTransform.translateX;
      this.previewTranslateY = settledTransform.translateY;
      this.mainGridOpacity = 0;
    });
    this.stageTwoTimeoutId = setTimeout((): void => {
      this.stageTwoTimeoutId = undefined;
      this.applyPinchTargetColumns(state);
    }, PINCH_STAGE_TWO_DURATION_MS);
  }

  private resolveCommittedGridItemsFromPromotedLayer(): Array<HybridGridItem> {
    if (this.useIdlePrebuiltPreview) {
      return this.idlePreviewGridDataSource?.getItemsSnapshot() ?? [];
    }
    return this.previewGridDataSource?.getItemsSnapshot() ?? [];
  }

  private applyPinchTargetColumns(state: HybridPinchStateInfo): void {
    const finalScrollOffset = this.anchorAdapter.resolveFinalScrollOffset(state);
    const commitState = new HybridGridColumnsCommitState();
    commitState.columns = state.targetColumns;
    commitState.targetFirstPhotoIndex = state.targetFirstPhotoIndex;
    commitState.targetAnchorPhotoIndex = state.targetAnchorPhotoIndex;
    commitState.targetFirstRowIndex = state.targetFirstRowIndex;
    commitState.targetAnchorRowIndex = state.targetAnchorRowIndex;
    commitState.targetScrollOffset = finalScrollOffset;
    this.pendingCommit = commitState;
    this.hasPendingCommit = true;
    this.pendingCommitRetryCount = 0;
    this.pendingCommitScrollOffset = finalScrollOffset;
    this.mainGridCommitReady = false;
    this.commitPhase = HybridPinchCommitPhase.SETTLING;
    this.commitAlignPhase = HybridCommitAlignPhase.INITIAL_ALIGN;
    this.commitStartedAt = Date.now();
    this.commitDeadlineMs = this.commitStartedAt + PINCH_COMMIT_MAX_DURATION_MS;
    this.gridColumns = state.targetColumns;
    this.mainGridScale = 1;
    this.mainGridOpacity = 0;
    this.previewScale = 1;
    this.previewTranslateX = 0;
    this.previewTranslateY = 0;
    this.pinchCenterX = state.sharedCenterX;
    this.pinchCenterY = state.sharedCenterY;
    this.previewVisible = this.previewLatchedVisible;
    this.previewOpacity = this.previewLatchedVisible ? 1 : 0;
    this.previewCommitReady = false;
    this.committedFillPosition = 0;
    this.previewColumns = state.targetColumns;
    this.previewPreparedColumns = state.targetColumns;
    this.previewPreparedFillPosition = state.fillPosition;
    this.previewPreparedGridVersion = this.renderedGridVersion;
    this.previewPreparedScrollOffset = finalScrollOffset;
    this.previewVisibleStartIndex = -1;
    this.previewVisibleEndIndex = -1;
    this.previewPreparing = false;
    this.previewDataReady = true;
    this.previewPositionReady = false;
    this.previewVisibleRowsWarm = false;
    this.previewViewportWarm = false;
    this.previewReady = false;
    this.previewBootstrapReady = false;
    this.previewCoverageReady = false;
    this.previewScrollPhase = HybridPreviewScrollPhase.OBSERVING;
    this.committedLayerKind = HybridCommittedLayerKind.MAIN;
    this.dataVm.silentSetGridColumns(this.gridColumns, commitState);
    this.syncSilentColumnsFromDataVm();
    this.currentScrollOffsetY = finalScrollOffset;
    this.mainVisibleStartIndex = -1;
    this.mainVisibleEndIndex = -1;
    this.mainGridVisible = true;
    this.previewVisible = true;
    this.previewOpacity = 1;
    this.schedulePendingCommitSync(0);
    this.notifyStateChanged();
  }

  private animateResetToCurrentGrid(): void {
    this.animateEaseOut(PINCH_RESET_DURATION_MS, (): void => {
      this.mainGridScale = 1;
      this.mainGridOpacity = 1;
      this.previewOpacity = 0;
      this.previewScale = 1;
      this.previewTranslateX = 0;
      this.previewTranslateY = 0;
    });
    this.stageTwoTimeoutId = setTimeout((): void => {
      this.stageTwoTimeoutId = undefined;
      if (this.previewBootstrapTimeoutId !== undefined) {
        clearTimeout(this.previewBootstrapTimeoutId);
        this.previewBootstrapTimeoutId = undefined;
      }
      this.previewVisible = false;
      this.previewItems = [];
      this.previewColumns = 0;
      this.previewPreparedColumns = 0;
      this.previewPreparedFillPosition = 0;
      this.previewPreparedGridVersion = -1;
      this.previewPreparedScrollOffset = 0;
      this.previewVisibleStartIndex = -1;
      this.previewVisibleEndIndex = -1;
      this.previewPreparing = false;
      this.previewDataReady = false;
      this.previewPositionReady = false;
      this.previewVisibleRowsWarm = false;
      this.previewViewportWarm = false;
      this.previewReady = false;
      this.previewBootstrapReady = false;
      this.previewLatchedVisible = false;
      this.previewCommitReady = false;
      this.previewBootstrapFrame = false;
      this.previewCoverageReady = false;
      this.previewSyncToken += 1;
      this.previewSyncRetryCount = 0;
      this.previewScale = 1;
      this.previewTranslateX = 0;
      this.previewTranslateY = 0;
      this.mainGridVisible = true;
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
      this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
      this.notifyStateChanged();
    }, PINCH_RESET_DURATION_MS);
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

  private resolveMainGridOpacity(state: HybridPinchStateInfo): number {
    if (state.targetColumns === state.startColumns) {
      return 1;
    }

    if (!this.previewCoverageReady) {
      return 1;
    }

    if (state.targetDirection === HybridPinchTargetDirection.SHRINK) {
      if (state.targetVisualScale > FADE_START_SCALE_DOWN) {
        return 1;
      }
      return Math.max(0, Math.min(1, (state.targetVisualScale - 1) / (FADE_START_SCALE_DOWN - 1)));
    }

    if (state.targetDirection === HybridPinchTargetDirection.EXPAND) {
      if (state.targetVisualScale < FADE_START_SCALE_UP) {
        return 1;
      }
      return Math.max(0, Math.min(1, (1 - state.targetVisualScale) / (1 - FADE_START_SCALE_UP)));
    }

    return 1;
  }

  private schedulePreviewReadinessCheck(
    syncToken: number,
    targetScrollOffset: number,
    targetFillPosition: number,
    delayMs: number,
  ): void {
    this.previewSyncTimeoutId = setTimeout((): void => {
      this.previewSyncTimeoutId = undefined;
      this.checkPreviewReadiness(syncToken, targetScrollOffset, targetFillPosition);
    }, Math.max(0, delayMs));
  }

  private latchPreviewVisible(): void {
    if (this.previewLatchedVisible) {
      return;
    }
    this.previewLatchedVisible = true;
    this.previewBootstrapFrozen = true;
    this.previewScrollPhase = HybridPreviewScrollPhase.READY;
    this.previewBootstrapFrame = true;
    if (this.previewBootstrapTimeoutId !== undefined) {
      clearTimeout(this.previewBootstrapTimeoutId);
      this.previewBootstrapTimeoutId = undefined;
    }
    this.previewBootstrapTimeoutId = setTimeout((): void => {
      this.previewBootstrapTimeoutId = undefined;
      if (!this.previewLatchedVisible) {
        return;
      }
      this.previewBootstrapFrame = false;
      this.syncPreviewPresentation();
      this.notifyStateChanged();
    }, PINCH_PREVIEW_BOOTSTRAP_FRAME_DELAY_MS);
  }

  private checkPreviewReadiness(
    syncToken: number,
    targetScrollOffset: number,
    targetFillPosition: number,
  ): void {
    if (syncToken !== this.previewSyncToken) {
      return;
    }
    if (!this.pinchState || this.pinchState.targetColumns === this.gridColumns) {
      return;
    }
    if (!this.previewScroller || !this.previewAreaReady) {
      this.previewPreparing = true;
      this.previewDataReady = this.isPreparedPreviewDataReady(
        this.pinchState.targetColumns,
        targetFillPosition,
      );
      this.previewPositionReady = false;
      this.previewVisibleRowsWarm = false;
      this.previewViewportWarm = false;
      this.previewReady = false;
      this.previewBootstrapReady = false;
      this.previewCoverageReady = false;
      this.previewScrollPhase = HybridPreviewScrollPhase.IDLE;
      this.syncPreviewPresentation();
      this.notifyStateChanged();
      return;
    }

    if (this.previewScrollIssuedForToken !== syncToken) {
      this.previewBootstrapToken = syncToken;
      this.previewScrollIssuedForToken = syncToken;
      this.previewScrollPhase = HybridPreviewScrollPhase.COMMANDED;
      try {
        this.previewScroller.scrollTo({ xOffset: 0, yOffset: targetScrollOffset });
      } catch (_error) {}
    } else if (this.previewScrollPhase === HybridPreviewScrollPhase.COMMANDED) {
      this.previewScrollPhase = HybridPreviewScrollPhase.OBSERVING;
    }

    let currentOffset = Number.NaN;
    try {
      currentOffset = Math.max(0, this.previewScroller.currentOffset().yOffset);
    } catch (_error) {}

    const dataReady = this.isPreparedPreviewDataReady(this.pinchState.targetColumns, targetFillPosition);
    const coverageReady = this.previewAreaReady && dataReady;
    const offsetReady =
      !Number.isNaN(currentOffset) &&
      Math.abs(currentOffset - targetScrollOffset) <= PINCH_PREVIEW_READY_OFFSET_TOLERANCE;
    const positionReady = offsetReady;
    const visibleRowsWarm = positionReady && this.ensurePreviewVisibleRowsWarm();
    const viewportWarm = positionReady && this.prefetchPreviewOverscan();

    if (coverageReady && positionReady && visibleRowsWarm) {
      this.previewPreparedScrollOffset = currentOffset;
      this.previewPreparing = false;
      this.previewDataReady = true;
      this.previewPositionReady = true;
      this.previewVisibleRowsWarm = true;
      this.previewViewportWarm = viewportWarm;
      this.previewReady = true;
      this.previewBootstrapReady = true;
      this.previewCoverageReady = true;
      this.previewScrollPhase = HybridPreviewScrollPhase.READY;
      this.latchPreviewVisible();
      this.syncPreviewPresentation();
      this.notifyStateChanged();
      return;
    }

    this.previewPreparedScrollOffset = Number.isNaN(currentOffset) ? Number.NaN : currentOffset;
    if (!this.previewLatchedVisible) {
      this.previewPreparing = true;
      this.previewDataReady = dataReady;
      this.previewPositionReady = positionReady;
      this.previewVisibleRowsWarm = visibleRowsWarm;
      this.previewViewportWarm = viewportWarm;
      this.previewReady = false;
      this.previewBootstrapReady = false;
      this.previewCoverageReady = false;
      if (this.previewScrollPhase === HybridPreviewScrollPhase.IDLE) {
        this.previewScrollPhase = HybridPreviewScrollPhase.OBSERVING;
      }
      this.syncPreviewPresentation();
    }
    this.previewSyncRetryCount += 1;
    if (this.pinchActive) {
      this.schedulePreviewReadinessCheck(
        syncToken,
        targetScrollOffset,
        targetFillPosition,
        PINCH_PREVIEW_READY_RETRY_DELAY_MS,
      );
    }
    this.notifyStateChanged();
  }

  private syncPreviewPresentation(): void {
    if (!this.pinchState || this.pinchState.targetColumns === this.gridColumns) {
      return;
    }

    const previewVisualScale = this.previewBootstrapFrame
      ? this.pinchState.targetBaseScale
      : this.pinchState.targetVisualScale;
    const transform = this.anchorAdapter.resolvePreviewTransformForVisualScale(
      this.pinchState,
      previewVisualScale,
    );
    this.previewScale = transform.scale;
    this.previewTranslateX = transform.translateX;
    this.previewTranslateY = transform.translateY;

    if (this.previewLatchedVisible) {
      this.previewVisible = true;
      this.previewOpacity = 1;
      if (this.pinchActive && !this.pendingCommit) {
        this.mainGridOpacity = 1;
      }
      return;
    }

    if (this.pinchActive && !this.pendingCommit) {
      this.previewVisible = false;
      this.previewOpacity = 0;
      this.mainGridOpacity = 1;
    }
  }

  private isPreviewViewportIndexReady(): boolean {
    const pinchState = this.pinchState;
    if (!pinchState || pinchState.targetColumns <= 0) {
      return false;
    }
    if (this.previewVisibleStartIndex < 0) {
      return false;
    }

    const expectedFirstGridIndex = Math.max(0, pinchState.targetFirstPhotoIndex + pinchState.fillPosition);
    const tolerance = Math.max(1, pinchState.targetColumns);
    return Math.abs(this.previewVisibleStartIndex - expectedFirstGridIndex) <= tolerance;
  }

  private ensurePreviewVisibleRowsWarm(): boolean {
    const pinchState = this.pinchState;
    if (!pinchState || pinchState.targetColumns <= 0) {
      return true;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      return true;
    }

    const range = this.resolvePreviewViewportPhotoRange(pinchState, assets.length, 0);
    if (range.end < range.start) {
      return true;
    }

    return this.ensurePhotoRangeWarm(assets, range, this.resolvePreviewRequestSize());
  }

  private prefetchPreviewOverscan(): boolean {
    const pinchState = this.pinchState;
    if (!pinchState || pinchState.targetColumns <= 0) {
      return true;
    }

    const assets = this.dataAdapter.flattenAssets(this.sections);
    if (assets.length <= 0) {
      return true;
    }

    const range = this.resolvePreviewViewportPhotoRange(pinchState, assets.length, 2);
    if (range.end < range.start) {
      return true;
    }

    const key = this.buildPrefetchRangeKey(
      'preview_overscan',
      pinchState.targetColumns,
      pinchState.fillPosition,
      pinchState.targetScrollOffset,
      range,
    );
    if (key !== this.lastPreviewOverscanPrefetchKey) {
      this.lastPreviewOverscanPrefetchKey = key;
      return this.prefetchPhotoRange(assets, range, this.resolvePreviewRequestSize());
    }
    return this.ensurePhotoRangeWarm(assets, range, this.resolvePreviewRequestSize());
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
    const startGridRow = Math.max(0, firstVisibleGridRow - overscanRows);
    const endGridRow = firstVisibleGridRow + visibleRows + overscanRows;
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
        this.mainFirstPaintStableCount = Math.min(2, this.mainFirstPaintStableCount + 1);
        this.mainFirstPaintReady = this.mainFirstPaintStableCount >= 2;
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
    this.previewCommitReady = isReady;
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
    this.previewCommitReady = true;
    this.syncCurrentScrollOffset();
    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
    if (this.previewBootstrapTimeoutId !== undefined) {
      clearTimeout(this.previewBootstrapTimeoutId);
      this.previewBootstrapTimeoutId = undefined;
    }
    this.mainGridVisible = true;
    this.mainGridOpacity = 1;
    this.previewVisible = false;
    this.previewOpacity = 0;
    this.previewColumns = 0;
    this.previewPreparedColumns = 0;
    this.previewPreparedFillPosition = 0;
    this.previewPreparedGridVersion = -1;
    this.previewPreparedScrollOffset = 0;
    this.previewPreparing = false;
    this.previewDataReady = false;
    this.previewPositionReady = false;
    this.previewVisibleRowsWarm = false;
    this.previewViewportWarm = false;
    this.previewReady = false;
    this.previewBootstrapReady = false;
    this.previewLatchedVisible = false;
    this.previewCommitReady = false;
    this.previewBootstrapFrame = false;
    this.previewCoverageReady = false;
    this.previewSyncToken += 1;
    this.previewSyncRetryCount = 0;
    this.previewScale = 1;
    this.previewTranslateX = 0;
    this.previewTranslateY = 0;
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
    this.clearIdlePrebuildState(false);
    this.suppressDeferredDataVmSyncCount = this.dataVm.endPinchFreeze();
    this.snapshotController?.hideSnapshot();
    this.forcePruneVisibleThumbnailCache();
    this.scheduleIdleShrinkPrebuild(IDLE_PREBUILD_DELAY_MS);
    this.notifyStateChanged();
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
    if (this.previewSyncTimeoutId !== undefined) {
      clearTimeout(this.previewSyncTimeoutId);
      this.previewSyncTimeoutId = undefined;
    }
    if (this.previewBootstrapTimeoutId !== undefined) {
      clearTimeout(this.previewBootstrapTimeoutId);
      this.previewBootstrapTimeoutId = undefined;
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
}
