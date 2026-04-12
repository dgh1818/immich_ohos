import { common } from '@kit.AbilityKit';
import { LengthMetrics } from '@kit.ArkUI';
import { HybridFlutterBridge } from '../../../bridge/HybridFlutterBridge';
import * as Shared from '../PhotoGridShared';
import * as Thumbnail from '../PhotoThumbnail';
import { TimelineLayoutBuilder } from '../TimelineLayoutBuilder';
import { GridSnapshotController } from '../viewcontroller/GridSnapshotController';
import { GridAttributeUpdater } from '../viewcontroller/GridAttributeUpdater';
import { FormGridVc, FormGridVcCallbacks } from '../viewcontroller/FormGridVc';
import { PhotoGridActionAdapter } from '../adapter/PhotoGridActionAdapter';
import { PhotoGridDataAdapter, FloatingSectionInfo } from '../adapter/PhotoGridDataAdapter';
import {
  GridAnchorAdapter,
  PinchStateInfo,
  PinchTargetDirection,
} from '../adapter/GridAnchorAdapter';
import { SwitchCalcParams, SwitchCalcUtils } from './SwitchCalcUtils';
import {
  TimelineDataManager,
  TimelinePreloadReason,
  TimelinePreloadRequest,
  TimelinePreloadResult,
} from '../model/TimelineDataManager';
import { DataLoadListener, TimelineGridViewModel, GridColumnsCommitState } from './TimelineGridViewModel';
import {
  DEFAULT_CACHE_COUNT,
  DEFAULT_COLUMN,
  DEFAULT_GUTTER,
  FormIndex,
  getColumnsByFormIndex,
  getFormIndexByColumns,
} from '../statemanager/constants/GridDefine';
import { GridFormFsm, FormEventTypeUtils } from '../statemanager/GridFormFsm';
import {
  GridPreloadFsm,
  PreloadEventType,
  PreloadStateType,
  PreloadStateTypeUtils,
} from '../statemanager/GridPreloadFsm';
import {
  GridShowFsm,
  ShowEventType,
  ShowStateType,
  ShowStateTypeUtils,
} from '../statemanager/GridShowFsm';
import { PinchStateManager, PinchStateUpdateParams } from '../statemanager/PinchStateManager';
import { PinchAction } from '../statemanager/constants/PinchDefine';
import { SwitchStartInfo, SwitchType } from '../statemanager/common/SwitchStartInfo';
import { GridStateProxy } from '../statemanager/GridStateProxy';

type PhotoAsset = Shared.PhotoAsset;
type BucketInfo = Shared.BucketInfo;
type GroupInfo = Shared.GroupInfo;
type PhotoSection = Shared.PhotoSection;
type TimelineItem = Shared.TimelineItem;
type GridItem = Shared.GridItem;

const PINCH_RESET_DURATION_MS: number = 160;
const PINCH_COMMIT_DURATION_MS: number = 150;
const FILL_POSITION_RESTORE_DELAY_MS: number = 350;
const PRELOAD_TIMEOUT_MS: number = 180;
const PINCH_SHRINK_ENTER_SCALE: number = 0.98;
const EXPAND_MIN_OPACITY: number = 0.15;

const FORM_ORDER: Array<FormIndex> = [
  FormIndex.YEAR,
  FormIndex.MONTH,
  FormIndex.DAY,
  FormIndex.GROUP_DAY,
];

export class FormGridState {
  public readonly form: FormIndex;
  public readonly columns: number;
  public readonly attributeUpdater: GridAttributeUpdater = new GridAttributeUpdater();
  public readonly preloadFsm: GridPreloadFsm = new GridPreloadFsm();
  public readonly showFsm: GridShowFsm = new GridShowFsm();
  public scroller?: Scroller = undefined;
  public dataSource?: Shared.GridDataSource = undefined;
  public visible: boolean = false;
  public interactive: boolean = false;
  public warmActive: boolean = false;
  public cacheRows: number;
  public fillPosition: number = 0;
  public firstVisibleIndex: number = 0;
  public showState: ShowStateType = ShowStateType.INIT_STATE;
  public preloadState: PreloadStateType = PreloadStateType.INIT_STATE;
  public preloadRequestKey: string = '';
  public preloadAnchorGridIndex: number = 0;
  public preloadToken: number = 0;
  public preloadTimeoutId?: number = undefined;
  public scaleValue: number = 1;
  public opacityValue: number = 0;
  public zIndexValue: number = 0;

  public constructor(form: FormIndex) {
    this.form = form;
    this.columns = getColumnsByFormIndex(form);
    this.cacheRows = Shared.resolveListCacheCount(this.columns);
  }
}

@Observed
export class PhotoGridViewModel {
  private readonly context: common.UIAbilityContext;
  private readonly timelineViewModel: TimelineGridViewModel;
  private readonly dataAdapter: PhotoGridDataAdapter = new PhotoGridDataAdapter();
  private readonly timelineDataManager: TimelineDataManager = new TimelineDataManager();
  private readonly timelineLayoutBuilder: TimelineLayoutBuilder = new TimelineLayoutBuilder();
  public readonly actionAdapter: PhotoGridActionAdapter = new PhotoGridActionAdapter();
  private readonly anchorAdapter: GridAnchorAdapter = new GridAnchorAdapter();
  private readonly stateProxy: GridStateProxy = GridStateProxy.getInstance(GridStateProxy.getNewProxyId());
  private readonly formFsm: GridFormFsm = this.stateProxy.formFsm;
  private readonly pinchStateManager: PinchStateManager = this.stateProxy.pinchStateManager;
  private readonly stateListeners: Array<() => void> = [];

  private snapshotController?: GridSnapshotController = undefined;
  private pinchState?: PinchStateInfo = undefined;
  private initialized: boolean = false;
  private renderVersion: number = 0;
  private preparedTargetForm: FormIndex = FormIndex.INVALID;
  private preparedTargetVersion: number = -1;
  private preloadVersion: number = -1;
  private preloadActiveForm: FormIndex = FormIndex.INVALID;
  private transitionTimeoutId?: number = undefined;
  private lastVisibleGridStart: number = 0;
  private lastVisibleGridEnd: number = 0;
  private visibleGridCapacity: number = 0;
  private lastScrollPrefetchAt: number = 0;
  private lastForwardPrefetchEnd: number = -1;
  private lastBackwardPrefetchStart: number = Number.MAX_SAFE_INTEGER;
  private backgroundPredownloadToken: number = 0;
  private backgroundPredownloadRunning: boolean = false;
  private idleWorkToken: number = 0;
  private pendingWarmupSections: Array<PhotoSection> = [];
  private viewerSections: Array<PhotoSection> = [];

  public readonly yearGridState: FormGridState = new FormGridState(FormIndex.YEAR);
  public readonly monthGridState: FormGridState = new FormGridState(FormIndex.MONTH);
  public readonly dayGridState: FormGridState = new FormGridState(FormIndex.DAY);
  public readonly groupDayGridState: FormGridState = new FormGridState(FormIndex.GROUP_DAY);
  private readonly gridVcCallbacks: FormGridVcCallbacks = {
    onSwitchAnimationEnd: (gridForm: FormIndex): void => {
      this.handleGridSwitchAnimationEnd(gridForm);
    },
  };
  private readonly yearGridVc: FormGridVc = new FormGridVc(
    FormIndex.YEAR,
    this.formFsm,
    this.pinchStateManager,
    this.yearGridState.attributeUpdater,
    this.gridVcCallbacks,
  );
  private readonly monthGridVc: FormGridVc = new FormGridVc(
    FormIndex.MONTH,
    this.formFsm,
    this.pinchStateManager,
    this.monthGridState.attributeUpdater,
    this.gridVcCallbacks,
  );
  private readonly dayGridVc: FormGridVc = new FormGridVc(
    FormIndex.DAY,
    this.formFsm,
    this.pinchStateManager,
    this.dayGridState.attributeUpdater,
    this.gridVcCallbacks,
  );
  private readonly groupDayGridVc: FormGridVc = new FormGridVc(
    FormIndex.GROUP_DAY,
    this.formFsm,
    this.pinchStateManager,
    this.groupDayGridState.attributeUpdater,
    this.gridVcCallbacks,
  );
  private gridVcInitialized: boolean = false;

  public sections: Array<PhotoSection> = [];
  public groupDayGroups: Array<GroupInfo> = [];
  public yearBuckets: Array<BucketInfo> = [];
  public monthBuckets: Array<BucketInfo> = [];
  public currentItems: Array<TimelineItem> = [];
  public currentGridItems: Array<GridItem> = [];
  public itemCount: number = 0;
  public hasCompletedFirstLoad: boolean = false;
  public isLoading: boolean = true;
  public isLoadingMore: boolean = false;
  public hasMore: boolean = true;
  public errorText: string = '';
  public floatingSectionTitle: string = '';
  public floatingSectionCount: number = 0;
  public listWidth: number = 0;
  public listHeight: number = 0;
  public currentScrollOffsetY: number = 0;
  public pinchActive: boolean = false;
  public pinchCenterX: number = 0;
  public pinchCenterY: number = 0;
  public isGridTouching: boolean = false;
  public isGridScrolling: boolean = false;
  public touchScrollEnd: boolean = true;
  public activeForm: FormIndex = FormIndex.DAY;
  public targetForm: FormIndex = FormIndex.DAY;
  public transitionFromForm: FormIndex = FormIndex.DAY;
  public transitionToForm: FormIndex = FormIndex.DAY;

  private readonly dataLoadListener: DataLoadListener = {
    onDataLoaded: (): void => {
      if (this.pinchActive) {
        this.syncMetaFromDataVm();
        return;
      }
      this.syncFromDataVm();
      this.hasCompletedFirstLoad = true;
    },
    onDataLoadError: (): void => {
      if (this.pinchActive) {
        this.syncMetaFromDataVm();
        return;
      }
      this.syncFromDataVm();
      this.hasCompletedFirstLoad = true;
    },
    onDataLoading: (isLoading: boolean): void => {
      this.syncMetaFromDataVm();
      if (!isLoading) {
        this.hasCompletedFirstLoad = true;
      }
    },
  };

  public constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.stateProxy.init({
      gridConfig: {
        gridColumns: DEFAULT_COLUMN,
        imageGutters: DEFAULT_GUTTER,
        imageColumnGutters: DEFAULT_GUTTER,
        cachedCounts: DEFAULT_CACHE_COUNT,
        isSupportFillPosition: [true, true, true, true],
      },
      displayConfig: {
        areaSize: { width: 0, height: 0 },
        isGridShow: true,
        isGridActive: true,
        topAvoidHeight: 56,
        bottomAvoidHeight: 0,
      },
      switchConfig: {
        isSupportSwitch: true,
        isSwitching: false,
      },
    });
    this.timelineViewModel = new TimelineGridViewModel(context, 0);
    this.timelineViewModel.setPrefetchOwnedByActiveRuntime(true);
    Thumbnail.setRuntimeScrollActive(false);
    Thumbnail.setPrefetchRuntimeMode(Shared.PrefetchRuntimeMode.NORMAL);
    this.applyBaseFormState();
    this.syncFormFsmToActiveForm();
    this.syncStateProxyRuntime('constructor');
  }

  public bindSnapshotController(snapshotController: GridSnapshotController): void {
    this.snapshotController = snapshotController;
    this.snapshotController.bindStateProxy(this.stateProxy);
  }

  public addStateListener(listener: () => void): void {
    if (this.stateListeners.indexOf(listener) >= 0) {
      return;
    }
    this.stateListeners.push(listener);
  }

  public removeStateListener(listener: () => void): void {
    const listenerIndex = this.stateListeners.indexOf(listener);
    if (listenerIndex < 0) {
      return;
    }
    this.stateListeners.splice(listenerIndex, 1);
  }

  public async init(): Promise<void> {
    if (this.initialized) {
      return;
    }

    this.initialized = true;
    this.initGridVcs();
    this.timelineViewModel.addDataLoadListener(this.dataLoadListener);
    this.hasCompletedFirstLoad = false;
    this.isLoading = true;
    this.errorText = '';
    this.itemCount = 0;
    await this.reload();
  }

  public release(): void {
    this.cancelPendingAnimations();
    this.backgroundPredownloadToken += 1;
    this.backgroundPredownloadRunning = false;
    this.idleWorkToken += 1;
    this.initialized = false;
    this.releaseGridVcs();
    this.timelineDataManager.reset();
    this.sections = [];
    this.viewerSections = [];
    this.groupDayGroups = [];
    this.yearBuckets = [];
    this.monthBuckets = [];
    this.currentItems = [];
    this.currentGridItems = [];
    this.itemCount = 0;
    this.hasCompletedFirstLoad = false;
    this.isLoading = false;
    this.isLoadingMore = false;
    this.hasMore = true;
    this.errorText = '';
    this.floatingSectionTitle = '';
    this.floatingSectionCount = 0;
    this.currentScrollOffsetY = 0;
    this.pinchActive = false;
    this.isGridTouching = false;
    this.isGridScrolling = false;
    this.touchScrollEnd = true;
    this.lastVisibleGridStart = 0;
    this.lastVisibleGridEnd = 0;
    this.visibleGridCapacity = 0;
    this.lastScrollPrefetchAt = 0;
    this.lastForwardPrefetchEnd = -1;
    this.lastBackwardPrefetchStart = Number.MAX_SAFE_INTEGER;
    this.pendingWarmupSections = [];
    this.pinchState = undefined;
    this.preparedTargetForm = FormIndex.INVALID;
    this.preparedTargetVersion = -1;
    this.cancelAllPreloadTimeouts();
    this.resetPreloadedForms();
    Thumbnail.setRuntimeScrollActive(false);
    Thumbnail.setPrefetchRuntimeMode(Shared.PrefetchRuntimeMode.NORMAL);
    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      state.dataSource?.updateAllIfChanged([]);
      state.scroller = undefined;
      state.dataSource = undefined;
    });
    this.timelineViewModel.removeDataLoadListener(this.dataLoadListener);
    this.timelineViewModel.release();
    this.snapshotController?.hideSnapshot();
    this.applyBaseFormState();
    this.syncFormFsmToActiveForm();
    this.syncStateProxyRuntime('release');
  }

  public async reload(): Promise<void> {
    this.hasCompletedFirstLoad = false;
    this.isLoading = true;
    this.errorText = '';
    this.timelineDataManager.reset();
    this.notifyStateChanged();

    try {
      await this.timelineViewModel.reload();
      this.syncFromDataVm();
      this.hasCompletedFirstLoad = true;
    } catch (error) {
      console.error(`[PhotoGridViewModel] reload failed: ${error}`);
      this.isLoading = false;
      this.errorText = 'Photo data load failed';
      this.hasCompletedFirstLoad = true;
      this.notifyStateChanged();
    }
  }

  public bindScroller(form: FormIndex, scroller: Scroller): void {
    this.getGridState(form).scroller = scroller;
  }

  public bindDataSource(form: FormIndex, dataSource: Shared.GridDataSource): void {
    const state = this.getGridState(form);
    state.dataSource = dataSource;
    if (form === this.activeForm) {
      this.resetFormPreloadRuntime(form, PreloadStateType.HIDDEN_STATE);
      dataSource.updateAllIfChanged(this.currentGridItems.slice());
      return;
    }
    if (!this.pinchActive && this.shouldPreloadForm(form)) {
      this.triggerPreloadViewData(this.buildAdjacentPreloadRequest(form));
      return;
    }
    this.resetFormPreloadRuntime(form, PreloadStateType.INIT_STATE);
    dataSource.updateAllIfChanged([]);
  }

  public onGridAreaChange(width: number, height: number): void {
    if (width <= 0 || height <= 0) {
      return;
    }

    const widthChanged = Math.abs(this.listWidth - width) > 0.5;
    const heightChanged = Math.abs(this.listHeight - height) > 0.5;
    this.listWidth = width;
    this.listHeight = height;
    this.syncRequestSizes();
    this.refreshCacheRows();
    if (widthChanged || heightChanged) {
      this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
      this.notifyStateChanged();
    }
  }

  public onFormScrollStart(form: FormIndex): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.syncCurrentScrollOffset(form);
    this.isGridScrolling = true;
    this.updateTouchScrollEnd();
    this.resetPreloadedForms();
    this.idleWorkToken += 1;
    this.lastScrollPrefetchAt = 0;
    this.lastForwardPrefetchEnd = this.lastVisibleGridEnd;
    this.lastBackwardPrefetchStart = this.lastVisibleGridStart;
    Thumbnail.setRuntimeScrollActive(true);
    Thumbnail.ThumbnailRequestLimiter.drainStalePrefetchWaiters();
    this.timelineViewModel.onScrollStart();
  }

  public onFormScrollStop(form: FormIndex): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.syncCurrentScrollOffset(form);
    this.isGridScrolling = false;
    this.updateTouchScrollEnd();
    Thumbnail.setRuntimeScrollActive(false);
    this.timelineViewModel.onScrollStop();
    this.syncActiveWindowToVisibleAnchor(true);
    this.prefetchVisibleAndAheadAfterScrollStop();
    this.scheduleIdlePrefetchWork();
    this.preloadAdjacentForms();
  }

  public onFormTouchState(form: FormIndex, touching: boolean): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.isGridTouching = touching;
    this.updateTouchScrollEnd();
  }

  public onFormScrollIndex(form: FormIndex, start: number, end: number): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }

    const previousGridStart = this.lastVisibleGridStart;
    const previousGridEnd = this.lastVisibleGridEnd;
    this.lastVisibleGridStart = Math.max(0, start);
    this.lastVisibleGridEnd = Math.max(this.lastVisibleGridStart, end);
    this.visibleGridCapacity = Math.max(1, this.lastVisibleGridEnd - this.lastVisibleGridStart + 1);
    this.syncCurrentScrollOffset(form);
    this.maybeShiftActiveWindowWhileScrolling();
    const rowStart = this.resolveTimelineRowIndexFromGridIndex(start, form);
    const rowEnd = this.resolveTimelineRowIndexFromGridIndex(end, form);
    this.updateFloatingSection(rowStart);
    this.timelineViewModel.onScrollIndex(rowStart, rowEnd);
    this.prefetchAheadWhileScrolling(previousGridStart, previousGridEnd, this.lastVisibleGridStart, this.lastVisibleGridEnd);
    this.notifyStateChanged();
  }

  public onPinchStart(centerX: number, centerY: number): void {
    if (this.listWidth <= 0 || this.listHeight <= 0) {
      return;
    }

    this.cancelPendingAnimations();
    this.cancelPendingShowTransitions();
    this.syncCurrentScrollOffset(this.activeForm);
    this.syncActiveWindowToVisibleAnchor(true, true, false);
    this.preloadAdjacentForms(true);
    this.timelineViewModel.beginPinchFreeze();
    this.timelineViewModel.handlePinchStart(centerX, centerY);

    const totalPhotoCount = this.dataAdapter.flattenAssets(this.sections).length;
    this.pinchState = this.anchorAdapter.createPinchState(
      this.activeForm,
      this.currentGridItems,
      this.getGridState(this.activeForm).columns,
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      0,
      totalPhotoCount,
      this.timelineDataManager.getWindowStartOffsetForForm(this.activeForm),
      this.timelineDataManager.getGroupDayGroups(this.activeForm),
    );
    this.pinchActive = true;
    this.pinchCenterX = centerX;
    this.pinchCenterY = centerY;
    this.idleWorkToken += 1;
    Thumbnail.setRuntimeScrollActive(false);
    this.targetForm = this.activeForm;
    this.timelineDataManager.updateSlidingWindowState(this.activeForm);
    this.transitionFromForm = this.activeForm;
    this.groupDayGroups = this.timelineDataManager.getGroupDayGroups(this.activeForm);
    this.preparedTargetForm = FormIndex.INVALID;
    this.preparedTargetVersion = -1;
    this.updatePrefetchRuntimeMode();
    this.updatePinchStandardScales();
    const pinchStartParams = new PinchStateUpdateParams();
    pinchStartParams.pinchAction = PinchAction.START;
    pinchStartParams.pinchStartInfo = this.buildSwitchStartInfo(this.pinchState, centerX, centerY);
    this.pinchStateManager.updatePinchState(pinchStartParams);
    this.snapshotController?.resetRestoreFpState();
    this.snapshotController?.hideSnapshot();
    this.applyBaseFormState();
    this.formFsm.submitEvent(FormEventTypeUtils.getPinchEventTypeFromForm(this.activeForm, true));
    this.notifyStateChanged();
  }

  public onPinchUpdate(scale: number, centerX: number, centerY: number): void {
    if (!this.pinchActive || !this.pinchState) {
      return;
    }

    this.timelineViewModel.handlePinchUpdate(scale, centerX, centerY);
    this.anchorAdapter.updatePinchState(this.pinchState, scale, centerX, centerY);
    this.pinchCenterX = this.pinchState.sharedCenterX;
    this.pinchCenterY = this.pinchState.sharedCenterY;
    this.targetForm = getFormIndexByColumns(this.pinchState.targetColumns);
    this.transitionFromForm = this.activeForm;
    this.transitionToForm = this.targetForm;
    this.updatePrefetchRuntimeMode();

    const switchStartInfo = this.pinchStateManager.switchStartInfo;
    if (switchStartInfo) {
      switchStartInfo.anchorCenterX = this.pinchCenterX;
      switchStartInfo.anchorCenterY = this.pinchCenterY;
    }

    const pinchUpdateParams = new PinchStateUpdateParams();
    pinchUpdateParams.pinchAction = PinchAction.UPDATE;
    pinchUpdateParams.pinchEvent = { scale: this.resolveDisplayLiveScale(this.pinchState) } as GestureEvent;
    pinchUpdateParams.targetForm = this.targetForm;
    pinchUpdateParams.willArriveForm = this.targetForm !== this.activeForm ? this.targetForm : undefined;
    this.pinchStateManager.updatePinchState(pinchUpdateParams);
    this.formFsm.submitEvent(FormEventTypeUtils.getPinchEventTypeFromForm(this.targetForm, true));

    this.showActiveForm(this.activeForm);
    this.setFormWarmActive(this.activeForm, false);

    if (this.targetForm === this.activeForm) {
      this.hideOtherForms(this.activeForm);
      this.syncLivePinchShadowState(this.pinchState);
      this.refreshFormZIndices();
      this.notifyStateChanged();
      return;
    }

    this.handlePreFormSwitch(this.pinchState, this.targetForm);
    this.hideOtherForms(this.activeForm, this.targetForm);
    this.showPreviewForm(this.targetForm);
    this.setFormWarmActive(this.targetForm, true);
    this.syncLivePinchShadowState(this.pinchState);

    this.getGridState(this.activeForm).cacheRows = Shared.resolveListCacheCount(this.getGridState(this.activeForm).columns);
    this.getGridState(this.targetForm).cacheRows = Shared.resolveListCacheCount(this.getGridState(this.targetForm).columns);
    this.refreshFormZIndices(this.targetForm);
    this.notifyStateChanged();
  }

  public onPinchEnd(): void {
    if (!this.pinchActive) {
      return;
    }

    this.timelineViewModel.handlePinchEnd();
    this.formFsm.submitEvent(FormEventTypeUtils.getPinchEventTypeFromForm(this.targetForm, false));
    if (!this.pinchState || this.targetForm === this.activeForm) {
      this.animateResetToActiveForm();
      return;
    }
    this.runPinchCommit(this.pinchState, this.targetForm);
  }

  public async openPreviewAssetViewer(asset: PhotoAsset): Promise<void> {
    await this.actionAdapter.openAssetViewer(this.viewerSections, asset);
  }

  public shouldShowInitialLoading(): boolean {
    return !this.hasCompletedFirstLoad && this.isLoading;
  }

  public shouldShowInitialError(): boolean {
    return this.hasCompletedFirstLoad && !this.isLoading && !!this.errorText;
  }

  public isNoDataVisible(): boolean {
    return this.hasCompletedFirstLoad && !this.isLoading && !this.errorText && this.itemCount <= 0;
  }

  public resolveRequestSize(form: FormIndex): number {
    const state = this.getGridState(form);
    const layerRole = form === this.activeForm
      ? Shared.ThumbnailLayerRole.ACTIVE
      : (state.warmActive ? Shared.ThumbnailLayerRole.WARM : Shared.ThumbnailLayerRole.PREVIEW);
    return Shared.resolveRequestSizeBucket(
      state.columns,
      this.listWidth,
      layerRole,
    );
  }

  private getGridState(form: FormIndex): FormGridState {
    switch (form) {
      case FormIndex.YEAR:
        return this.yearGridState;
      case FormIndex.MONTH:
        return this.monthGridState;
      case FormIndex.DAY:
        return this.dayGridState;
      case FormIndex.GROUP_DAY:
        return this.groupDayGridState;
      default:
        return this.dayGridState;
    }
  }

  private getGridVcs(): Array<FormGridVc> {
    return [
      this.yearGridVc,
      this.monthGridVc,
      this.dayGridVc,
      this.groupDayGridVc,
    ];
  }

  private initGridVcs(): void {
    if (this.gridVcInitialized) {
      return;
    }
    this.getGridVcs().forEach((gridVc: FormGridVc) => {
      gridVc.init();
    });
    this.gridVcInitialized = true;
  }

  private releaseGridVcs(): void {
    if (!this.gridVcInitialized) {
      return;
    }
    this.getGridVcs().forEach((gridVc: FormGridVc) => {
      gridVc.destroy();
    });
    this.gridVcInitialized = false;
  }

  private syncFormFsmToActiveForm(): void {
    this.formFsm.submitEvent(FormEventTypeUtils.getSwitchEventTypeFromForm(this.activeForm));
  }

  private syncStateProxyRuntime(reason: string): void {
    const activeState = this.getGridState(this.activeForm);
    this.stateProxy.displayStateManager.updateStateFromVariableConfig({
      areaSize: { width: this.listWidth, height: this.listHeight },
      isGridShow: activeState.visible,
      isGridActive: activeState.interactive && !this.pinchActive,
      topAvoidHeight: 56,
      bottomAvoidHeight: 0,
    }, reason);

    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      const scrollOffset = form === this.activeForm ? this.currentScrollOffsetY : 0;
      const firstVisibleIndex = form === this.activeForm ? this.lastVisibleGridStart : state.firstVisibleIndex;
      const lastVisibleIndex = form === this.activeForm
        ? Math.max(this.lastVisibleGridStart, this.lastVisibleGridEnd)
        : state.firstVisibleIndex;

      this.stateProxy.gridStateManager.updateColumn(form, state.columns, reason);
      this.stateProxy.gridStateManager.updateImageHeight(form, this.resolveTimelineRowHeight(state.columns), reason);
      this.stateProxy.gridStateManager.updateImageGutter(form, Shared.GRID_GAP, reason);
      this.stateProxy.gridStateManager.updateImageColumnGutter(form, Shared.GRID_GAP, reason);
      this.stateProxy.gridStateManager.updateCachedCount(form, state.cacheRows, reason);
      this.stateProxy.gridStateManager.updateFillPosition(form, Math.max(0, state.fillPosition), reason);
      this.stateProxy.gridStateManager.updateScrollOffset(form, scrollOffset, reason);
      this.stateProxy.gridStateManager.updateFirstIndex(form, Math.max(0, firstVisibleIndex), reason);
      this.stateProxy.gridStateManager.updateIrregularHeight(form, scrollOffset, reason);
      this.stateProxy.gridStateManager.updateSupportFillPosition(form, true, reason);
      this.stateProxy.gridStateManager.getGridShowStateManager(form).updateState(state.showState, reason);

      this.stateProxy.scrollerStateManager.updateRuntimeState(
        form,
        form === this.activeForm ? this.isGridScrolling : false,
        form === this.activeForm ? this.isGridTouching : false,
        Math.max(0, firstVisibleIndex),
        Math.max(0, lastVisibleIndex),
        reason,
      );
    });
  }

  private resetFormShowRuntime(form: FormIndex, showState: ShowStateType): void {
    const state = this.getGridState(form);
    state.showFsm.reset(showState);
    state.showState = showState;
    this.applyResolvedShowState(form);
  }

  private dispatchShowEvent(form: FormIndex, eventType: ShowEventType): ShowStateType {
    const state = this.getGridState(form);
    state.showState = state.showFsm.dispatch(eventType);
    this.applyResolvedShowState(form);
    return state.showState;
  }

  private applyResolvedShowState(form: FormIndex): void {
    const state = this.getGridState(form);
    state.visible = ShowStateTypeUtils.isVisibleState(state.showState);
    state.interactive = ShowStateTypeUtils.isInteractiveState(state.showState);
    state.attributeUpdater.updateVisibility(state.visible ? Visibility.Visible : Visibility.Hidden);
    state.attributeUpdater.updateHitTestMode(state.interactive ? HitTestMode.Default : HitTestMode.None);
  }

  private showActiveForm(form: FormIndex): void {
    this.dispatchShowEvent(form, ShowEventType.SHOW);
  }

  private showPreviewForm(form: FormIndex): void {
    this.dispatchShowEvent(form, ShowEventType.SHOW_PREVIEW);
  }

  private hideForm(form: FormIndex): void {
    this.dispatchShowEvent(form, ShowEventType.HIDE);
  }

  private dispatchShowEventToOtherForms(excludedForm: FormIndex, eventType: ShowEventType): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      if (form === excludedForm) {
        return;
      }
      this.dispatchShowEvent(form, eventType);
    });
  }

  private cancelPendingShowTransitions(): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      if (this.getGridState(form).showState === ShowStateType.WILL_SHOW_STATE) {
        this.dispatchShowEvent(form, ShowEventType.CANCEL_KEEP_SHOW);
      }
    });
  }

  private markFormWillShow(form: FormIndex): void {
    if (this.getGridState(form).showState === ShowStateType.HIDDEN_STATE) {
      this.dispatchShowEvent(form, ShowEventType.WILL_SHOW);
    }
  }

  private handleGridSwitchAnimationEnd(form: FormIndex): void {
    if (this.pinchActive || form !== this.activeForm) {
      return;
    }

    this.dispatchShowEvent(form, ShowEventType.SHOW);
    this.dispatchShowEventToOtherForms(form, ShowEventType.OTHER_END_ANIMATION);
    this.syncStateProxyRuntime('handleGridSwitchAnimationEnd');
    this.snapshotController?.prepareRestoreAnimation();
    this.notifyStateChanged();
  }

  private applyBaseFormState(): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      const isActiveForm = form === this.activeForm;
      state.cacheRows = form === this.activeForm
        ? Shared.resolveListCacheCount(state.columns)
        : Math.max(1, this.resolveViewportRowsForColumns(state.columns));
      state.warmActive = false;
      state.scaleValue = 1;
      state.opacityValue = isActiveForm ? 1 : 0;
      state.zIndexValue = this.resolveBaseZIndex(form);
      this.resetFormShowRuntime(form, isActiveForm ? ShowStateType.SHOW_STATE : ShowStateType.HIDDEN_STATE);
      this.resetFormPreloadRuntime(form, isActiveForm ? PreloadStateType.HIDDEN_STATE : PreloadStateType.INIT_STATE);
      state.attributeUpdater.updateScale({ x: 1, y: 1, centerX: 0, centerY: 0 });
      state.attributeUpdater.updateOpacity(state.opacityValue);
      if (isActiveForm) {
        state.attributeUpdater.restoreZIndex();
      } else {
        state.attributeUpdater.setLowZIndex();
      }
      state.attributeUpdater.updateZIndex(state.zIndexValue);
    });
  }

  private hideOtherForms(...formsToKeep: Array<FormIndex>): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      if (formsToKeep.indexOf(form) >= 0) {
        return;
      }
      this.hidePreloadForm(form, true);
      this.hideForm(form);
      this.setFormWarmActive(form, false);
      this.setFormOpacity(form, 0);
      this.updateFormScale(form, 1);
    });
  }

  private refreshFormZIndices(frontForm?: FormIndex): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      this.setFormZIndex(form, this.resolveBaseZIndex(form));
    });
    if (frontForm !== undefined) {
      this.setFormZIndex(this.activeForm, 0);
      this.setFormZIndex(frontForm, 1);
      return;
    }
    this.setFormZIndex(this.activeForm, 0);
  }

  private resolveBaseZIndex(form: FormIndex): number {
    return form === this.activeForm ? 0 : -1;
  }

  private setFormWarmActive(form: FormIndex, value: boolean): void {
    this.getGridState(form).warmActive = value;
  }

  private setFormOpacity(form: FormIndex, value: number): void {
    const state = this.getGridState(form);
    state.opacityValue = Math.max(0, Math.min(1, value));
    state.attributeUpdater.updateOpacity(state.opacityValue);
  }

  private updateFormScale(form: FormIndex, value: number, centerX: number = 0, centerY: number = 0): void {
    const state = this.getGridState(form);
    state.scaleValue = value;
    state.attributeUpdater.updateScale({
      x: value,
      y: value,
      centerX: centerX,
      centerY: centerY,
    });
  }

  private setFormZIndex(form: FormIndex, value: number): void {
    const state = this.getGridState(form);
    state.zIndexValue = value;
    state.attributeUpdater.updateZIndex(value);
  }

  private syncRequestSizes(): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      state.cacheRows = form === this.activeForm
        ? Shared.resolveListCacheCount(state.columns)
        : Math.max(1, this.resolveViewportRowsForColumns(state.columns));
    });
  }

  private refreshCacheRows(): void {
    this.syncRequestSizes();
  }

  private resolveViewportRowsForColumns(columns: number): number {
    if (this.listWidth <= 0 || this.listHeight <= 0 || columns <= 0) {
      return 6;
    }
    const totalGap = Shared.GRID_GAP * Math.max(0, columns - 1);
    const rowHeight = Math.max(1, (this.listWidth - totalGap) / columns);
    return Math.max(1, Math.ceil(this.listHeight / rowHeight) + 2);
  }

  private updateTouchScrollEnd(): void {
    this.touchScrollEnd = !this.isGridTouching && !this.isGridScrolling;
  }

  private buildSwitchStartInfo(state: PinchStateInfo, centerX: number, centerY: number): SwitchStartInfo {
    const switchStartInfo = new SwitchStartInfo(
      SwitchType.PINCH_GRID,
      this.activeForm,
      centerX,
      centerY,
      state.anchor.itemIndex,
    );
    switchStartInfo.anchorCenterX = state.sharedCenterX;
    switchStartInfo.anchorCenterY = state.sharedCenterY;
    switchStartInfo.setCachedAnchorCenterX(this.activeForm, state.sharedCenterX);
    return switchStartInfo;
  }

  private updatePinchStandardScales(): void {
    const referenceItemSize = this.resolveTimelineRowHeight(this.getGridState(this.activeForm).columns);
    if (referenceItemSize <= 0) {
      return;
    }

    const standardScales: number[] = FORM_ORDER.map((form: FormIndex) => {
      const itemSize = this.resolveTimelineRowHeight(this.getGridState(form).columns);
      return itemSize > 0 ? itemSize / referenceItemSize : 1.0;
    });
    this.pinchStateManager.updateStandardScales(standardScales, `PinchStandard_${FormIndex[this.activeForm]}`);
  }

  private syncLivePinchShadowState(state: PinchStateInfo): void {
    const activeState = this.getGridState(this.activeForm);
    const activeScale = this.resolveDisplayLiveScale(state);
    activeState.scaleValue = activeScale;
    activeState.opacityValue = 1;

    if (this.targetForm === this.activeForm) {
      return;
    }

    const targetState = this.getGridState(this.targetForm);
    targetState.scaleValue = state.targetBaseScale * activeScale;
    if (state.targetDirection === PinchTargetDirection.EXPAND) {
      const fadeStart = state.targetBaseScale;
      const fadeRange = Math.max(0.001, 1.0 - fadeStart);
      const rawOpacity = Math.min(1, Math.max(0, (targetState.scaleValue - fadeStart) / fadeRange));
      targetState.opacityValue = Math.min(1, EXPAND_MIN_OPACITY + (1.0 - EXPAND_MIN_OPACITY) * rawOpacity);
      return;
    }

    const shrinkProgress = Math.min(
      1,
      Math.max(0, (PINCH_SHRINK_ENTER_SCALE - state.liveScale) / Math.max(0.001, PINCH_SHRINK_ENTER_SCALE - 0.75)),
    );
    targetState.opacityValue = shrinkProgress;
  }

  private handlePreFormSwitch(state: PinchStateInfo, form: FormIndex): void {
    const targetState = this.getGridState(form);
    const targetDataSource = targetState.dataSource;
    if (!targetDataSource) {
      return;
    }

    this.markFormWillShow(form);

    const switchStartInfo = this.pinchStateManager.switchStartInfo ?? this.buildSwitchStartInfo(
      state,
      this.pinchCenterX,
      this.pinchCenterY,
    );
    const calcParams = new SwitchCalcParams();
    calcParams.startColumns = state.startColumns;
    calcParams.targetColumns = targetState.columns;
    calcParams.startScrollOffset = state.startScrollOffset;
    calcParams.anchor = state.anchor;
    calcParams.gridWidth = state.gridWidth;
    calcParams.gridHeight = state.gridHeight;
    calcParams.topInset = state.topInset;
    calcParams.gap = Shared.GRID_GAP;
    const calcResult = SwitchCalcUtils.calcSwitch(calcParams);
    const targetFillPosition = Math.max(0, calcResult.fillPosition ?? 0);
    const preloadRequest = this.buildPreloadRequest(
      form,
      Math.max(0, calcResult.firstIndex ?? 0),
      state.anchorPhotoOffset,
      targetFillPosition,
      true,
      TimelinePreloadReason.PINCH_PRE_SWITCH,
    );
    const preloadRequestKey = this.buildPreloadRequestKey(preloadRequest);
    const targetGridIndex = this.timelineDataManager.resolveGridIndexForPhotoOffset(
      form,
      state.anchorPhotoOffset,
      targetFillPosition,
    );
    const targetExtraOffset = this.resolveTargetExtraOffset(state, calcResult.scrollOffset);

    if (
      this.preparedTargetForm === form &&
      this.preparedTargetVersion === this.renderVersion &&
      targetDataSource.totalCount() > 0 &&
      targetState.preloadRequestKey === preloadRequestKey
    ) {
      this.scrollScrollerToAnchor(targetState.scroller, targetState.preloadAnchorGridIndex, targetExtraOffset);
      return;
    }

    targetState.fillPosition = preloadRequest.fillPosition;
    targetState.firstVisibleIndex = preloadRequest.firstIndex;
    state.fillPosition = targetFillPosition;
    switchStartInfo.anchorItemIndex = state.anchor.itemIndex;
    switchStartInfo.setCachedAnchorCenterX(form, calcResult.anchorCenterX);
    const preloadResult = this.triggerPreloadViewData(preloadRequest);
    const anchorGridIndex = preloadResult?.anchorGridIndex ?? targetState.preloadAnchorGridIndex ?? targetGridIndex;
    this.scrollScrollerToAnchor(targetState.scroller, anchorGridIndex, targetExtraOffset);
    if (preloadResult) {
      this.warmTargetFormPreview(form, preloadResult.gridItems, anchorGridIndex);
    }
    this.preparedTargetForm = form;
    this.preparedTargetVersion = this.renderVersion;
  }

  private buildCommittedGridItems(): Array<GridItem> {
    return this.timelineDataManager.buildGridItemsForForm(
      this.activeForm,
      this.getGridState(this.activeForm).fillPosition,
    );
  }

  private syncCommittedFormDataSource(): void {
    const activeState = this.getGridState(this.activeForm);
    activeState.dataSource?.updateAllIfChanged(this.currentGridItems.slice());
    FORM_ORDER.forEach((form: FormIndex) => {
      if (form === this.activeForm) {
        return;
      }
      if (this.pinchActive && form === this.targetForm) {
        return;
      }
      this.getGridState(form).dataSource?.updateAllIfChanged([]);
    });
  }

  private syncFromDataVm(): void {
    this.isLoading = this.timelineViewModel.getIsLoading();
    this.isLoadingMore = this.timelineViewModel.getIsLoadingMore();
    this.hasMore = this.timelineViewModel.getHasMore();
    this.errorText = this.timelineViewModel.getErrorText();
    this.timelineDataManager.updateSourceState({
      sections: this.timelineViewModel.getSections(),
      groupDayGroups: this.timelineViewModel.getGroupDayGroups(),
      yearBuckets: this.timelineViewModel.getYearBuckets(),
      monthBuckets: this.timelineViewModel.getMonthBuckets(),
      windowStartOffset: this.timelineViewModel.getWindowStartOffset(),
      windowEndOffset: this.timelineViewModel.getWindowEndOffset(),
      hasMore: this.hasMore,
    });
    this.activeForm = getFormIndexByColumns(this.timelineViewModel.getGridColumns());
    FORM_ORDER.forEach((form: FormIndex) => {
      if (!this.pinchActive || form !== this.activeForm) {
        this.getGridState(form).fillPosition = 0;
        this.getGridState(form).firstVisibleIndex = 0;
      }
    });
    this.timelineDataManager.updateSlidingWindowState(this.activeForm);
    this.viewerSections = this.timelineDataManager.getSourceSectionsForForm(this.activeForm);
    this.sections = this.timelineDataManager.getSectionsForForm(this.activeForm);
    this.groupDayGroups = this.timelineDataManager.getGroupDayGroups(this.activeForm);
    this.yearBuckets = this.timelineDataManager.getYearBuckets();
    this.monthBuckets = this.timelineDataManager.getMonthBuckets();
    this.targetForm = this.activeForm;
    this.transitionFromForm = this.activeForm;
    this.transitionToForm = this.activeForm;
    this.currentItems = this.timelineDataManager.buildTimelineItemsForForm(this.activeForm);
    this.itemCount = this.dataAdapter.flattenAssets(this.viewerSections).length;
    this.currentGridItems = this.buildCommittedGridItems();
    this.syncActiveWindowToVisibleAnchor(true, false, false);
    this.pendingWarmupSections = this.timelineDataManager.getSections();
    this.syncFormFsmToActiveForm();
    this.renderVersion += 1;
    this.preparedTargetForm = FormIndex.INVALID;
    this.preparedTargetVersion = -1;
    this.resetPreloadedForms();
    this.syncCommittedFormDataSource();
    this.applyBaseFormState();
    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
    this.preloadAdjacentForms(true);
    Thumbnail.ThumbnailCache.setActiveColumns(this.getGridState(this.activeForm).columns);
    this.updatePrefetchRuntimeMode();
    if (!this.isGridScrolling && !this.pinchActive) {
      this.prefetchVisibleAndAheadAfterScrollStop();
      this.scheduleIdlePrefetchWork();
    }
    this.notifyStateChanged();
  }

  private syncMetaFromDataVm(): void {
    this.isLoading = this.timelineViewModel.getIsLoading();
    this.isLoadingMore = this.timelineViewModel.getIsLoadingMore();
    this.hasMore = this.timelineViewModel.getHasMore();
    this.errorText = this.timelineViewModel.getErrorText();
    this.timelineDataManager.updateSourceState({
      sections: this.timelineViewModel.getSections(),
      groupDayGroups: this.timelineViewModel.getGroupDayGroups(),
      yearBuckets: this.timelineViewModel.getYearBuckets(),
      monthBuckets: this.timelineViewModel.getMonthBuckets(),
      windowStartOffset: this.timelineViewModel.getWindowStartOffset(),
      windowEndOffset: this.timelineViewModel.getWindowEndOffset(),
      hasMore: this.hasMore,
    });
    this.timelineDataManager.updateSlidingWindowState(this.activeForm);
    this.viewerSections = this.timelineDataManager.getSourceSectionsForForm(this.activeForm);
    this.sections = this.timelineDataManager.getSectionsForForm(this.activeForm);
    this.groupDayGroups = this.timelineDataManager.getGroupDayGroups(this.activeForm);
    this.yearBuckets = this.timelineDataManager.getYearBuckets();
    this.monthBuckets = this.timelineDataManager.getMonthBuckets();
    this.itemCount = this.dataAdapter.flattenAssets(this.viewerSections).length;
    this.updatePrefetchRuntimeMode();
    this.notifyStateChanged();
  }

  private updateFloatingSection(startIndex: number): void {
    const info = this.dataAdapter.buildFloatingSectionInfo(this.currentItems, startIndex);
    this.applyFloatingSection(info);
  }

  private applyFloatingSection(info: FloatingSectionInfo): void {
    this.floatingSectionTitle = info.title;
    this.floatingSectionCount = info.count;
  }

  private resolveVisibleTimelineRowIndex(): number {
    const rowHeight = this.resolveTimelineRowHeight(this.getGridState(this.activeForm).columns);
    if (rowHeight <= 0) {
      return 0;
    }
    return Math.max(0, Math.floor(this.currentScrollOffsetY / rowHeight));
  }

  private resolveTimelineRowHeight(columns: number): number {
    if (this.listWidth <= 0 || columns <= 0) {
      return 0;
    }
    const totalGap = Shared.GRID_GAP * Math.max(0, columns - 1);
    return Math.max(0, (this.listWidth - totalGap) / columns);
  }

  private resolveTimelineRowIndexFromGridIndex(gridIndex: number, form: FormIndex): number {
    return this.timelineDataManager.resolveTimelineRowIndexForGridIndex(
      form,
      gridIndex,
      this.getGridState(form).fillPosition,
    );
  }

  private syncCurrentScrollOffset(form: FormIndex): void {
    try {
      this.currentScrollOffsetY = Math.max(0, this.getGridState(form).scroller?.currentOffset().yOffset ?? 0);
    } catch (_error) {}
  }

  private runPinchCommit(state: PinchStateInfo, targetForm: FormIndex): void {
    this.dispatchShowEvent(this.activeForm, ShowEventType.OTHER_KEEP_SHOW_END_ANIMATION);
    this.markFormWillShow(targetForm);
    this.showPreviewForm(this.activeForm);
    this.showPreviewForm(targetForm);
    this.refreshFormZIndices(targetForm);

    this.transitionTimeoutId = setTimeout((): void => {
      this.transitionTimeoutId = undefined;
      this.commitPinchTransition(state, targetForm);
    }, PINCH_COMMIT_DURATION_MS);
  }

  private commitPinchTransition(state: PinchStateInfo, targetForm: FormIndex): void {
    const committedFillPosition = this.getGridState(targetForm).fillPosition;
    const commitState = new GridColumnsCommitState();
    commitState.columns = this.getGridState(targetForm).columns;
    commitState.targetFirstRowIndex = state.targetFirstRowIndex;
    commitState.targetAnchorRowIndex = state.targetAnchorRowIndex;
    commitState.targetFirstPhotoIndex = state.targetFirstPhotoIndex;
    commitState.targetAnchorPhotoIndex = state.targetAnchorPhotoIndex;
    commitState.targetScrollOffset = this.anchorAdapter.resolveFinalScrollOffset(state);
    commitState.anchorItemIndex = state.anchorItemIndex;
    commitState.anchorItemIndex = this.timelineDataManager.resolveGridIndexForPhotoOffset(
      targetForm,
      state.anchorPhotoOffset,
      committedFillPosition,
    );
    commitState.extraOffset = this.resolveTargetExtraOffset(state, commitState.targetScrollOffset);

    this.activeForm = targetForm;
    this.targetForm = targetForm;
    this.transitionFromForm = targetForm;
    this.transitionToForm = targetForm;
    this.currentScrollOffsetY = commitState.targetScrollOffset;
    this.timelineViewModel.silentSetGridColumns(this.getGridState(targetForm).columns, commitState);
    this.syncFromDataVm();
    this.scrollCommitToAnchor(this.getGridState(targetForm).scroller, commitState);
    this.pinchStateManager.clearStartInfo();
    this.pinchState = undefined;
    this.pinchActive = false;
    this.isGridTouching = false;
    this.isGridScrolling = false;
    this.updateTouchScrollEnd();
    this.timelineViewModel.endPinchFreeze();
    this.updatePrefetchRuntimeMode();
    this.preloadAdjacentForms(true);
    this.restoreFillPosition(targetForm);
    this.scheduleIdlePrefetchWork();
    this.notifyStateChanged();
  }

  private animateResetToActiveForm(): void {
    this.transitionTimeoutId = setTimeout((): void => {
      this.transitionTimeoutId = undefined;
      this.pinchStateManager.clearStartInfo();
      this.pinchState = undefined;
      this.pinchActive = false;
      this.isGridTouching = false;
      this.isGridScrolling = false;
      this.updateTouchScrollEnd();
      this.targetForm = this.activeForm;
      this.transitionFromForm = this.activeForm;
      this.transitionToForm = this.activeForm;
      FORM_ORDER.forEach((form: FormIndex) => {
        this.getGridState(form).fillPosition = 0;
      });
      this.cancelPendingShowTransitions();
      this.snapshotController?.resetRestoreFpState();
      this.snapshotController?.cancelRestoreAnimation();
      this.timelineViewModel.endPinchFreeze();
      this.updatePrefetchRuntimeMode();
      this.applyBaseFormState();
      this.preloadAdjacentForms(true);
      this.scheduleIdlePrefetchWork();
      this.notifyStateChanged();
    }, PINCH_RESET_DURATION_MS);
  }

  private resolveDisplayLiveScale(state: PinchStateInfo): number {
    return Math.max(0.5, Math.min(2.0, state.liveScale));
  }

  private scrollScrollerToAnchor(scroller: Scroller | undefined, anchorItemIndex: number, extraOffset: number): void {
    try {
      scroller?.scrollToIndex(
        Math.max(0, anchorItemIndex),
        false,
        ScrollAlign.START,
        { extraOffset: LengthMetrics.vp(extraOffset) },
      );
    } catch (_error) {}
  }

  private scrollCommitToAnchor(scroller: Scroller | undefined, commitState: GridColumnsCommitState): void {
    this.scrollScrollerToAnchor(scroller, commitState.anchorItemIndex, commitState.extraOffset);
  }

  private resolveTargetExtraOffset(state: PinchStateInfo, _targetScrollOffset: number): number {
    return state.extraOffset;
  }

  private updatePrefetchRuntimeMode(): void {
    const constrained = this.pinchActive ||
      (this.transitionToForm !== this.activeForm) ||
      (this.preparedTargetForm !== FormIndex.INVALID && this.preparedTargetForm !== this.activeForm);
    Thumbnail.setPrefetchRuntimeMode(
      constrained ? Shared.PrefetchRuntimeMode.CONSTRAINED : Shared.PrefetchRuntimeMode.NORMAL,
    );
  }

  private prefetchGridRange(startIndex: number, endIndex: number): void {
    if (this.currentGridItems.length <= 0 || this.pinchActive) {
      return;
    }

    const requestSize = this.resolveRequestSize(this.activeForm);
    const safeStart = Math.max(0, startIndex);
    const safeEnd = Math.min(endIndex, this.currentGridItems.length - 1);
    if (safeStart > safeEnd) {
      return;
    }

    for (let index = safeStart; index <= safeEnd; index += 1) {
      const item = this.currentGridItems[index];
      if (item.kind !== 'photo' || !item.asset) {
        continue;
      }
      Thumbnail.prefetchAssetThumbnail(this.context, item.asset, requestSize);
    }
  }

  private resolveVisibleGridCapacity(): number {
    if (this.visibleGridCapacity > 0) {
      return this.visibleGridCapacity;
    }
    const state = this.getGridState(this.activeForm);
    return Math.max(1, state.columns * this.resolveViewportRowsForColumns(state.columns));
  }

  private resolveForwardPrefetchEnd(endIndex: number): number {
    return Math.min(
      this.currentGridItems.length - 1,
      endIndex + (this.resolveVisibleGridCapacity() * Shared.HYBRID_SCROLL_FORWARD_PREFETCH_SCREEN_MULTIPLIER),
    );
  }

  private resolveBackwardPrefetchStart(startIndex: number): number {
    return Math.max(
      0,
      startIndex - (this.resolveVisibleGridCapacity() * Shared.HYBRID_SCROLL_BACKWARD_PREFETCH_SCREEN_MULTIPLIER),
    );
  }

  private resolveScrollStopPrefetchEnd(endIndex: number): number {
    return Math.min(
      this.currentGridItems.length - 1,
      endIndex + (this.resolveVisibleGridCapacity() * Shared.HYBRID_SCROLL_STOP_PREFETCH_SCREEN_MULTIPLIER),
    );
  }

  private prefetchAheadWhileScrolling(
    previousStart: number,
    previousEnd: number,
    startIndex: number,
    endIndex: number,
  ): void {
    if (!this.isGridScrolling || this.currentGridItems.length <= 0) {
      return;
    }

    const now = Date.now();
    if (now - this.lastScrollPrefetchAt < Shared.HYBRID_SCROLL_PREFETCH_INTERVAL_MS) {
      return;
    }
    this.lastScrollPrefetchAt = now;

    if (endIndex >= previousEnd) {
      const targetStart = Math.max(0, endIndex + 1);
      const targetEnd = this.resolveForwardPrefetchEnd(endIndex);
      if (targetStart <= targetEnd && targetEnd > this.lastForwardPrefetchEnd) {
        this.prefetchGridRange(targetStart, targetEnd);
        this.lastForwardPrefetchEnd = targetEnd;
      }
      return;
    }

    if (startIndex < previousStart) {
      const targetStart = this.resolveBackwardPrefetchStart(startIndex);
      const targetEnd = Math.max(targetStart, startIndex - 1);
      if (targetStart <= targetEnd && targetStart < this.lastBackwardPrefetchStart) {
        this.prefetchGridRange(targetStart, targetEnd);
        this.lastBackwardPrefetchStart = targetStart;
      }
    }
  }

  private prefetchVisibleAndAheadAfterScrollStop(): void {
    if (this.currentGridItems.length <= 0 || this.pinchActive) {
      return;
    }

    const startIndex = Math.max(0, this.lastVisibleGridStart);
    const endIndex = this.lastVisibleGridEnd >= startIndex
      ? this.lastVisibleGridEnd
      : Math.min(
        this.currentGridItems.length - 1,
        Math.max(
          0,
          (Shared.resolveInitialPrefetchRows(this.getGridState(this.activeForm).columns) *
            this.getGridState(this.activeForm).columns) - 1,
        ),
      );
    this.prefetchGridRange(startIndex, this.resolveScrollStopPrefetchEnd(endIndex));
  }

  private maybeShiftActiveWindowWhileScrolling(): void {
    if (!this.isGridScrolling || this.pinchActive || this.sections.length <= 0) {
      return;
    }

    const shifted = this.syncActiveWindowToVisibleAnchor(false, true, false);
    if (!shifted) {
      return;
    }

    this.lastForwardPrefetchEnd = this.lastVisibleGridEnd;
    this.lastBackwardPrefetchStart = this.lastVisibleGridStart;
  }

  private async predownloadSections(
    sections: Array<PhotoSection>,
    includeAllAssets: boolean,
    requestSize: number,
  ): Promise<void> {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES || sections.length <= 0) {
      return;
    }

    const assets = this.timelineLayoutBuilder.collectPredownloadAssets(sections, includeAllAssets);
    const batchSize = Math.max(1, Shared.resolvePrefetchConcurrency());
    for (let index = 0; index < assets.length; index += batchSize) {
      while (Thumbnail.ThumbnailRequestLimiter.isUnderPressure()) {
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 2);
      }
      const batch = assets.slice(index, index + batchSize);
      await Promise.all(
        batch.map((asset: PhotoAsset) => {
          if (!asset.thumbnailUrl) {
            return Promise.resolve();
          }
          return Thumbnail.backgroundPredownloadRemoteThumbnail(this.context, asset.thumbnailUrl, requestSize);
        }),
      );
      await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
    }
  }

  private startBackgroundPredownload(): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES ||
      this.isGridScrolling ||
      this.pinchActive ||
      this.backgroundPredownloadRunning ||
      !this.hasMore ||
      !Thumbnail.shouldContinueBackgroundPredownload(this.context) ||
      Thumbnail.ThumbnailRequestLimiter.isUnderPressure()) {
      return;
    }

    const startOffset = this.timelineViewModel.getNextOffset();
    if (startOffset <= 0) {
      return;
    }

    const token = ++this.backgroundPredownloadToken;
    const requestSize = this.resolveRequestSize(this.activeForm);
    this.backgroundPredownloadRunning = true;
    void this.runBackgroundPredownload(token, startOffset, requestSize).finally(() => {
      if (token === this.backgroundPredownloadToken) {
        this.backgroundPredownloadRunning = false;
      }
    });
  }

  private async runBackgroundPredownload(
    token: number,
    startOffset: number,
    requestSize: number,
  ): Promise<void> {
    let offset = startOffset;

    while (token === this.backgroundPredownloadToken && Thumbnail.shouldContinueBackgroundPredownload(this.context)) {
      if (this.isGridScrolling || this.pinchActive || Thumbnail.ThumbnailRequestLimiter.isUnderPressure()) {
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 4);
        continue;
      }

      try {
        const payload = await HybridFlutterBridge.fetchTimelineWindow(offset, Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE);
        const page = this.timelineLayoutBuilder.parsePageResult(payload);
        if (!page.ready || page.sections.length <= 0) {
          break;
        }

        this.timelineDataManager.appendSourcePage({
          sections: page.sections,
          groupDayGroups: page.groupDayGroups,
          yearBuckets: page.yearBuckets,
          monthBuckets: page.monthBuckets,
          windowStartOffset: page.windowStartOffset,
          windowEndOffset: page.windowEndOffset,
          hasMore: page.hasMore,
        });

        await this.predownloadSections(page.sections, true, requestSize);

        if (!page.hasMore || page.nextOffset <= offset) {
          break;
        }

        offset = page.nextOffset;
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
      } catch (_error) {
        break;
      }
    }
  }

  private scheduleIdlePrefetchWork(): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      return;
    }

    const token = ++this.idleWorkToken;
    const requestSize = this.resolveRequestSize(this.activeForm);
    setTimeout((): void => {
      if (token !== this.idleWorkToken || this.isGridScrolling || this.pinchActive) {
        return;
      }

      const pendingSections = this.pendingWarmupSections.splice(0, this.pendingWarmupSections.length);
      if (pendingSections.length > 0) {
        void this.predownloadSections(pendingSections, false, requestSize);
      }
      Thumbnail.flushDeferredThumbnailWritesIfIdle();
      Thumbnail.trimRemoteThumbnailCacheIfNeeded(this.context);
      this.startBackgroundPredownload();
    }, Shared.HYBRID_DISK_IDLE_DELAY_MS);
  }

  private warmTargetFormPreview(
    form: FormIndex,
    previewItems: Array<GridItem>,
    anchorGridIndex: number,
  ): void {
    if (previewItems.length <= 0) {
      return;
    }

    const requestSize = this.resolveRequestSize(form);
    const warmStart = Math.max(0, anchorGridIndex - getColumnsByFormIndex(form));
    const warmEnd = Math.min(previewItems.length - 1, anchorGridIndex + getColumnsByFormIndex(form) * 3);
    for (let index = warmStart; index <= warmEnd; index += 1) {
      const item = previewItems[index];
      if (item.kind !== 'photo' || !item.asset) {
        continue;
      }
      Thumbnail.warmupAssetThumbnail(this.context, item.asset, requestSize);
    }
  }

  private restoreFillPosition(form: FormIndex): void {
    const state = this.getGridState(form);
    if (state.fillPosition <= 0) {
      return;
    }

    this.syncStateProxyRuntime('restoreFillPosition.start');
    this.snapshotController?.notifyFillPositionChanged(true);

    const restoreToken = this.renderVersion;
    this.transitionTimeoutId = setTimeout((): void => {
      this.transitionTimeoutId = undefined;
      if (this.activeForm !== form || this.pinchActive || restoreToken !== this.renderVersion) {
        return;
      }

      this.syncStateProxyRuntime('restoreFillPosition.prepare');
      this.snapshotController?.prepareRestoreAnimation();
      state.fillPosition = 0;
      this.snapshotController?.notifyFillPositionChanged(false);
      this.currentGridItems = this.buildCommittedGridItems();
      state.dataSource?.updateAllIfChanged(this.currentGridItems.slice());
      this.notifyStateChanged();
    }, FILL_POSITION_RESTORE_DELAY_MS);
  }

  private resolveAdjacentForms(form: FormIndex): Array<FormIndex> {
    const activeIndex = FORM_ORDER.indexOf(form);
    if (activeIndex < 0) {
      return [];
    }

    const adjacentForms: Array<FormIndex> = [];
    if (activeIndex > 0) {
      adjacentForms.push(FORM_ORDER[activeIndex - 1]);
    }
    if (activeIndex + 1 < FORM_ORDER.length) {
      adjacentForms.push(FORM_ORDER[activeIndex + 1]);
    }
    return adjacentForms;
  }

  private shouldPreloadForm(form: FormIndex): boolean {
    return form !== this.activeForm && this.resolveAdjacentForms(this.activeForm).indexOf(form) >= 0;
  }

  private buildPreloadRequest(
    form: FormIndex,
    firstIndex: number,
    anchorPhotoOffset: number,
    fillPosition: number,
    includeTail: boolean,
    reason: TimelinePreloadReason,
  ): TimelinePreloadRequest {
    const state = this.getGridState(form);
    const viewportItemCount = Math.max(
      state.columns,
      this.resolveViewportRowsForColumns(state.columns) * state.columns,
    );
    const isPinchPreSwitch = reason === TimelinePreloadReason.PINCH_PRE_SWITCH;
    const normalizedFillPosition = reason === TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW
      ? fillPosition
      : Math.max(0, fillPosition);
    return {
      form: form,
      firstIndex: Math.max(0, firstIndex),
      anchorPhotoOffset: Math.max(0, anchorPhotoOffset),
      fillPosition: normalizedFillPosition,
      includeTail: includeTail,
      reason: reason,
      viewportItemCount: viewportItemCount,
      backwardBufferItemCount: isPinchPreSwitch
        ? Math.max(viewportItemCount, state.columns * 2)
        : Math.max(state.columns, Math.floor(viewportItemCount / 2)),
      forwardBufferItemCount: isPinchPreSwitch
        ? Math.max(viewportItemCount * 2, state.columns * 6)
        : Math.max(viewportItemCount, state.columns * 4),
    };
  }

  private buildAdjacentPreloadRequest(form: FormIndex): TimelinePreloadRequest {
    const anchorPhotoOffset = this.resolveActiveViewportPhotoOffset();
    return this.buildPreloadRequest(
      form,
      this.resolveSourceLocalPhotoOffset(anchorPhotoOffset),
      anchorPhotoOffset,
      0,
      true,
      TimelinePreloadReason.ADJACENT_PRELOAD,
    );
  }

  private buildActiveWindowRequest(
    reason: TimelinePreloadReason = TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW,
  ): TimelinePreloadRequest | undefined {
    if (this.sections.length <= 0) {
      return undefined;
    }

    const anchorPhotoOffset = this.resolveActiveViewportPhotoOffset();
    return this.buildPreloadRequest(
      this.activeForm,
      this.resolveSourceLocalPhotoOffset(anchorPhotoOffset),
      anchorPhotoOffset,
      -1,
      true,
      reason,
    );
  }

  private buildPreloadRequestKey(request: TimelinePreloadRequest): string {
    return `${request.reason}_${request.form}_${request.firstIndex}_${request.anchorPhotoOffset}_${request.fillPosition}_${request.includeTail ? 1 : 0}_${request.viewportItemCount}_${request.backwardBufferItemCount}_${request.forwardBufferItemCount}`;
  }

  private resolveActiveViewportPhotoOffset(): number {
    const fallbackPhotoOffset = this.timelineDataManager.getWindowStartOffsetForForm(this.activeForm) +
      Math.max(0, this.getGridState(this.activeForm).firstVisibleIndex);
    if (this.currentGridItems.length <= 0) {
      return fallbackPhotoOffset;
    }

    const startIndex = Math.max(0, Math.min(this.lastVisibleGridStart, this.currentGridItems.length - 1));
    const endIndex = Math.max(startIndex, Math.min(this.lastVisibleGridEnd, this.currentGridItems.length - 1));
    for (let index = startIndex; index <= endIndex; index += 1) {
      const photoOffset = this.resolveGlobalPhotoOffsetFromGridItem(this.currentGridItems[index], this.activeForm);
      if (photoOffset !== undefined) {
        return photoOffset;
      }
    }

    for (let index = 0; index < this.currentGridItems.length; index += 1) {
      const photoOffset = this.resolveGlobalPhotoOffsetFromGridItem(this.currentGridItems[index], this.activeForm);
      if (photoOffset !== undefined) {
        return photoOffset;
      }
    }
    return fallbackPhotoOffset;
  }

  private resolveGlobalPhotoOffsetFromGridItem(item: GridItem, form: FormIndex): number | undefined {
    if (item.kind !== 'photo' || item.sourceIndex === undefined) {
      return undefined;
    }
    if (form === FormIndex.GROUP_DAY) {
      return Math.max(0, item.sourceIndex);
    }
    return Math.max(0, this.timelineDataManager.getWindowStartOffsetForForm(form) + item.sourceIndex);
  }

  private resolveSourceLocalPhotoOffset(globalPhotoOffset: number): number {
    return Math.max(0, globalPhotoOffset - this.timelineDataManager.getSourceWindowStartOffset());
  }

  private syncActiveWindowToVisibleAnchor(
    force: boolean = false,
    syncDataSource: boolean = true,
    notifyStateChanged: boolean = true,
  ): boolean {
    if (this.pinchActive || this.sections.length <= 0) {
      return false;
    }

    const activeRequest = this.buildActiveWindowRequest(
      force ? TimelinePreloadReason.POST_COMMIT : TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW,
    );
    if (!activeRequest) {
      return false;
    }

    const activeState = this.getGridState(this.activeForm);
    const previousWindowStartOffset = this.timelineDataManager.getWindowStartOffsetForForm(this.activeForm);
    const previousWindowPhotoCount = this.timelineDataManager.getWindowPhotoCountForForm(this.activeForm);
    const activeWindowResult = this.timelineDataManager.updateSlidingWindowState(this.activeForm, activeRequest);
    if (!activeWindowResult) {
      return false;
    }

    if (!force &&
      previousWindowStartOffset === activeWindowResult.windowStartPhotoOffset &&
      previousWindowPhotoCount === activeWindowResult.windowPhotoCount &&
      activeState.fillPosition === activeWindowResult.fillPosition) {
      return false;
    }

    activeState.fillPosition = activeWindowResult.fillPosition;
    activeState.firstVisibleIndex = Math.max(0, activeRequest.anchorPhotoOffset - activeWindowResult.windowStartPhotoOffset);
    this.sections = this.timelineDataManager.getSectionsForForm(this.activeForm);
    this.groupDayGroups = this.timelineDataManager.getGroupDayGroups(this.activeForm);
    this.currentItems = this.timelineDataManager.buildTimelineItemsForForm(this.activeForm);
    this.currentGridItems = activeWindowResult.gridItems;
    if (syncDataSource) {
      activeState.dataSource?.updateAllIfChanged(this.currentGridItems.slice());
    }
    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
    if (notifyStateChanged) {
      this.notifyStateChanged();
    }
    return true;
  }

  private resetFormPreloadRuntime(form: FormIndex, preloadState: PreloadStateType): void {
    const state = this.getGridState(form);
    this.cancelPreloadTimeout(form);
    state.preloadToken += 1;
    state.preloadFsm.reset(preloadState);
    state.preloadState = preloadState;
    state.preloadRequestKey = '';
    state.preloadAnchorGridIndex = 0;
  }

  private dispatchPreloadEvent(form: FormIndex, eventType: PreloadEventType): PreloadStateType {
    const state = this.getGridState(form);
    state.preloadState = state.preloadFsm.dispatch(eventType);
    return state.preloadState;
  }

  private cancelPreloadTimeout(form: FormIndex): void {
    const state = this.getGridState(form);
    if (state.preloadTimeoutId !== undefined) {
      clearTimeout(state.preloadTimeoutId);
      state.preloadTimeoutId = undefined;
    }
  }

  private cancelAllPreloadTimeouts(): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      this.cancelPreloadTimeout(form);
    });
  }

  private enterPreloadState(form: FormIndex): number {
    const state = this.getGridState(form);
    this.cancelPreloadTimeout(form);
    state.preloadToken += 1;
    const preloadToken = state.preloadToken;
    this.dispatchPreloadEvent(form, PreloadEventType.ENTER_PRELOAD);
    state.preloadTimeoutId = setTimeout((): void => {
      const latestState = this.getGridState(form);
      if (latestState.preloadToken !== preloadToken || latestState.preloadRequestKey.length <= 0) {
        return;
      }
      if (!PreloadStateTypeUtils.isInPreloadOrTimeoutState(latestState.preloadState)) {
        return;
      }
      this.dispatchPreloadEvent(form, PreloadEventType.PRELOAD_TIMEOUT);
      this.notifyStateChanged();
    }, PRELOAD_TIMEOUT_MS);
    return preloadToken;
  }

  private finishPreloadState(form: FormIndex, preloadToken: number, hasItems: boolean): void {
    const state = this.getGridState(form);
    if (state.preloadToken !== preloadToken) {
      return;
    }

    this.cancelPreloadTimeout(form);
    if (hasItems) {
      this.dispatchPreloadEvent(form, PreloadEventType.LOAD_FINISH);
      return;
    }

    this.dispatchPreloadEvent(form, PreloadEventType.HIDE);
    state.preloadRequestKey = '';
    state.preloadAnchorGridIndex = 0;
  }

  private hidePreloadForm(form: FormIndex, clearDataSource: boolean = false): void {
    const state = this.getGridState(form);
    this.cancelPreloadTimeout(form);
    state.preloadToken += 1;
    if (state.preloadRequestKey.length > 0 || state.preloadState !== PreloadStateType.INIT_STATE) {
      this.dispatchPreloadEvent(form, PreloadEventType.HIDE);
    }
    this.timelineDataManager.resetSlidingWindowState(form);
    state.preloadRequestKey = '';
    state.preloadAnchorGridIndex = 0;
    if (clearDataSource) {
      state.dataSource?.updateAllIfChanged([]);
    }
  }

  private triggerPreloadViewData(request: TimelinePreloadRequest): TimelinePreloadResult | undefined {
    const state = this.getGridState(request.form);
    if (!state.dataSource) {
      return undefined;
    }

    state.fillPosition = request.fillPosition >= 0 ? Math.max(0, request.fillPosition) : request.fillPosition;
    state.firstVisibleIndex = Math.max(0, request.firstIndex);
    state.preloadRequestKey = this.buildPreloadRequestKey(request);
    state.preloadAnchorGridIndex = 0;
    const preloadToken = this.enterPreloadState(request.form);
    try {
      const preloadResult = this.timelineDataManager.updateSlidingWindowState(this.activeForm, request);
      if (!preloadResult) {
        this.hidePreloadForm(request.form, true);
        return undefined;
      }
      state.fillPosition = preloadResult.fillPosition;
      state.dataSource.updateAllIfChanged(preloadResult.gridItems);
      state.preloadAnchorGridIndex = preloadResult.anchorGridIndex;
      if (preloadResult.gridItems.length <= 0) {
        this.timelineDataManager.resetSlidingWindowState(request.form);
      }
      this.finishPreloadState(request.form, preloadToken, preloadResult.gridItems.length > 0);
      return preloadResult;
    } catch (error) {
      console.error(`[PhotoGridViewModel] preload build failed for ${FormIndex[request.form]}: ${error}`);
      this.hidePreloadForm(request.form, true);
      return undefined;
    }
  }

  private preloadAdjacentForms(force: boolean = false): void {
    if (this.pinchActive || this.sections.length <= 0) {
      return;
    }
    if (!force && this.preloadVersion === this.renderVersion && this.preloadActiveForm === this.activeForm) {
      return;
    }

    this.timelineDataManager.updateSlidingWindowState(this.activeForm);

    const adjacentForms = this.resolveAdjacentForms(this.activeForm);
    FORM_ORDER.forEach((form: FormIndex) => {
      if (form === this.activeForm) {
        this.setFormWarmActive(form, false);
        this.resetFormPreloadRuntime(form, PreloadStateType.HIDDEN_STATE);
        return;
      }

      if (adjacentForms.indexOf(form) >= 0) {
        this.setFormWarmActive(form, true);
        this.triggerPreloadViewData(this.buildAdjacentPreloadRequest(form));
        return;
      }

      this.hidePreloadForm(form, true);
    });

    this.preloadVersion = this.renderVersion;
    this.preloadActiveForm = this.activeForm;
  }

  private resetPreloadedForms(): void {
    this.preloadVersion = -1;
    this.preloadActiveForm = FormIndex.INVALID;
    FORM_ORDER.forEach((form: FormIndex) => {
      if (form === this.activeForm) {
        return;
      }
      this.hidePreloadForm(form, true);
    });
  }

  private cancelPendingAnimations(): void {
    if (this.transitionTimeoutId !== undefined) {
      clearTimeout(this.transitionTimeoutId);
      this.transitionTimeoutId = undefined;
    }
  }

  private notifyStateChanged(): void {
    this.stateListeners.forEach((listener: () => void) => {
      listener();
    });
  }
}
