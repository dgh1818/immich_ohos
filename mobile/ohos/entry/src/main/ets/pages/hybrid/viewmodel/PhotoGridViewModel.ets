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

interface GridIndexRange {
  startIndex: number;
  endIndex: number;
}

interface DuplicateAssetKeyStats {
  totalAssetCount: number;
  uniqueKeyCount: number;
  duplicateKeyCount: number;
  duplicateAssetCount: number;
  firstDuplicateKey: string;
}

interface RemotePredownloadCoverageSnapshot {
  totalRemoteAssetCount: number;
  totalBucketEntryCount: number;
  persistedGapCount: number;
  transientOnlyGapCount: number;
  fullMissGapCount: number;
}

interface NearbyViewportWarmupBudget {
  decodedRemaining: number;
  compressedRemaining: number;
}

type GridPrefetchCallback = (request: Shared.HybridGridPrefetchRequest) => Promise<void>;
type GridPrefetchCancelCallback = (index: number, item?: GridItem) => void;

class GridPrefetchHandlerAdapter implements Shared.HybridGridPrefetchHandler {
  private readonly prefetchCallback: GridPrefetchCallback;
  private readonly cancelCallback: GridPrefetchCancelCallback;

  constructor(prefetchCallback: GridPrefetchCallback, cancelCallback: GridPrefetchCancelCallback) {
    this.prefetchCallback = prefetchCallback;
    this.cancelCallback = cancelCallback;
  }

  async prefetch(request: Shared.HybridGridPrefetchRequest): Promise<void> {
    await this.prefetchCallback(request);
  }

  cancel(index: number, item?: GridItem): void {
    this.cancelCallback(index, item);
  }
}

const PINCH_RESET_DURATION_MS: number = 160;
const PINCH_COMMIT_DURATION_MS: number = 150;
const FILL_POSITION_RESTORE_DELAY_MS: number = 350;
const PRELOAD_TIMEOUT_MS: number = 180;
const PINCH_SHRINK_ENTER_SCALE: number = 0.98;
const EXPAND_MIN_OPACITY: number = 0.15;
const GRID_CACHED_COUNT: number = 8;

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
  public gridItems: Array<GridItem> = [];
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
    this.cacheRows = GRID_CACHED_COUNT;
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
  private tapSwitchTargetForm: FormIndex = FormIndex.INVALID;
  private lastVisibleGridStart: number = 0;
  private lastVisibleGridEnd: number = 0;
  private visibleGridCapacity: number = 0;
  private lastScrollPrefetchAt: number = 0;
  private lastScrollDirection: number = 1;
  private lastViewportKeepKeysAt: number = 0;
  private lastForwardPrefetchEnd: number = -1;
  private lastBackwardPrefetchStart: number = Number.MAX_SAFE_INTEGER;
  private lastWindowAnchorGridIndex: number = 0;
  private initialRemotePredownloadToken: number = 0;
  private initialRemotePredownloadRunning: boolean = false;
  private initialRemotePredownloadCompleted: boolean = false;
  private initialRemotePredownloadRequestSize: number = 0;
  private backgroundPredownloadToken: number = 0;
  private backgroundPredownloadRunning: boolean = false;
  private backgroundPredownloadRetryTimeoutId?: number = undefined;
  private idleWorkToken: number = 0;
  private pendingWarmupSections: Array<PhotoSection> = [];
  private viewerSections: Array<PhotoSection> = [];
  private appendSourcePagePreDuplicateLogged: boolean = false;
  private appendSourcePagePostDuplicateLogged: boolean = false;
  private syncActiveProjectionPreDuplicateLogged: boolean = false;

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
  public topInsetHeight: number = 56;
  public bottomAvoidHeight: number = 0;
  private gridHeadSpacerHeight: number = 0;

  private readonly dataLoadListener: DataLoadListener = {
    onDataLoaded: (): void => {
      if (this.pinchActive) {
        this.syncMetaFromDataVm();
        return;
      }
      if (this.isGridScrolling) {
        this.syncSourceWhileScrolling(false);
        return;
      }
      if (this.hasCompletedFirstLoad) {
        // 非滚动状态下新数据到达（loadMore 完成等）时，用增量通知同步到 Grid，
        // 避免 onDataReloaded() 带来的可见闪烁。
        this.syncSourceWhileScrolling(false);
        this.syncActiveWindowToVisibleAnchor(true, false);
        this.reconcileFormGridItems(this.activeForm, this.currentGridItems);
        this.notifyStateChanged();
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
      if (this.isGridScrolling) {
        this.syncSourceWhileScrolling(false);
        return;
      }
      if (this.hasCompletedFirstLoad) {
        this.syncSourceWhileScrolling(true);
        return;
      }
      this.syncFromDataVm();
      this.hasCompletedFirstLoad = true;
    },
    onDataLoading: (isLoading: boolean): void => {
      if (this.isGridScrolling) {
        this.syncSourceWhileScrolling(false);
      } else {
        this.syncMetaFromDataVm();
      }
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
        topAvoidHeight: this.topInsetHeight,
        bottomAvoidHeight: this.bottomAvoidHeight,
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
    Thumbnail.primeRemoteThumbnailCacheIndex(this.context);
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
    this.initialRemotePredownloadToken += 1;
    this.initialRemotePredownloadRunning = false;
    this.initialRemotePredownloadCompleted = false;
    this.initialRemotePredownloadRequestSize = 0;
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
    this.lastScrollDirection = 1;
    this.lastViewportKeepKeysAt = 0;
    this.lastForwardPrefetchEnd = -1;
    this.lastBackwardPrefetchStart = Number.MAX_SAFE_INTEGER;
    this.pendingWarmupSections = [];
    Thumbnail.ThumbnailCache.updateViewportKeepKeys(new Set<string>());
    this.pinchState = undefined;
    this.preparedTargetForm = FormIndex.INVALID;
    this.preparedTargetVersion = -1;
    this.cancelAllPreloadTimeouts();
    this.resetPreloadedForms();
    Thumbnail.setRuntimeScrollActive(false);
    Thumbnail.setPrefetchRuntimeMode(Shared.PrefetchRuntimeMode.NORMAL);
    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      this.clearFormGridItems(form);
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
    this.initialRemotePredownloadToken += 1;
    this.initialRemotePredownloadRunning = false;
    this.initialRemotePredownloadCompleted = false;
    this.initialRemotePredownloadRequestSize = 0;
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
    dataSource.setPrefetchHandler(this.buildGridPrefetchHandler(form));
    if (form === this.activeForm) {
      this.resetFormPreloadRuntime(form, PreloadStateType.HIDDEN_STATE);
      this.reconcileFormGridItems(form, this.currentGridItems);
      return;
    }
    if (this.shouldKeepAdjacentFormsWarm() && this.shouldPreloadForm(form)) {
      this.triggerPreloadViewData(this.buildAdjacentPreloadRequest(form));
      return;
    }
    this.resetFormPreloadRuntime(form, PreloadStateType.INIT_STATE);
    this.clearFormGridItems(form);
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
      if (this.hasCompletedFirstLoad && !this.isGridScrolling && !this.pinchActive) {
        this.startInitialRemotePredownloadIfNeeded();
      }
      this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
      this.notifyStateChanged();
    }
  }

  public updateTopInset(topInset: number): void {
    const nextTopInset = Math.max(0, topInset);
    if (Math.abs(this.topInsetHeight - nextTopInset) <= 0.5) {
      return;
    }
    this.topInsetHeight = nextTopInset;
    this.syncStateProxyRuntime('updateTopInset');
    this.notifyStateChanged();
  }

  public updateGridHeadSpacerHeight(height: number): void {
    const nextHeight = Math.max(0, height);
    if (Math.abs(this.gridHeadSpacerHeight - nextHeight) <= 0.5) {
      return;
    }
    this.gridHeadSpacerHeight = nextHeight;
    this.syncStateProxyRuntime('updateGridHeadSpacerHeight');
    this.notifyStateChanged();
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
    this.notifyStateChanged();
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
    this.syncSourceWhileScrolling(false);
    // 滚动停止后只把最新 source 投影增量同步到 active Grid；
    // 内部滑窗状态仍然会更新，但不会再把 window-local 数组直接塞回 Grid。
    this.syncActiveWindowToVisibleAnchor(true, false);
    this.reconcileFormGridItems(this.activeForm, this.currentGridItems);
    this.prefetchVisibleAndAheadAfterScrollStop(false);
    this.scheduleIdlePrefetchWork();
    this.notifyStateChanged();
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
    this.updateLastScrollDirection(previousGridStart, previousGridEnd, this.lastVisibleGridStart, this.lastVisibleGridEnd);
    this.syncCurrentScrollOffset(form);
    this.maybeShiftActiveWindowWhileScrolling();
    const rowStart = this.resolveTimelineRowIndexFromGridIndex(start, form);
    const rowEnd = this.resolveTimelineRowIndexFromGridIndex(end, form);
    this.updateFloatingSection(rowStart);
    this.timelineViewModel.onScrollIndex(rowStart, rowEnd);
    this.prefetchAheadWhileScrolling(previousGridStart, previousGridEnd, this.lastVisibleGridStart, this.lastVisibleGridEnd);
    this.updateViewportThumbnailKeepKeys(false);
  }

  public onFormDidScroll(form: FormIndex, _offset: number, _state: number): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.syncCurrentScrollOffset(form);
  }

  public onFormReachStart(form: FormIndex): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.currentScrollOffsetY = 0;
  }

  public onFormReachEnd(form: FormIndex): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.syncCurrentScrollOffset(form);
    void this.timelineViewModel.loadMore();
  }

  public onFormWillScroll(form: FormIndex, offset: number, _state: number, _source: number): void {
    if (form !== this.activeForm || this.pinchActive) {
      return;
    }
    this.currentScrollOffsetY = Math.max(0, this.currentScrollOffsetY + offset);
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

    const totalPhotoCount = this.dataAdapter.countAssets(this.sections);
    this.pinchState = this.anchorAdapter.createPinchState(
      this.activeForm,
      this.currentGridItems,
      this.getGridState(this.activeForm).columns,
      centerX,
      centerY,
      this.currentScrollOffsetY,
      this.listWidth,
      this.listHeight,
      this.resolveHeadSpacerHeight(this.activeForm),
      totalPhotoCount,
      this.timelineDataManager.getSourceWindowStartOffset(),
      this.groupDayGroups,
    );
    this.pinchActive = true;
    this.pinchCenterX = centerX;
    this.pinchCenterY = centerY;
    this.idleWorkToken += 1;
    Thumbnail.setRuntimeScrollActive(false);
    this.targetForm = this.activeForm;
    this.timelineDataManager.updateSlidingWindowState(this.activeForm);
    this.transitionFromForm = this.activeForm;
    this.groupDayGroups = this.timelineDataManager.getSourceGroupDayGroups(this.activeForm);
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

    this.getGridState(this.activeForm).cacheRows = GRID_CACHED_COUNT;
    this.getGridState(this.targetForm).cacheRows = GRID_CACHED_COUNT;
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

  /**
   * 处理单击切换事件（tap-to-zoom）
   * 对齐参考程序：仅更新切换状态并提交 FSM 事件，数据提交在动画结束后执行
   */
  public handleSingleTapEvent(sourceForm: FormIndex): void {
    if (this.pinchActive) {
      return;
    }
    if (this.stateProxy.switchStateManager.isSwitchingAsm.currentState) {
      return;
    }
    if (sourceForm !== this.activeForm) {
      return;
    }

    const activeIndex = FORM_ORDER.indexOf(sourceForm);
    if (activeIndex < 0 || activeIndex + 1 >= FORM_ORDER.length) {
      return;
    }
    const targetForm: FormIndex = FORM_ORDER[activeIndex + 1];

    // 构建点击切换的 SwitchStartInfo，使用屏幕中心作为锚点
    const centerX = this.listWidth / 2;
    const centerY = this.listHeight / 2;
    const switchStartInfo = new SwitchStartInfo(SwitchType.CLICK_GRID, sourceForm, centerX, centerY);
    switchStartInfo.anchorCenterX = centerX;
    switchStartInfo.anchorCenterY = centerY;
    this.pinchStateManager.setSwitchStartInfo(switchStartInfo);

    // 更新切换中状态（对齐参考：isSwitchingAsm + updateSwitchState + submitEvent）
    this.updateSwitchTransitionState(true, sourceForm, targetForm, 'handleSingleTapEvent');
    this.tapSwitchTargetForm = targetForm;
  this.triggerPreloadViewData(this.buildAdjacentPreloadRequest(targetForm));

    // 准备显示状态
    this.markFormWillShow(targetForm);
    this.showPreviewForm(targetForm);
  this.setFormWarmActive(targetForm, true);
    this.refreshFormZIndices(targetForm);

    // 提交切换事件，触发动画（不改变 activeForm，不重建数据）
    this.formFsm.submitEvent(FormEventTypeUtils.getSwitchEventTypeFromForm(targetForm));
    this.notifyStateChanged();
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

  public resolveGridGap(form: FormIndex): number {
    if (form >= 0 && form < DEFAULT_GUTTER.length) {
      return DEFAULT_GUTTER[form];
    }
    return Shared.GRID_GAP;
  }

  public resolveGridLayoutOptions(form: FormIndex): GridLayoutOptions {
    const irregularIndexes: Array<number> = [];
    if (this.resolveHeadSpacerHeight(form) > 0) {
      irregularIndexes.push(0);
    }
    return {
      regularSize: [1, 1],
      irregularIndexes: irregularIndexes,
    };
  }

  public resolveHeadSpacerHeight(form: FormIndex): number {
    if (form === FormIndex.INVALID) {
      return 0;
    }
    return Math.max(0, this.gridHeadSpacerHeight);
  }

  public resolveTailSpacerHeight(form: FormIndex): number {
    if (form === FormIndex.INVALID) {
      return 0;
    }
    return Math.max(0, this.bottomAvoidHeight);
  }

  public resolveTailFillPositions(form: FormIndex): Array<number> {
    if (this.hasMore || this.itemCount <= 0) {
      return [];
    }

    const state = this.getGridState(form);
    const columns = Math.max(1, state.columns);
    if (form !== this.activeForm) {
      const windowEndOffset = this.timelineDataManager.getWindowEndOffsetForForm(form);
      if (windowEndOffset < this.itemCount) {
        return [];
      }
    }

    if (state.gridItems.length <= 0) {
      return [];
    }

    const tailPhotoCount = form === FormIndex.GROUP_DAY
      ? this.resolveGroupTailPhotoCount(state.gridItems)
      : this.resolveGridPhotoCount(state.gridItems);
    if (tailPhotoCount <= 0) {
      return [];
    }

    const lastRowCount = (tailPhotoCount + Math.max(0, state.fillPosition)) % columns;
    const tailFillCount = lastRowCount > 0 ? (columns - lastRowCount) : 0;
    const tailFillPositions: Array<number> = [];
    for (let index = 0; index < tailFillCount; index += 1) {
      tailFillPositions.push(index + 1);
    }
    return tailFillPositions;
  }

  private resolveGridPhotoCount(gridItems: Array<GridItem>): number {
    let count = 0;
    gridItems.forEach((item: GridItem) => {
      if (item.kind === 'photo') {
        count += 1;
      }
    });
    return count;
  }

  private resolveGroupTailPhotoCount(gridItems: Array<GridItem>): number {
    let count = 0;
    for (let index = gridItems.length - 1; index >= 0; index -= 1) {
      const item = gridItems[index];
      if (item.kind === 'tail' || item.kind === 'placeholder') {
        continue;
      }
      if (item.kind === 'groupHeader') {
        break;
      }
      if (item.kind === 'photo') {
        count += 1;
      }
    }
    return count;
  }

  private updateFormGridItems(form: FormIndex, gridItems: Array<GridItem>, syncDataSource: boolean = true): void {
    const state = this.getGridState(form);
    state.gridItems = gridItems.slice();
    if (syncDataSource) {
      state.dataSource?.updateDataIfChanged(state.gridItems.slice());
    }
  }

  private reconcileFormGridItems(form: FormIndex, gridItems: Array<GridItem>): void {
    const state = this.getGridState(form);
    state.gridItems = gridItems.slice();
    state.dataSource?.reconcile(state.gridItems.slice());
  }

  private clearFormGridItems(form: FormIndex, syncDataSource: boolean = true): void {
    this.updateFormGridItems(form, [], syncDataSource);
  }

  private syncStateProxyRuntime(reason: string): void {
    const activeState = this.getGridState(this.activeForm);
    this.stateProxy.displayStateManager.updateStateFromVariableConfig({
      areaSize: { width: this.listWidth, height: this.listHeight },
      isGridShow: activeState.visible,
      isGridActive: activeState.interactive && !this.pinchActive,
      topAvoidHeight: this.topInsetHeight,
      bottomAvoidHeight: this.bottomAvoidHeight,
    }, reason);

    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      const gap = this.resolveGridGap(form);
      const headSpacerHeight = this.resolveHeadSpacerHeight(form);
      const scrollOffset = form === this.activeForm ? this.currentScrollOffsetY : 0;
      const firstVisibleIndex = form === this.activeForm ? this.lastVisibleGridStart : state.firstVisibleIndex;
      const lastVisibleIndex = form === this.activeForm
        ? Math.max(this.lastVisibleGridStart, this.lastVisibleGridEnd)
        : state.firstVisibleIndex;

      this.stateProxy.gridStateManager.updateColumn(form, state.columns, reason);
      this.stateProxy.gridStateManager.updateImageHeight(form, this.resolveTimelineRowHeight(state.columns, form), reason);
      this.stateProxy.gridStateManager.updateImageGutter(form, gap, reason);
      this.stateProxy.gridStateManager.updateImageColumnGutter(form, gap, reason);
      this.stateProxy.gridStateManager.updateCachedCount(form, state.cacheRows, reason);
      this.stateProxy.gridStateManager.updateFillPosition(form, Math.max(0, state.fillPosition), reason);
      this.stateProxy.gridStateManager.updateScrollOffset(form, scrollOffset, reason);
      this.stateProxy.gridStateManager.updateFirstIndex(form, Math.max(0, firstVisibleIndex), reason);
      this.stateProxy.gridStateManager.updateIrregularHeight(form, headSpacerHeight, reason);
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
    if (this.pinchActive) {
      return;
    }

    // 处理点击切换的动画结束：动画完成后再提交数据变更
    if (form === this.tapSwitchTargetForm && form !== this.activeForm) {
      this.commitTapTransition(form);
      return;
    }

    if (form !== this.activeForm) {
      return;
    }

    this.dispatchShowEvent(form, ShowEventType.SHOW);
    this.dispatchShowEventToOtherForms(form, ShowEventType.OTHER_END_ANIMATION);
    this.updateSwitchTransitionState(false, form, form, 'handleGridSwitchAnimationEnd');
    this.syncStateProxyRuntime('handleGridSwitchAnimationEnd');
    this.notifyStateChanged();
  }

  /**
   * 提交点击切换（动画结束后执行）
   * 对齐参考程序的 notifySwitchAnimationEnd → handleSwitchEnd 模式
   */
  private commitTapTransition(targetForm: FormIndex): void {
    this.tapSwitchTargetForm = FormIndex.INVALID;
    const targetColumns = getColumnsByFormIndex(targetForm);

    const commitState = new GridColumnsCommitState();
    commitState.columns = targetColumns;
    commitState.anchorItemIndex = 0;
    commitState.extraOffset = 0;

    this.activeForm = targetForm;
    this.targetForm = targetForm;
    this.transitionFromForm = targetForm;
    this.transitionToForm = targetForm;
    this.timelineViewModel.silentSetGridColumns(targetColumns, commitState);
    this.syncFromDataVm();
    this.pinchStateManager.clearStartInfo();
    this.scheduleIdlePrefetchWork();
  }

  private applyBaseFormState(): void {
    FORM_ORDER.forEach((form: FormIndex) => {
      const state = this.getGridState(form);
      const isActiveForm = form === this.activeForm;
      state.cacheRows = GRID_CACHED_COUNT;
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
      state.cacheRows = GRID_CACHED_COUNT;
    });
  }

  private refreshCacheRows(): void {
    this.syncRequestSizes();
  }

  private resolveViewportRowsForColumns(columns: number): number {
    if (this.listWidth <= 0 || this.listHeight <= 0 || columns <= 0) {
      return 6;
    }
    const totalGap = this.resolveGridGap(getFormIndexByColumns(columns)) * Math.max(0, columns - 1);
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
    const referenceItemSize = this.resolveTimelineRowHeight(this.getGridState(this.activeForm).columns, this.activeForm);
    if (referenceItemSize <= 0) {
      return;
    }

    const standardScales: number[] = FORM_ORDER.map((form: FormIndex) => {
      const itemSize = this.resolveTimelineRowHeight(this.getGridState(form).columns, form);
      return itemSize > 0 ? itemSize / referenceItemSize : 1.0;
    });
    this.pinchStateManager.updateStandardScales(standardScales, `PinchStandard_${FormIndex[this.activeForm]}`);
  }

  private syncLivePinchShadowState(state: PinchStateInfo): void {
    const activeState = this.getGridState(this.activeForm);
    const activeScale = this.resolveDisplayLiveScale(state);
    activeState.scaleValue = activeScale;
    activeState.opacityValue = 1;
    activeState.attributeUpdater.updateScale({
      x: activeScale,
      y: activeScale,
      centerX: this.pinchCenterX,
      centerY: this.pinchCenterY,
    });
    activeState.attributeUpdater.updateOpacity(1);

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
    } else {
      const shrinkProgress = Math.min(
        1,
        Math.max(0, (PINCH_SHRINK_ENTER_SCALE - state.liveScale) / Math.max(0.001, PINCH_SHRINK_ENTER_SCALE - 0.75)),
      );
      targetState.opacityValue = shrinkProgress;
    }
    targetState.attributeUpdater.updateScale({
      x: targetState.scaleValue,
      y: targetState.scaleValue,
      centerX: this.pinchCenterX,
      centerY: this.pinchCenterY,
    });
    targetState.attributeUpdater.updateOpacity(targetState.opacityValue);
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
    calcParams.gap = this.resolveGridGap(form);
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
      this.scrollScrollerToAnchor(form, targetState.scroller, targetState.preloadAnchorGridIndex, targetExtraOffset);
      return;
    }

    targetState.fillPosition = preloadRequest.fillPosition;
    targetState.firstVisibleIndex = preloadRequest.firstIndex;
    state.fillPosition = targetFillPosition;
    switchStartInfo.anchorItemIndex = state.anchor.itemIndex;
    switchStartInfo.setCachedAnchorCenterX(form, calcResult.anchorCenterX);
    const preloadResult = this.triggerPreloadViewData(preloadRequest);
    const anchorGridIndex = preloadResult?.anchorGridIndex ?? targetState.preloadAnchorGridIndex ?? targetGridIndex;
    this.scrollScrollerToAnchor(form, targetState.scroller, anchorGridIndex, targetExtraOffset);
    if (preloadResult) {
      this.warmTargetFormPreview(form, preloadResult.gridItems, anchorGridIndex);
    }
    this.preparedTargetForm = form;
    this.preparedTargetVersion = this.renderVersion;
  }

  private buildCommittedGridItems(): Array<GridItem> {
    return this.timelineDataManager.buildSourceGridItemsForForm(this.activeForm);
  }

  private syncActiveSourceProjection(syncDataSource: boolean = false, useReconcile: boolean = false): void {
    this.logDuplicateAssetKeysOnce(
      'syncActiveSourceProjection:pre',
      this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
      this.timelineDataManager.getSourceWindowStartOffset(),
      this.timelineDataManager.getSourceWindowEndOffset(),
      this.activeForm,
    );
    const activeState = this.getGridState(this.activeForm);
    activeState.fillPosition = this.timelineDataManager.resolveSourceFillPositionForForm(this.activeForm);
    this.viewerSections = this.timelineDataManager.getSourceSectionsForForm(this.activeForm);
    this.sections = this.viewerSections;
    this.groupDayGroups = this.timelineDataManager.getSourceGroupDayGroups(this.activeForm);
    this.yearBuckets = this.timelineDataManager.getYearBuckets();
    this.monthBuckets = this.timelineDataManager.getMonthBuckets();
    this.currentItems = this.timelineDataManager.buildSourceTimelineItemsForForm(this.activeForm);
    this.itemCount = this.dataAdapter.countAssets(this.viewerSections);
    this.currentGridItems = this.buildCommittedGridItems();

    if (syncDataSource) {
      if (useReconcile) {
        this.reconcileFormGridItems(this.activeForm, this.currentGridItems);
      } else {
        this.updateFormGridItems(this.activeForm, this.currentGridItems);
      }
      return;
    }

    this.updateFormGridItems(this.activeForm, this.currentGridItems, false);
  }

  private syncCommittedFormDataSource(): void {
    this.reconcileFormGridItems(this.activeForm, this.currentGridItems);
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
    this.targetForm = this.activeForm;
    this.transitionFromForm = this.activeForm;
    this.transitionToForm = this.activeForm;
    this.syncActiveSourceProjection(false, false);
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
    if (this.shouldKeepAdjacentFormsWarm()) {
      this.preloadAdjacentForms(true);
    }
    Thumbnail.ThumbnailCache.setActiveColumns(this.getGridState(this.activeForm).columns);
    this.updatePrefetchRuntimeMode();
    if (!this.isGridScrolling && !this.pinchActive) {
      this.prefetchVisibleAndAheadAfterScrollStop(false);
      this.scheduleIdlePrefetchWork();
    }
    this.notifyStateChanged();
  }

  private syncCommittedLocalState(): void {
    this.isLoading = this.timelineViewModel.getIsLoading();
    this.isLoadingMore = this.timelineViewModel.getIsLoadingMore();
    this.hasMore = this.timelineViewModel.getHasMore();
    this.errorText = this.timelineViewModel.getErrorText();
    FORM_ORDER.forEach((form: FormIndex) => {
      if (!this.pinchActive || form !== this.activeForm) {
        this.getGridState(form).fillPosition = 0;
        this.getGridState(form).firstVisibleIndex = 0;
      }
    });
    this.timelineDataManager.updateSlidingWindowState(this.activeForm);
    this.targetForm = this.activeForm;
    this.transitionFromForm = this.activeForm;
    this.transitionToForm = this.activeForm;
    this.syncActiveSourceProjection(false, false);
    this.pendingWarmupSections = this.timelineDataManager.getSections();
    this.syncFormFsmToActiveForm();
    this.renderVersion += 1;
    this.preparedTargetForm = FormIndex.INVALID;
    this.preparedTargetVersion = -1;
    this.resetPreloadedForms();
    this.syncCommittedFormDataSource();
    this.applyBaseFormState();
    this.updateFloatingSection(this.resolveVisibleTimelineRowIndex());
    Thumbnail.ThumbnailCache.setActiveColumns(this.getGridState(this.activeForm).columns);
  }

  private syncMetaFromDataVm(): void {
    this.isLoading = this.timelineViewModel.getIsLoading();
    this.isLoadingMore = this.timelineViewModel.getIsLoadingMore();
    this.hasMore = this.timelineViewModel.getHasMore();
    this.errorText = this.timelineViewModel.getErrorText();
    // 仅更新数据源元信息，保留现有滑动窗口位置——避免 onDataLoading 后窗口重置
    this.timelineDataManager.updateSourceStatePreservingWindow({
      sections: this.timelineViewModel.getSections(),
      groupDayGroups: this.timelineViewModel.getGroupDayGroups(),
      yearBuckets: this.timelineViewModel.getYearBuckets(),
      monthBuckets: this.timelineViewModel.getMonthBuckets(),
      windowStartOffset: this.timelineViewModel.getWindowStartOffset(),
      windowEndOffset: this.timelineViewModel.getWindowEndOffset(),
      hasMore: this.hasMore,
    });
    this.timelineDataManager.updateSlidingWindowState(this.activeForm);
    this.syncActiveSourceProjection(false, false);
    this.updatePrefetchRuntimeMode();
    this.notifyStateChanged();
  }

  /**
   * 滚动中的轻量级数据同步：刷新 source 投影与元信息，
   * 但不在滚动中把新投影直接同步到 active Grid 数据源。
   */
  private syncSourceWhileScrolling(notifyUi: boolean = false): void {
    this.isLoading = this.timelineViewModel.getIsLoading();
    this.isLoadingMore = this.timelineViewModel.getIsLoadingMore();
    this.hasMore = this.timelineViewModel.getHasMore();
    this.errorText = this.timelineViewModel.getErrorText();
    this.timelineDataManager.updateSourceStatePreservingWindow({
      sections: this.timelineViewModel.getSections(),
      groupDayGroups: this.timelineViewModel.getGroupDayGroups(),
      yearBuckets: this.timelineViewModel.getYearBuckets(),
      monthBuckets: this.timelineViewModel.getMonthBuckets(),
      windowStartOffset: this.timelineViewModel.getWindowStartOffset(),
      windowEndOffset: this.timelineViewModel.getWindowEndOffset(),
      hasMore: this.hasMore,
    });
    this.syncActiveSourceProjection(false, false);
    if (notifyUi) {
      this.notifyStateChanged();
    }
  }

  private updateFloatingSection(startIndex: number): boolean {
    const info = this.dataAdapter.buildFloatingSectionInfo(this.currentItems, startIndex);
    return this.applyFloatingSection(info);
  }

  private applyFloatingSection(info: FloatingSectionInfo): boolean {
    if (this.floatingSectionTitle === info.title && this.floatingSectionCount === info.count) {
      return false;
    }
    this.floatingSectionTitle = info.title;
    this.floatingSectionCount = info.count;
    return true;
  }

  private resolveVisibleTimelineRowIndex(): number {
    const rowHeight = this.resolveTimelineRowHeight(this.getGridState(this.activeForm).columns, this.activeForm);
    if (rowHeight <= 0) {
      return 0;
    }
    return Math.max(0, Math.floor(this.resolveContentScrollOffset(this.activeForm, this.currentScrollOffsetY) / rowHeight));
  }

  private resolveTimelineRowHeight(columns: number, form?: FormIndex): number {
    if (this.listWidth <= 0 || columns <= 0) {
      return 0;
    }
    const resolvedForm = form === undefined ? getFormIndexByColumns(columns) : form;
    const totalGap = this.resolveGridGap(resolvedForm) * Math.max(0, columns - 1);
    return Math.max(0, (this.listWidth - totalGap) / columns);
  }

  private resolveTimelineRowIndexFromGridIndex(gridIndex: number, form: FormIndex): number {
    if (form === this.activeForm) {
      return this.timelineDataManager.resolveSourceTimelineRowIndexForGridIndex(form, gridIndex);
    }
    return this.timelineDataManager.resolveTimelineRowIndexForGridIndex(
      form,
      gridIndex,
      this.getGridState(form).fillPosition,
    );
  }

  private resolveRenderLeadingItemCount(form: FormIndex): number {
    return this.resolveHeadSpacerHeight(form) > 0 ? 1 : 0;
  }

  private normalizeRenderGridIndex(form: FormIndex, renderGridIndex: number): number {
    return Math.max(0, renderGridIndex - this.resolveRenderLeadingItemCount(form));
  }

  private resolveRenderGridIndex(form: FormIndex, dataGridIndex: number): number {
    return Math.max(0, dataGridIndex) + this.resolveRenderLeadingItemCount(form);
  }

  private resolveContentScrollOffset(form: FormIndex, scrollOffset: number): number {
    return Math.max(0, scrollOffset - this.resolveHeadSpacerHeight(form));
  }

  private syncCurrentScrollOffset(form: FormIndex): void {
    try {
      this.currentScrollOffsetY = Math.max(0, this.getGridState(form).scroller?.currentOffset().yOffset ?? 0);
    } catch (_error) {}
  }

  private runPinchCommit(state: PinchStateInfo, targetForm: FormIndex): void {
    this.updateSwitchTransitionState(true, this.activeForm, targetForm, 'runPinchCommit');
    this.dispatchShowEvent(this.activeForm, ShowEventType.OTHER_KEEP_SHOW_END_ANIMATION);
    this.markFormWillShow(targetForm);
    this.showPreviewForm(this.activeForm);
    this.showPreviewForm(targetForm);
    this.refreshFormZIndices(targetForm);

    const sourceForm = this.activeForm;
    const centerX = this.pinchCenterX;
    const centerY = this.pinchCenterY;
    const sourceGridState = this.getGridState(sourceForm);
    const targetGridState = this.getGridState(targetForm);
    animateTo({
      duration: PINCH_COMMIT_DURATION_MS,
      curve: Curve.EaseInOut,
    }, (): void => {
      sourceGridState.attributeUpdater.updateScale({ x: 1, y: 1, centerX: centerX, centerY: centerY });
      sourceGridState.attributeUpdater.updateOpacity(0);
      targetGridState.attributeUpdater.updateScale({ x: 1, y: 1, centerX: centerX, centerY: centerY });
      targetGridState.attributeUpdater.updateOpacity(1);
    });

    this.transitionTimeoutId = setTimeout((): void => {
      this.transitionTimeoutId = undefined;
      this.commitPinchTransition(state, targetForm);
    }, PINCH_COMMIT_DURATION_MS);
  }

  private commitPinchTransition(state: PinchStateInfo, targetForm: FormIndex): void {
    const sourceForm = this.activeForm;
    const commitState = new GridColumnsCommitState();
    commitState.columns = this.getGridState(targetForm).columns;
    commitState.targetFirstRowIndex = state.targetFirstRowIndex;
    commitState.targetAnchorRowIndex = state.targetAnchorRowIndex;
    commitState.targetFirstPhotoIndex = state.targetFirstPhotoIndex;
    commitState.targetAnchorPhotoIndex = state.targetAnchorPhotoIndex;
    commitState.targetScrollOffset = this.anchorAdapter.resolveFinalScrollOffset(state);
    commitState.anchorItemIndex = state.anchorItemIndex;
    commitState.anchorItemIndex = this.timelineDataManager.resolveSourceGridIndexForPhotoOffset(
      targetForm,
      state.anchorPhotoOffset,
    );
    commitState.extraOffset = this.resolveTargetExtraOffset(state, commitState.targetScrollOffset);

    this.activeForm = targetForm;
    this.targetForm = targetForm;
    this.transitionFromForm = targetForm;
    this.transitionToForm = targetForm;
    this.updateSwitchTransitionState(true, sourceForm, targetForm, 'commitPinchTransition');
    this.currentScrollOffsetY = commitState.targetScrollOffset;
    this.timelineViewModel.silentSetGridColumns(this.getGridState(targetForm).columns, commitState);
    this.syncCommittedLocalState();
    this.scrollCommitToAnchor(targetForm, this.getGridState(targetForm).scroller, commitState);
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
    const centerX = this.pinchCenterX;
    const centerY = this.pinchCenterY;
    const activeState = this.getGridState(this.activeForm);
    animateTo({
      duration: PINCH_RESET_DURATION_MS,
      curve: Curve.EaseInOut,
    }, (): void => {
      activeState.attributeUpdater.updateScale({ x: 1, y: 1, centerX: centerX, centerY: centerY });
      activeState.attributeUpdater.updateOpacity(1);
    });

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
      this.getGridState(this.activeForm).fillPosition =
        this.timelineDataManager.resolveSourceFillPositionForForm(this.activeForm);
      this.cancelPendingShowTransitions();
      this.updateSwitchTransitionState(false, this.activeForm, this.activeForm, 'animateResetToActiveForm');
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

  private scrollScrollerToAnchor(
    form: FormIndex,
    scroller: Scroller | undefined,
    anchorItemIndex: number,
    extraOffset: number,
  ): void {
    try {
      scroller?.scrollToIndex(
        this.resolveRenderGridIndex(form, anchorItemIndex),
        false,
        ScrollAlign.START,
        { extraOffset: LengthMetrics.vp(extraOffset) },
      );
    } catch (_error) {}
  }

  private scrollCommitToAnchor(form: FormIndex, scroller: Scroller | undefined, commitState: GridColumnsCommitState): void {
    this.scrollScrollerToAnchor(form, scroller, commitState.anchorItemIndex, commitState.extraOffset);
  }

  private resolveTargetExtraOffset(state: PinchStateInfo, _targetScrollOffset: number): number {
    return state.extraOffset;
  }

  private updatePrefetchRuntimeMode(): void {
    const constrained = this.shouldKeepAdjacentFormsWarm();
    Thumbnail.setPrefetchRuntimeMode(
      constrained ? Shared.PrefetchRuntimeMode.CONSTRAINED : Shared.PrefetchRuntimeMode.NORMAL,
    );
  }

  private shouldKeepAdjacentFormsWarm(): boolean {
    return this.pinchActive ||
      this.tapSwitchTargetForm !== FormIndex.INVALID ||
      this.transitionToForm !== this.activeForm ||
      (this.preparedTargetForm !== FormIndex.INVALID && this.preparedTargetForm !== this.activeForm);
  }

  private buildGridPrefetchHandler(form: FormIndex): Shared.HybridGridPrefetchHandler | undefined {
    if (!this.shouldUseGridDataSourcePrefetch(form)) {
      return undefined;
    }
    return new GridPrefetchHandlerAdapter(
      async (request: Shared.HybridGridPrefetchRequest): Promise<void> => {
        await this.handleGridPrefetchRequest(form, request);
      },
      (index: number, item?: GridItem): void => {
        this.handleGridPrefetchCancel(form, index, item);
      },
    );
  }

  private shouldUseGridDataSourcePrefetch(form: FormIndex): boolean {
    return form === FormIndex.DAY;
  }

  private async handleGridPrefetchRequest(
    form: FormIndex,
    request: Shared.HybridGridPrefetchRequest,
  ): Promise<void> {
    if (form !== this.activeForm || this.pinchActive || request.isCanceled()) {
      return;
    }

    const item = this.resolveGridPrefetchItem(request.index, request.item);
    if (!item || item.kind !== 'photo' || !item.asset) {
      return;
    }

    const requestSize = this.resolveRequestSize(form);
    const visibleCapacity = this.resolveGridPrefetchVisibleCapacity(request.visibleStart, request.visibleEnd);
    const memoryRunwayDistance = Math.max(this.resolveVisibleGridCapacity(), visibleCapacity);
    const distance = this.resolveGridPrefetchDistance(request.index, request.visibleStart, request.visibleEnd);

    if (distance <= memoryRunwayDistance) {
      await this.prefetchGridAssetToMemory(item.asset, requestSize, request);
      return;
    }

    await this.predownloadGridAssetToDisk(item.asset, requestSize, request);
  }

  private handleGridPrefetchCancel(_form: FormIndex, _index: number, _item?: GridItem): void {}

  private resolveGridPrefetchItem(index: number, item?: GridItem): GridItem | undefined {
    if (item) {
      return item;
    }
    if (index < 0 || index >= this.currentGridItems.length) {
      return undefined;
    }
    return this.currentGridItems[index];
  }

  private resolveGridPrefetchVisibleCapacity(visibleStart: number, visibleEnd: number): number {
    if (visibleEnd < visibleStart) {
      return this.resolveVisibleGridCapacity();
    }
    return Math.max(1, visibleEnd - visibleStart + 1);
  }

  private resolveGridPrefetchDistance(index: number, visibleStart: number, visibleEnd: number): number {
    if (index < visibleStart) {
      return visibleStart - index;
    }
    if (index > visibleEnd) {
      return index - visibleEnd;
    }
    return 0;
  }

  private shouldPrioritizeInitialRemoteDiskWarmup(): boolean {
    return Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES &&
      (!this.initialRemotePredownloadCompleted || this.initialRemotePredownloadRunning);
  }

  private async prefetchGridAssetToMemory(
    asset: PhotoAsset,
    requestSize: number,
    request: Shared.HybridGridPrefetchRequest,
  ): Promise<void> {
    if (request.isCanceled()) {
      return;
    }

    if (asset.localId) {
      Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize);
      return;
    }

    const remoteUrl = asset.thumbnailUrl;
    if (!remoteUrl) {
      return;
    }

    if (Thumbnail.hasRemoteThumbnailCache(this.context, remoteUrl, requestSize, false)) {
      Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize);
      return;
    }

    if (this.shouldPrioritizeInitialRemoteDiskWarmup()) {
      if (this.isGridScrolling) {
        this.startInitialRemotePredownloadIfNeeded();
        return;
      }
      await Thumbnail.backgroundPredownloadRemoteThumbnail(
        this.context,
        remoteUrl,
        this.resolveInitialRemotePredownloadRequestSize(),
        Thumbnail.HybridRemotePredownloadPriorityHint.INITIAL,
      );
      return;
    }

    if (this.isGridScrolling) {
      this.startInitialRemotePredownloadIfNeeded();
      return;
    }

    if (Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize);
      return;
    }

    await Thumbnail.backgroundPredownloadRemoteThumbnail(
      this.context,
      remoteUrl,
      this.resolveInitialRemotePredownloadRequestSize(),
      Thumbnail.HybridRemotePredownloadPriorityHint.NEARBY,
    );
    if (request.isCanceled()) {
      return;
    }
    Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize);
  }

  private async predownloadGridAssetToDisk(
    asset: PhotoAsset,
    requestSize: number,
    request: Shared.HybridGridPrefetchRequest,
  ): Promise<void> {
    void requestSize;
    if (request.isCanceled() || Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      return;
    }

    const remoteUrl = asset.thumbnailUrl;
    if (!remoteUrl) {
      return;
    }

    if (this.isGridScrolling) {
      this.startInitialRemotePredownloadIfNeeded();
      return;
    }

    await Thumbnail.backgroundPredownloadRemoteThumbnail(
      this.context,
      remoteUrl,
      this.resolveInitialRemotePredownloadRequestSize(),
      Thumbnail.HybridRemotePredownloadPriorityHint.NEARBY,
    );
  }

  private updateLastScrollDirection(
    previousStart: number,
    previousEnd: number,
    startIndex: number,
    endIndex: number,
  ): void {
    if (endIndex > previousEnd || startIndex > previousStart) {
      this.lastScrollDirection = 1;
      return;
    }
    if (startIndex < previousStart || endIndex < previousEnd) {
      this.lastScrollDirection = -1;
    }
  }

  private prefetchGridRangeToMemory(
    startIndex: number,
    endIndex: number,
    budget: number,
    allowRemoteDiskWarmup: boolean = true,
    seenAssetKeys?: Set<string>,
  ): number {
    if (this.currentGridItems.length <= 0 || this.pinchActive || budget <= 0) {
      return 0;
    }

    const requestSize = this.resolveRequestSize(this.activeForm);
    const safeStart = Math.max(0, startIndex);
    const safeEnd = Math.min(endIndex, this.currentGridItems.length - 1);
    if (safeStart > safeEnd) {
      return 0;
    }

    let remainingBudget = budget;
    let scheduledCount = 0;
    const effectiveSeenAssetKeys: Set<string> = seenAssetKeys ?? new Set<string>();
    for (let index = safeStart; index <= safeEnd; index += 1) {
      if (remainingBudget <= 0) {
        return scheduledCount;
      }

      const item = this.currentGridItems[index];
      if (item.kind !== 'photo' || !item.asset) {
        continue;
      }

      const asset = item.asset;
      const remoteUrl = asset.thumbnailUrl;
      const dedupeKey = remoteUrl && remoteUrl.length > 0
        ? `remote:${remoteUrl}`
        : `asset:${asset.id}`;
      if (effectiveSeenAssetKeys.has(dedupeKey)) {
        continue;
      }
      effectiveSeenAssetKeys.add(dedupeKey);

      const remoteCacheReady = remoteUrl && remoteUrl.length > 0
        ? Thumbnail.hasRemoteThumbnailCache(this.context, remoteUrl, requestSize, false)
        : false;

      if (
        remoteUrl &&
        remoteUrl.length > 0 &&
        this.isGridScrolling &&
        !remoteCacheReady
      ) {
        if (!allowRemoteDiskWarmup) {
          continue;
        }
        this.startInitialRemotePredownloadIfNeeded();
        continue;
      }

      if (
        remoteUrl &&
        remoteUrl.length > 0 &&
        this.shouldPrioritizeInitialRemoteDiskWarmup() &&
        !remoteCacheReady
      ) {
        if (!allowRemoteDiskWarmup) {
          continue;
        }
        void Thumbnail.backgroundPredownloadRemoteThumbnail(
          this.context,
          remoteUrl,
          this.resolveInitialRemotePredownloadRequestSize(),
          Thumbnail.HybridRemotePredownloadPriorityHint.INITIAL,
        );
        continue;
      }

      if (remoteUrl && remoteUrl.length > 0 && !remoteCacheReady && !allowRemoteDiskWarmup) {
        continue;
      }

      if (!Thumbnail.prefetchAssetThumbnail(this.context, asset, requestSize)) {
        continue;
      }

      remainingBudget -= 1;
      scheduledCount += 1;
    }

    return scheduledCount;
  }

  private preloadGridRangeRemoteCompressedData(
    startIndex: number,
    endIndex: number,
    budget: number,
    seenRemoteUrls?: Set<string>,
  ): number {
    if (this.currentGridItems.length <= 0 || this.pinchActive || budget <= 0) {
      return 0;
    }

    const requestSize = this.resolveRequestSize(this.activeForm);
    const safeStart = Math.max(0, startIndex);
    const safeEnd = Math.min(endIndex, this.currentGridItems.length - 1);
    if (safeStart > safeEnd) {
      return 0;
    }

    let remainingBudget = budget;
    let scheduledCount = 0;
    const effectiveSeenRemoteUrls: Set<string> = seenRemoteUrls ?? new Set<string>();
    for (let index = safeStart; index <= safeEnd; index += 1) {
      if (remainingBudget <= 0) {
        return scheduledCount;
      }

      const item = this.currentGridItems[index];
      if (item.kind !== 'photo' || !item.asset || !item.asset.thumbnailUrl) {
        continue;
      }

      const remoteUrl = item.asset.thumbnailUrl;
      if (effectiveSeenRemoteUrls.has(remoteUrl)) {
        continue;
      }
      effectiveSeenRemoteUrls.add(remoteUrl);

      if (!Thumbnail.preloadRemoteAssetThumbnailCompressedData(this.context, item.asset, requestSize)) {
        continue;
      }

      remainingBudget -= 1;
      scheduledCount += 1;
    }

    return scheduledCount;
  }

  private warmNearbyViewportSegment(
    startIndex: number,
    endIndex: number,
    budget: NearbyViewportWarmupBudget,
    allowRemoteDiskWarmup: boolean,
    seenAssetKeys: Set<string>,
    seenRemoteUrls: Set<string>,
  ): void {
    if (startIndex > endIndex) {
      return;
    }

    if (budget.compressedRemaining > 0) {
      budget.compressedRemaining = Math.max(
        0,
        budget.compressedRemaining - this.preloadGridRangeRemoteCompressedData(
          startIndex,
          endIndex,
          budget.compressedRemaining,
          seenRemoteUrls,
        ),
      );
    }

    if (budget.decodedRemaining > 0) {
      budget.decodedRemaining = Math.max(
        0,
        budget.decodedRemaining - this.prefetchGridRangeToMemory(
          startIndex,
          endIndex,
          budget.decodedRemaining,
          allowRemoteDiskWarmup,
          seenAssetKeys,
        ),
      );
    }
  }

  private preloadNearbyVisibleRunwayToMemory(allowRemoteDiskWarmup: boolean): void {
    if (this.currentGridItems.length <= 0 || this.pinchActive) {
      return;
    }

    const visibleStart = Math.max(0, Math.min(this.lastVisibleGridStart, this.currentGridItems.length - 1));
    const visibleEnd = Math.max(visibleStart, Math.min(this.lastVisibleGridEnd, this.currentGridItems.length - 1));
    const visibleCapacity = Math.max(1, visibleEnd - visibleStart + 1);
    const budget: NearbyViewportWarmupBudget = {
      decodedRemaining: Shared.resolveNearbyMemoryPredecodeBudget(visibleCapacity),
      compressedRemaining: Shared.resolveNearbyCompressedBufferPreloadBudget(visibleCapacity),
    };
    const seenAssetKeys: Set<string> = new Set<string>();
    const seenRemoteUrls: Set<string> = new Set<string>();
    const forwardStart = Math.min(this.currentGridItems.length - 1, visibleEnd + 1);
    const forwardEnd = this.resolveScrollStopPrefetchEnd(visibleEnd);
    const backwardStart = this.resolveBackwardPrefetchStart(visibleStart);
    const backwardEnd = Math.max(backwardStart, visibleStart - 1);

    this.preloadGridRangeRemoteCompressedData(
      visibleStart,
      visibleEnd,
      visibleCapacity,
      seenRemoteUrls,
    );
    this.prefetchGridRangeToMemory(
      visibleStart,
      visibleEnd,
      visibleCapacity,
      allowRemoteDiskWarmup,
      seenAssetKeys,
    );

    if (this.lastScrollDirection >= 0) {
      this.warmNearbyViewportSegment(
        forwardStart,
        forwardEnd,
        budget,
        allowRemoteDiskWarmup,
        seenAssetKeys,
        seenRemoteUrls,
      );
      this.warmNearbyViewportSegment(
        backwardStart,
        backwardEnd,
        budget,
        allowRemoteDiskWarmup,
        seenAssetKeys,
        seenRemoteUrls,
      );
      return;
    }

    this.warmNearbyViewportSegment(
      backwardStart,
      backwardEnd,
      budget,
      allowRemoteDiskWarmup,
      seenAssetKeys,
      seenRemoteUrls,
    );
    this.warmNearbyViewportSegment(
      forwardStart,
      forwardEnd,
      budget,
      allowRemoteDiskWarmup,
      seenAssetKeys,
      seenRemoteUrls,
    );
  }

  private predownloadGridRangeToDisk(startIndex: number, endIndex: number, budget: number): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES ||
      this.currentGridItems.length <= 0 ||
      this.pinchActive ||
      budget <= 0 ||
      Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      return;
    }

    if (this.isGridScrolling) {
      this.startInitialRemotePredownloadIfNeeded();
      return;
    }

    const safeStart = Math.max(0, startIndex);
    const safeEnd = Math.min(endIndex, this.currentGridItems.length - 1);
    if (safeStart > safeEnd) {
      return;
    }

    let remainingBudget = budget;
    const seenRemoteUrls: Set<string> = new Set();
    for (let index = safeStart; index <= safeEnd; index += 1) {
      if (remainingBudget <= 0) {
        return;
      }

      const item = this.currentGridItems[index];
      if (item.kind !== 'photo' || !item.asset || !item.asset.thumbnailUrl) {
        continue;
      }

      const remoteUrl = item.asset.thumbnailUrl;
      if (seenRemoteUrls.has(remoteUrl)) {
        continue;
      }
      seenRemoteUrls.add(remoteUrl);

      if (!Thumbnail.predownloadRemoteAssetThumbnail(
        this.context,
        item.asset,
        this.resolveInitialRemotePredownloadRequestSize(),
      )) {
        continue;
      }

      remainingBudget -= 1;
    }
  }

  private resolveVisibleGridCapacity(): number {
    if (this.visibleGridCapacity > 0) {
      return this.visibleGridCapacity;
    }
    const state = this.getGridState(this.activeForm);
    return Math.max(1, state.columns * this.resolveViewportRowsForColumns(state.columns));
  }

  private resolveAdaptiveRemoteDiskPredownloadBudget(visibleCapacity: number): number {
    const baseBudget = Shared.resolveScrollRemoteDiskPredownloadBudget(visibleCapacity);
    if (baseBudget <= 0 || Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      return 0;
    }

    // Cold first-pass scrolls are exactly when we need the far runway most.
    // Do not shrink runway budget just because the current window is dominated
    // by network misses; that only makes the next batch colder.
    return baseBudget;
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

    if (this.shouldUseGridDataSourcePrefetch(this.activeForm)) {
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
        const visibleCapacity = this.resolveVisibleGridCapacity();
        const memoryBudget = Shared.resolveNearbyMemoryPredecodeBudget(visibleCapacity);
        const compressedBudget = Shared.resolveNearbyCompressedBufferPreloadBudget(visibleCapacity);
        const memoryEnd = Math.min(targetEnd, targetStart + Math.max(0, memoryBudget - 1));
        const compressedEnd = Math.min(targetEnd, targetStart + Math.max(0, compressedBudget - 1));
        const remoteDiskBudget = this.resolveAdaptiveRemoteDiskPredownloadBudget(visibleCapacity);
        this.preloadGridRangeRemoteCompressedData(targetStart, compressedEnd, compressedBudget);
        this.prefetchGridRangeToMemory(targetStart, memoryEnd, memoryBudget);
        this.predownloadGridRangeToDisk(
          memoryEnd + 1,
          targetEnd,
          remoteDiskBudget,
        );
        this.lastForwardPrefetchEnd = targetEnd;
      }
      return;
    }

    if (startIndex < previousStart) {
      const targetStart = this.resolveBackwardPrefetchStart(startIndex);
      const targetEnd = Math.max(targetStart, startIndex - 1);
      if (targetStart <= targetEnd && targetStart < this.lastBackwardPrefetchStart) {
        const visibleCapacity = this.resolveVisibleGridCapacity();
        const backwardMemoryBudget = Shared.resolveNearbyMemoryPredecodeBudget(visibleCapacity);
        const backwardCompressedBudget = Shared.resolveNearbyCompressedBufferPreloadBudget(visibleCapacity);
        const memoryStart = Math.max(targetStart, targetEnd - Math.max(0, backwardMemoryBudget - 1));
        const compressedStart = Math.max(targetStart, targetEnd - Math.max(0, backwardCompressedBudget - 1));
        this.preloadGridRangeRemoteCompressedData(compressedStart, targetEnd, backwardCompressedBudget);
        this.prefetchGridRangeToMemory(memoryStart, targetEnd, backwardMemoryBudget);
        this.lastBackwardPrefetchStart = targetStart;
      }
    }
  }

  private prefetchVisibleAndAheadAfterScrollStop(allowDiskPredownload: boolean = true): void {
    const range = this.resolveScrollStopPrefetchRange();
    if (!range) {
      return;
    }

    const visibleCapacity = this.resolveVisibleGridCapacity();
    const memoryBudget = Shared.resolveNearbyMemoryPredecodeBudget(visibleCapacity);
    const visibleEnd = this.lastVisibleGridEnd >= range.startIndex
      ? this.lastVisibleGridEnd
      : range.startIndex;
    const memoryAheadCount = Math.max(0, memoryBudget);
    const memoryEnd = Math.min(range.endIndex, visibleEnd + memoryAheadCount);
    this.preloadNearbyVisibleRunwayToMemory(allowDiskPredownload);
    this.updateViewportThumbnailKeepKeys(true);
    if (!allowDiskPredownload) {
      return;
    }
    this.predownloadGridRangeToDisk(
      memoryEnd + 1,
      range.endIndex,
      this.resolveAdaptiveRemoteDiskPredownloadBudget(visibleCapacity),
    );
  }

  private resolveScrollStopPrefetchRange(): GridIndexRange | undefined {
    if (this.currentGridItems.length <= 0 || this.pinchActive) {
      return undefined;
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

    return {
      startIndex: startIndex,
      endIndex: this.resolveScrollStopPrefetchEnd(endIndex),
    };
  }

  private updateViewportThumbnailKeepKeys(force: boolean): void {
    if (this.currentGridItems.length <= 0 || this.pinchActive) {
      return;
    }

    const now = Date.now();
    if (!force && now - this.lastViewportKeepKeysAt < Shared.HYBRID_VIEWPORT_CACHE_PRUNE_INTERVAL_MS) {
      return;
    }
    this.lastViewportKeepKeysAt = now;

    const requestSize = this.resolveRequestSize(this.activeForm);
    if (requestSize <= 0) {
      return;
    }

    const visibleStart = Math.max(0, Math.min(this.lastVisibleGridStart, this.currentGridItems.length - 1));
    const visibleEnd = Math.max(visibleStart, Math.min(this.lastVisibleGridEnd, this.currentGridItems.length - 1));
    const visibleCapacity = Math.max(1, visibleEnd - visibleStart + 1);
    const forwardKeepCount = Shared.resolveNearbyMemoryPredecodeBudget(visibleCapacity);
    const reverseKeepCount = visibleCapacity;
    const keepStart = this.lastScrollDirection >= 0
      ? Math.max(0, visibleStart - reverseKeepCount)
      : Math.max(0, visibleStart - forwardKeepCount);
    const keepEnd = this.lastScrollDirection >= 0
      ? Math.min(this.currentGridItems.length - 1, visibleEnd + forwardKeepCount)
      : Math.min(this.currentGridItems.length - 1, visibleEnd + reverseKeepCount);
    const keepKeys: Set<string> = new Set<string>();
    for (let index = keepStart; index <= keepEnd; index += 1) {
      const item = this.currentGridItems[index];
      if (item.kind !== 'photo' || !item.asset || !item.asset.id) {
        continue;
      }
      keepKeys.add(Thumbnail.buildThumbnailCacheKey(item.asset.id, requestSize));
    }

    Thumbnail.ThumbnailCache.updateViewportKeepKeys(keepKeys);
    if (keepKeys.size > 0) {
      Thumbnail.ThumbnailCache.pruneOutsideKeys(keepKeys);
    }
  }

  private maybeShiftActiveWindowWhileScrolling(): void {
    if (!this.isGridScrolling || this.pinchActive || this.sections.length <= 0) {
      return;
    }

    // Active Grid 已经绑定 source-backed 稳定索引空间；
    // 滑窗移动只服务于内部预加载与锚点计算，不再驱动 Grid 数据源更新。
    const shifted = this.syncActiveWindowToVisibleAnchor(false, false, false);
    if (!shifted) {
      return;
    }

    this.lastForwardPrefetchEnd = this.lastVisibleGridEnd;
    this.lastBackwardPrefetchStart = this.lastVisibleGridStart;
  }

  private resolveRemotePredownloadRequestSizes(requestSize: number): Array<number> {
    if (requestSize <= 0) {
      return [];
    }
    return [Shared.resolveCanonicalRequestSizeBucket()];
  }

  private async predownloadSectionsForRequestSizes(
    sections: Array<PhotoSection>,
    includeAllAssets: boolean,
    requestSizes: Array<number>,
    limit: number,
    stopOnInteraction: boolean,
    batchSize: number,
    priorityHint: Thumbnail.HybridRemotePredownloadPriorityHint,
    persistedOnly: boolean = false,
  ): Promise<number> {
    if (requestSizes.length <= 0) {
      return 0;
    }

    let scheduledCount = 0;
    for (let index = 0; index < requestSizes.length; index += 1) {
      const candidateRequestSize = requestSizes[index];
      scheduledCount += await this.predownloadSectionsUpToLimit(
        sections,
        includeAllAssets,
        candidateRequestSize,
        limit,
        stopOnInteraction,
        batchSize,
        priorityHint,
        persistedOnly,
      );
      if (stopOnInteraction && (this.isGridScrolling || this.pinchActive)) {
        return scheduledCount;
      }
    }
    return scheduledCount;
  }

  private resolveInitialRemotePredownloadRequestSize(): number {
    return Shared.resolveCanonicalRequestSizeBucket();
  }

  private shouldAbortInitialRemotePredownload(token: number): boolean {
    return token !== this.initialRemotePredownloadToken || !this.initialized;
  }

  private countReadyRemotePredownloadAssets(
    sections: Array<PhotoSection>,
    requestSize: number,
    limit: number,
  ): number {
    if (sections.length <= 0 || limit <= 0) {
      return 0;
    }

    const assets = this.timelineLayoutBuilder.collectPredownloadAssets(sections, true);
    let readyCount = 0;
    for (let index = 0; index < assets.length; index += 1) {
      if (readyCount >= limit) {
        return readyCount;
      }

      const asset = assets[index];
      const remoteUrl = asset.thumbnailUrl;
      if (!remoteUrl || remoteUrl.length <= 0) {
        continue;
      }

      if (!Thumbnail.hasPersistedRemoteThumbnailCache(this.context, remoteUrl, requestSize, false)) {
        continue;
      }

      readyCount += 1;
    }
    return readyCount;
  }

  private adoptPrefetchedPageCursor(
    windowEndOffset: number,
    nextOffset: number,
    hasMore: boolean,
  ): void {
    this.timelineViewModel.adoptPrefetchedPageCursor(windowEndOffset, nextOffset, hasMore);
    this.hasMore = this.timelineViewModel.getHasMore();
  }

  private collectRemotePredownloadCandidates(
    sections: Array<PhotoSection>,
    includeAllAssets: boolean,
    requestSize: number,
    limit: number,
    persistedOnly: boolean = false,
  ): Array<PhotoAsset> {
    if (sections.length <= 0 || limit <= 0) {
      return [];
    }

    const assets = this.timelineLayoutBuilder.collectPredownloadAssets(sections, includeAllAssets);
    const selected: Array<PhotoAsset> = [];
    for (let index = 0; index < assets.length; index += 1) {
      if (selected.length >= limit) {
        return selected;
      }

      const asset = assets[index];
      const remoteUrl = asset.thumbnailUrl;
      if (!remoteUrl || remoteUrl.length <= 0) {
        continue;
      }
      const covered = persistedOnly
        ? Thumbnail.hasPersistedRemoteThumbnailCache(this.context, remoteUrl, requestSize, false)
        : Thumbnail.hasRemoteThumbnailCache(this.context, remoteUrl, requestSize, false);
      if (covered) {
        continue;
      }
      selected.push(asset);
    }
    return selected;
  }

  private buildRemotePredownloadCoverageSnapshot(
    sections: Array<PhotoSection>,
    includeAllAssets: boolean,
    requestSizes: Array<number>,
  ): RemotePredownloadCoverageSnapshot {
    if (sections.length <= 0 || requestSizes.length <= 0) {
      return {
        totalRemoteAssetCount: 0,
        totalBucketEntryCount: 0,
        persistedGapCount: 0,
        transientOnlyGapCount: 0,
        fullMissGapCount: 0,
      };
    }

    const assets = this.timelineLayoutBuilder.collectPredownloadAssets(sections, includeAllAssets);
    const seenRemoteUrls: Set<string> = new Set();
    let totalRemoteAssetCount = 0;
    let totalBucketEntryCount = 0;
    let persistedGapCount = 0;
    let transientOnlyGapCount = 0;
    let fullMissGapCount = 0;

    for (let index = 0; index < assets.length; index += 1) {
      const asset = assets[index];
      const remoteUrl = asset.thumbnailUrl;
      if (!remoteUrl || remoteUrl.length <= 0 || seenRemoteUrls.has(remoteUrl)) {
        continue;
      }
      seenRemoteUrls.add(remoteUrl);
      totalRemoteAssetCount += 1;

      for (let requestSizeIndex = 0; requestSizeIndex < requestSizes.length; requestSizeIndex += 1) {
        const candidateRequestSize = requestSizes[requestSizeIndex];
        totalBucketEntryCount += 1;
        if (Thumbnail.hasPersistedRemoteThumbnailCache(this.context, remoteUrl, candidateRequestSize, false)) {
          continue;
        }

        persistedGapCount += 1;
        if (Thumbnail.hasRemoteThumbnailCache(this.context, remoteUrl, candidateRequestSize, false)) {
          transientOnlyGapCount += 1;
          continue;
        }

        fullMissGapCount += 1;
      }
    }

    return {
      totalRemoteAssetCount: totalRemoteAssetCount,
      totalBucketEntryCount: totalBucketEntryCount,
      persistedGapCount: persistedGapCount,
      transientOnlyGapCount: transientOnlyGapCount,
      fullMissGapCount: fullMissGapCount,
    };
  }

  private buildLoadedRemotePredownloadCoverageSnapshot(
    requestSizes: Array<number>,
  ): RemotePredownloadCoverageSnapshot {
    return this.buildRemotePredownloadCoverageSnapshot(
      this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
      true,
      requestSizes,
    );
  }

  private collectGridRangeRemotePredownloadCandidates(
    startIndex: number,
    endIndex: number,
    requestSize: number,
    limit: number,
  ): Array<PhotoAsset> {
    if (this.currentGridItems.length <= 0 || limit <= 0) {
      return [];
    }

    const safeStart = Math.max(0, startIndex);
    const safeEnd = Math.min(endIndex, this.currentGridItems.length - 1);
    if (safeStart > safeEnd) {
      return [];
    }

    const selected: Array<PhotoAsset> = [];
    const seenRemoteUrls: Set<string> = new Set();
    for (let index = safeStart; index <= safeEnd; index += 1) {
      if (selected.length >= limit) {
        return selected;
      }

      const item = this.currentGridItems[index];
      if (item.kind !== 'photo' || !item.asset || !item.asset.thumbnailUrl) {
        continue;
      }

      const remoteUrl = item.asset.thumbnailUrl;
      if (seenRemoteUrls.has(remoteUrl)) {
        continue;
      }
      seenRemoteUrls.add(remoteUrl);

      if (Thumbnail.hasRemoteThumbnailCache(this.context, remoteUrl, requestSize, false)) {
        continue;
      }

      selected.push(item.asset);
    }
    return selected;
  }

  private hasLoadedRemotePredownloadCandidates(
    requestSize: number,
    persistedOnly: boolean = false,
  ): boolean {
    return this.collectRemotePredownloadCandidates(
      this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
      true,
      requestSize,
      1,
      persistedOnly,
    ).length > 0;
  }

  private hasLoadedRemotePredownloadCandidatesForRequestSizes(
    requestSizes: Array<number>,
    persistedOnly: boolean = false,
  ): boolean {
    for (let index = 0; index < requestSizes.length; index += 1) {
      if (this.hasLoadedRemotePredownloadCandidates(requestSizes[index], persistedOnly)) {
        return true;
      }
    }
    return false;
  }

  private hasBackgroundCoverageWork(requestSizes: Array<number>): boolean {
    if (this.hasMore) {
      return true;
    }
    return this.hasLoadedRemotePredownloadCandidatesForRequestSizes(requestSizes, true);
  }

  private async predownloadRemoteAssets(
    assets: Array<PhotoAsset>,
    requestSize: number,
    stopOnInteraction: boolean,
    batchSize: number,
    priorityHint: Thumbnail.HybridRemotePredownloadPriorityHint,
  ): Promise<number> {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES ||
      assets.length <= 0 ||
      Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      return 0;
    }

    const safeBatchSize = Math.max(1, batchSize);
    let scheduledCount = 0;
    for (let index = 0; index < assets.length; index += safeBatchSize) {
      while (
        Thumbnail.ThumbnailRequestLimiter.isUnderPressure() ||
        Thumbnail.shouldThrottleRemoteDiskPredownload()
      ) {
        Thumbnail.flushDeferredThumbnailWritesIfIdle();
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 2);
        if (stopOnInteraction && (this.isGridScrolling || this.pinchActive)) {
          return scheduledCount;
        }
      }

      if (stopOnInteraction && (this.isGridScrolling || this.pinchActive)) {
        return scheduledCount;
      }

      const batch = assets.slice(index, index + safeBatchSize);
      await Promise.all(
        batch.map((asset: PhotoAsset) => {
          if (!asset.thumbnailUrl) {
            return Promise.resolve();
          }
          return Thumbnail.backgroundPredownloadRemoteThumbnail(
            this.context,
            asset.thumbnailUrl,
            requestSize,
            priorityHint,
          );
        }),
      );
      scheduledCount += batch.length;
      await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
    }
    return scheduledCount;
  }

  private async predownloadSectionsUpToLimit(
    sections: Array<PhotoSection>,
    includeAllAssets: boolean,
    requestSize: number,
    limit: number,
    stopOnInteraction: boolean,
    batchSize: number,
    priorityHint: Thumbnail.HybridRemotePredownloadPriorityHint,
    persistedOnly: boolean = false,
  ): Promise<number> {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES ||
      sections.length <= 0 ||
      limit <= 0 ||
      Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      return 0;
    }

    const candidates = this.collectRemotePredownloadCandidates(
      sections,
      includeAllAssets,
      requestSize,
      limit,
      persistedOnly,
    );
    return await this.predownloadRemoteAssets(
      candidates,
      requestSize,
      stopOnInteraction,
      batchSize,
      priorityHint,
    );
  }

  private async predownloadGridRangeToDiskUpToLimit(
    startIndex: number,
    endIndex: number,
    requestSize: number,
    limit: number,
    priorityHint: Thumbnail.HybridRemotePredownloadPriorityHint,
  ): Promise<number> {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES ||
      this.currentGridItems.length <= 0 ||
      this.pinchActive ||
      this.isGridScrolling ||
      limit <= 0 ||
      Thumbnail.shouldThrottleRemoteDiskPredownload()) {
      return 0;
    }

    const candidates = this.collectGridRangeRemotePredownloadCandidates(
      startIndex,
      endIndex,
      requestSize,
      limit,
    );
    return await this.predownloadRemoteAssets(
      candidates,
      requestSize,
      true,
      Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE,
      priorityHint,
    );
  }

  private async predownloadViewportRunwayToDisk(requestSizes: Array<number>): Promise<number> {
    const range = this.resolveScrollStopPrefetchRange();
    if (!range || requestSizes.length <= 0) {
      return 0;
    }

    let scheduledCount = 0;
    for (let index = 0; index < requestSizes.length; index += 1) {
      scheduledCount += await this.predownloadGridRangeToDiskUpToLimit(
        range.startIndex,
        range.endIndex,
        requestSizes[index],
        Number.MAX_SAFE_INTEGER,
        Thumbnail.HybridRemotePredownloadPriorityHint.NEARBY,
      );
      if (this.isGridScrolling || this.pinchActive) {
        return scheduledCount;
      }
    }
    return scheduledCount;
  }

  private async predownloadLoadedResidualSections(requestSizes: Array<number>): Promise<number> {
    return await this.predownloadSectionsForRequestSizes(
      this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
      true,
      requestSizes,
      Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE,
      true,
      Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE,
      Thumbnail.HybridRemotePredownloadPriorityHint.BACKGROUND,
      true,
    );
  }

  private startInitialRemotePredownloadIfNeeded(): void {
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES || !this.initialized) {
      return;
    }

    if (this.isGridScrolling || this.pinchActive || this.listWidth <= 0 || this.listHeight <= 0) {
      return;
    }

    const requestSize = this.resolveInitialRemotePredownloadRequestSize();
    const requestSizes = this.resolveRemotePredownloadRequestSizes(requestSize);
    if (requestSize <= 0 || requestSizes.length <= 0) {
      return;
    }

    if (this.initialRemotePredownloadRequestSize !== requestSize) {
      this.initialRemotePredownloadToken += 1;
      this.initialRemotePredownloadRunning = false;
      this.initialRemotePredownloadCompleted = false;
      this.initialRemotePredownloadRequestSize = requestSize;
    }

    if (this.initialRemotePredownloadRunning) {
      return;
    }

    const sourceSections = this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY);
    if (sourceSections.length <= 0) {
      return;
    }

    const targetCount = Shared.HYBRID_INITIAL_REMOTE_PREDOWNLOAD_TARGET;
    const readyCount = this.countReadyRemotePredownloadAssets(sourceSections, requestSize, targetCount);
    if (readyCount >= targetCount) {
      this.initialRemotePredownloadCompleted = true;
      return;
    }

    this.initialRemotePredownloadCompleted = false;
    const token = ++this.initialRemotePredownloadToken;
    this.initialRemotePredownloadRunning = true;
    this.initialRemotePredownloadRequestSize = requestSize;
    console.info(
      `[PhotoGridViewModel] initial remote predownload start: ready=${readyCount}/${targetCount}, ` +
        `requestSize=${requestSize} requestSizeFamily=${requestSizes.join(',')}`,
    );
    void this.runInitialRemotePredownload(token, requestSize, readyCount, requestSizes).finally(() => {
      if (token === this.initialRemotePredownloadToken) {
        this.initialRemotePredownloadRunning = false;
      }
    });
  }

  private async runInitialRemotePredownload(
    token: number,
    requestSize: number,
    initialReadyCount: number,
    requestSizes: Array<number>,
  ): Promise<void> {
    const targetCount = Shared.HYBRID_INITIAL_REMOTE_PREDOWNLOAD_TARGET;
    let readyCount = initialReadyCount;
    let offset = this.timelineViewModel.getNextOffset();
    let exhaustedPages = offset <= 0;

    if (readyCount < targetCount) {
      await this.predownloadSectionsForRequestSizes(
        this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
        true,
        requestSizes,
        targetCount - readyCount,
        true,
        Shared.HYBRID_INITIAL_REMOTE_PREDOWNLOAD_BATCH_SIZE,
        Thumbnail.HybridRemotePredownloadPriorityHint.INITIAL,
      );
      readyCount = this.countReadyRemotePredownloadAssets(
        this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
        requestSize,
        targetCount,
      );
    }

    while (!this.shouldAbortInitialRemotePredownload(token) &&
      readyCount < targetCount &&
      Thumbnail.shouldContinueBackgroundPredownload(this.context) &&
      !exhaustedPages) {
      if (this.isGridScrolling || this.pinchActive) {
        Thumbnail.flushDeferredThumbnailWritesIfIdle();
        await Shared.delay(Shared.HYBRID_INITIAL_REMOTE_PREDOWNLOAD_RESUME_DELAY_MS);
        continue;
      }

      while (
        Thumbnail.ThumbnailRequestLimiter.isUnderPressure() ||
        Thumbnail.shouldThrottleRemoteDiskPredownload()
      ) {
        Thumbnail.flushDeferredThumbnailWritesIfIdle();
        await Shared.delay(Shared.HYBRID_INITIAL_REMOTE_PREDOWNLOAD_RESUME_DELAY_MS);
        if (this.shouldAbortInitialRemotePredownload(token)) {
          return;
        }
      }

      try {
        const payload = await HybridFlutterBridge.fetchTimelineWindow(offset, Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE);
        const page = this.timelineLayoutBuilder.parsePageResult(payload);
        if (!page.ready || page.sections.length <= 0) {
          exhaustedPages = true;
          break;
        }

        this.logDuplicateAssetKeysOnce(
          'appendSourcePage:pre',
          page.sections,
          page.windowStartOffset,
          page.windowEndOffset,
          FormIndex.DAY,
        );

        this.timelineDataManager.appendSourcePage({
          sections: page.sections,
          groupDayGroups: page.groupDayGroups,
          yearBuckets: page.yearBuckets,
          monthBuckets: page.monthBuckets,
          windowStartOffset: page.windowStartOffset,
          windowEndOffset: page.windowEndOffset,
          hasMore: page.hasMore,
        });
        this.adoptPrefetchedPageCursor(page.windowEndOffset, page.nextOffset, page.hasMore);

        this.logDuplicateAssetKeysOnce(
          'appendSourcePage:post',
          this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
          this.timelineDataManager.getSourceWindowStartOffset(),
          this.timelineDataManager.getSourceWindowEndOffset(),
          FormIndex.DAY,
        );

        await this.predownloadSectionsForRequestSizes(
          page.sections,
          true,
          requestSizes,
          targetCount - readyCount,
          true,
          Shared.HYBRID_INITIAL_REMOTE_PREDOWNLOAD_BATCH_SIZE,
          Thumbnail.HybridRemotePredownloadPriorityHint.INITIAL,
        );
        readyCount = this.countReadyRemotePredownloadAssets(
          this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
          requestSize,
          targetCount,
        );

        if (!page.hasMore || page.nextOffset <= offset) {
          exhaustedPages = true;
          break;
        }

        offset = page.nextOffset;
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
      } catch (_error) {
        break;
      }
    }

    if (this.shouldAbortInitialRemotePredownload(token)) {
      return;
    }

    const completed = readyCount >= targetCount || exhaustedPages;
    this.initialRemotePredownloadCompleted = completed;
    console.info(
      `[PhotoGridViewModel] initial remote predownload finish: ready=${readyCount}/${targetCount}, ` +
        `completed=${completed ? 1 : 0}, exhaustedPages=${exhaustedPages ? 1 : 0} ` +
        `requestSize=${requestSize} requestSizeFamily=${requestSizes.join(',')}`,
    );
    if (completed) {
      this.startBackgroundPredownload();
    }
  }

  private startBackgroundPredownload(): void {
    this.cancelBackgroundPredownloadRetry();
    if (!this.initialRemotePredownloadCompleted) {
      this.logBackgroundPredownloadSkip('initial-not-complete');
      this.startInitialRemotePredownloadIfNeeded();
      return;
    }

    const throttled = Thumbnail.shouldThrottleRemoteDiskPredownload();
    const underPressure = Thumbnail.ThumbnailRequestLimiter.isUnderPressure();
    const canContinueBackgroundPredownload = throttled || Thumbnail.shouldContinueBackgroundPredownload(this.context);
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES) {
      this.logBackgroundPredownloadSkip(
        'disk-writes-disabled',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    if (this.isGridScrolling) {
      this.logBackgroundPredownloadSkip(
        'grid-scrolling',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    if (this.pinchActive) {
      this.logBackgroundPredownloadSkip(
        'pinch-active',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    if (this.backgroundPredownloadRunning) {
      this.logBackgroundPredownloadSkip(
        'already-running',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    if (!canContinueBackgroundPredownload) {
      this.logBackgroundPredownloadSkip(
        'should-continue-false',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    const requestSize = this.resolveRequestSize(this.activeForm);
    const requestSizes = this.resolveRemotePredownloadRequestSizes(requestSize);
    if (requestSize <= 0 || requestSizes.length <= 0) {
      this.logBackgroundPredownloadSkip(
        'request-size<=0',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    const hasBackgroundCoverageWork = this.hasBackgroundCoverageWork(requestSizes);
    if (!hasBackgroundCoverageWork) {
      this.logBackgroundPredownloadSkip(
        'coverage-complete',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      return;
    }

    if (throttled || underPressure) {
      this.logBackgroundPredownloadSkip(
        'retry-throttled-or-under-pressure',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
      );
      this.scheduleBackgroundPredownloadRetry();
      return;
    }

    const startOffset = this.timelineViewModel.getNextOffset();
    if (startOffset <= 0 && !this.hasLoadedRemotePredownloadCandidatesForRequestSizes(requestSizes, true)) {
      this.logBackgroundPredownloadSkip(
        'next-offset<=0',
        throttled,
        underPressure,
        canContinueBackgroundPredownload,
        startOffset,
      );
      return;
    }

    const token = ++this.backgroundPredownloadToken;
    this.backgroundPredownloadRunning = true;
    void this.runBackgroundPredownload(token, startOffset, requestSizes).finally(() => {
      if (token === this.backgroundPredownloadToken) {
        this.backgroundPredownloadRunning = false;
      }
      const currentRequestSizes = this.resolveRemotePredownloadRequestSizes(this.resolveRequestSize(this.activeForm));
      const hasBackgroundCoverageWorkAfterRun = this.hasBackgroundCoverageWork(currentRequestSizes);
      if (!this.isGridScrolling &&
        !this.pinchActive &&
        !this.backgroundPredownloadRunning &&
        hasBackgroundCoverageWorkAfterRun &&
        (Thumbnail.shouldThrottleRemoteDiskPredownload() ||
          Thumbnail.ThumbnailRequestLimiter.isUnderPressure())) {
        this.scheduleBackgroundPredownloadRetry();
      }
    });
  }

  private logBackgroundPredownloadSkip(
    reason: string,
    throttled: boolean = false,
    underPressure: boolean = false,
    canContinueBackgroundPredownload: boolean = false,
    nextOffset?: number,
  ): void {
    const resolvedNextOffset = nextOffset ?? this.timelineViewModel.getNextOffset();
    console.info(
      `[PhotoGridViewModel] background predownload skip: reason=${reason} ` +
        `hasMore=${this.hasMore ? 1 : 0} nextOffset=${resolvedNextOffset} ` +
        `canContinue=${canContinueBackgroundPredownload ? 1 : 0} ` +
        `throttled=${throttled ? 1 : 0} underPressure=${underPressure ? 1 : 0} ` +
        `scrolling=${this.isGridScrolling ? 1 : 0} pinch=${this.pinchActive ? 1 : 0} ` +
        `running=${this.backgroundPredownloadRunning ? 1 : 0}`,
    );
  }

  private scheduleBackgroundPredownloadRetry(): void {
    const requestSize = this.resolveRequestSize(this.activeForm);
    const requestSizes = this.resolveRemotePredownloadRequestSizes(requestSize);
    if (!Shared.HYBRID_ENABLE_REMOTE_THUMBNAIL_DISK_WRITES ||
      !this.initialized ||
      requestSize <= 0 ||
      requestSizes.length <= 0 ||
      !this.initialRemotePredownloadCompleted ||
      this.isGridScrolling ||
      this.pinchActive ||
      this.backgroundPredownloadRunning ||
      !this.hasBackgroundCoverageWork(requestSizes) ||
      this.backgroundPredownloadRetryTimeoutId !== undefined) {
      return;
    }

    const retryToken = this.backgroundPredownloadToken;
    this.backgroundPredownloadRetryTimeoutId = setTimeout((): void => {
      this.backgroundPredownloadRetryTimeoutId = undefined;
      if (!this.initialized || retryToken !== this.backgroundPredownloadToken) {
        return;
      }
      this.startBackgroundPredownload();
    }, Shared.HYBRID_DISK_IDLE_DELAY_MS);
  }

  private async runBackgroundPredownload(
    token: number,
    startOffset: number,
    requestSizes: Array<number>,
  ): Promise<void> {
    let offset = startOffset;
    const primaryRequestSize = requestSizes.length > 0 ? requestSizes[0] : 0;
    const requestSizeFamily = requestSizes.join(',');
    const initialLoadedCoverage = this.buildLoadedRemotePredownloadCoverageSnapshot(requestSizes);
    console.info(
      `[PhotoGridViewModel] background predownload run start: startOffset=${startOffset} ` +
        `requestSize=${primaryRequestSize} requestSizeFamily=${requestSizeFamily} ` +
        `hasMore=${this.hasMore ? 1 : 0} totalBucketEntryCount=${initialLoadedCoverage.totalBucketEntryCount} ` +
        `persistedGapCount=${initialLoadedCoverage.persistedGapCount} ` +
        `transientOnlyGapCount=${initialLoadedCoverage.transientOnlyGapCount} ` +
        `fullMissGapCount=${initialLoadedCoverage.fullMissGapCount}`,
    );

    while (token === this.backgroundPredownloadToken && Thumbnail.shouldContinueBackgroundPredownload(this.context)) {
      if (
        this.isGridScrolling ||
        this.pinchActive ||
        Thumbnail.ThumbnailRequestLimiter.isUnderPressure() ||
        Thumbnail.shouldThrottleRemoteDiskPredownload()
      ) {
        Thumbnail.flushDeferredThumbnailWritesIfIdle();
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS * 4);
        continue;
      }

      const runwayScheduled = await this.predownloadViewportRunwayToDisk(requestSizes);
      if (runwayScheduled > 0) {
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
        continue;
      }

      const residualScheduled = await this.predownloadLoadedResidualSections(requestSizes);
      if (residualScheduled > 0) {
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
        continue;
      }

      if (!this.hasMore) {
        const loadedCoverage = this.buildLoadedRemotePredownloadCoverageSnapshot(requestSizes);
        console.info(
          `[PhotoGridViewModel] background predownload stop: reason=loaded-residual-complete ` +
            `offset=${offset} nextOffset=${this.timelineViewModel.getNextOffset()} ` +
            `windowEndOffset=${this.timelineDataManager.getSourceWindowEndOffset()} ` +
            `requestSize=${primaryRequestSize} requestSizeFamily=${requestSizeFamily} ` +
            `totalRemote=${loadedCoverage.totalRemoteAssetCount} ` +
            `totalBucketEntryCount=${loadedCoverage.totalBucketEntryCount} ` +
            `persistedGapCount=${loadedCoverage.persistedGapCount} ` +
            `transientOnlyGapCount=${loadedCoverage.transientOnlyGapCount} ` +
            `fullMissGapCount=${loadedCoverage.fullMissGapCount}`,
        );
        break;
      }

      try {
        const payload = await HybridFlutterBridge.fetchTimelineWindow(offset, Shared.HYBRID_BACKGROUND_PREDOWNLOAD_PAGE_SIZE);
        const page = this.timelineLayoutBuilder.parsePageResult(payload);
        if (!page.ready || page.sections.length <= 0) {
          console.info(
            `[PhotoGridViewModel] background predownload stop: reason=page-not-ready-or-empty ` +
              `offset=${offset} ready=${page.ready ? 1 : 0} sections=${page.sections.length}`,
          );
          break;
        }

        await this.predownloadSectionsForRequestSizes(
          page.sections,
          true,
          requestSizes,
          Number.MAX_SAFE_INTEGER,
          true,
          Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE,
          Thumbnail.HybridRemotePredownloadPriorityHint.BACKGROUND,
        );

        this.logDuplicateAssetKeysOnce(
          'appendSourcePage:pre',
          page.sections,
          page.windowStartOffset,
          page.windowEndOffset,
          FormIndex.DAY,
        );

        this.timelineDataManager.appendSourcePage({
          sections: page.sections,
          groupDayGroups: page.groupDayGroups,
          yearBuckets: page.yearBuckets,
          monthBuckets: page.monthBuckets,
          windowStartOffset: page.windowStartOffset,
          windowEndOffset: page.windowEndOffset,
          hasMore: page.hasMore,
        });
        this.adoptPrefetchedPageCursor(page.windowEndOffset, page.nextOffset, page.hasMore);

        this.logDuplicateAssetKeysOnce(
          'appendSourcePage:post',
          this.timelineDataManager.getSourceSectionsForForm(FormIndex.DAY),
          this.timelineDataManager.getSourceWindowStartOffset(),
          this.timelineDataManager.getSourceWindowEndOffset(),
          FormIndex.DAY,
        );

        if (!page.hasMore) {
          console.info(
            `[PhotoGridViewModel] background predownload page tail reached: ` +
              `offset=${offset} nextOffset=${page.nextOffset} windowEndOffset=${page.windowEndOffset}`,
          );
        }

        if (page.nextOffset <= offset) {
          console.info(
            `[PhotoGridViewModel] background predownload stop: reason=page-nextOffset<=offset ` +
              `offset=${offset} nextOffset=${page.nextOffset} windowEndOffset=${page.windowEndOffset}`,
          );
          break;
        }

        offset = page.nextOffset;
        await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
      } catch (error) {
        console.warn(
          `[PhotoGridViewModel] background predownload stop: reason=exception ` +
            `offset=${offset} error=${error instanceof Error ? error.message : String(error)}`,
        );
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
      void this.runIdlePrefetchWork(token, requestSize);
    }, Shared.HYBRID_SCROLL_IDLE_DELAY_MS);
  }

  private logDuplicateAssetKeysOnce(
    stage: string,
    sections: Array<PhotoSection>,
    windowStartOffset: number,
    windowEndOffset: number,
    form: FormIndex,
  ): void {
    if (stage === 'appendSourcePage:pre') {
      if (this.appendSourcePagePreDuplicateLogged) {
        return;
      }
    } else if (stage === 'appendSourcePage:post') {
      if (this.appendSourcePagePostDuplicateLogged) {
        return;
      }
    } else if (stage === 'syncActiveSourceProjection:pre') {
      if (this.syncActiveProjectionPreDuplicateLogged) {
        return;
      }
    }

    const stats = this.collectDuplicateAssetKeyStats(sections);
    if (stats.duplicateKeyCount <= 0) {
      return;
    }

    if (stage === 'appendSourcePage:pre') {
      this.appendSourcePagePreDuplicateLogged = true;
    } else if (stage === 'appendSourcePage:post') {
      this.appendSourcePagePostDuplicateLogged = true;
    } else if (stage === 'syncActiveSourceProjection:pre') {
      this.syncActiveProjectionPreDuplicateLogged = true;
    }
    console.warn(
      `[PhotoGridViewModel] duplicate asset keys at ${stage}: form=${FormIndex[form]}, ` +
        `window=[${windowStartOffset}, ${windowEndOffset}), sections=${sections.length}, ` +
        `totalAssets=${stats.totalAssetCount}, uniqueKeys=${stats.uniqueKeyCount}, ` +
        `duplicateKeys=${stats.duplicateKeyCount}, duplicateAssets=${stats.duplicateAssetCount}, ` +
        `firstDuplicateKey=${stats.firstDuplicateKey}`,
    );
  }

  private collectDuplicateAssetKeyStats(sections: Array<PhotoSection>): DuplicateAssetKeyStats {
    const countsByKey: Map<string, number> = new Map();
    let totalAssetCount = 0;
    for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex += 1) {
      const section = sections[sectionIndex];
      for (let rowIndex = 0; rowIndex < section.rows.length; rowIndex += 1) {
        const row = section.rows[rowIndex];
        for (let assetIndex = 0; assetIndex < row.length; assetIndex += 1) {
          const asset = row[assetIndex];
          const assetKey = this.resolveDuplicateAssetKey(asset);
          totalAssetCount += 1;
          const previousCount = countsByKey.get(assetKey);
          if (previousCount === undefined) {
            countsByKey.set(assetKey, 1);
          } else {
            countsByKey.set(assetKey, previousCount + 1);
          }
        }
      }
    }

    let duplicateKeyCount = 0;
    let duplicateAssetCount = 0;
    let firstDuplicateKey = '';
    countsByKey.forEach((count: number, key: string): void => {
      if (count <= 1) {
        return;
      }
      duplicateKeyCount += 1;
      duplicateAssetCount += count - 1;
      if (firstDuplicateKey.length <= 0) {
        firstDuplicateKey = key;
      }
    });

    return {
      totalAssetCount: totalAssetCount,
      uniqueKeyCount: countsByKey.size,
      duplicateKeyCount: duplicateKeyCount,
      duplicateAssetCount: duplicateAssetCount,
      firstDuplicateKey: firstDuplicateKey,
    };
  }

  private resolveDuplicateAssetKey(asset: PhotoAsset): string {
    if (asset.remoteId !== undefined && asset.remoteId.length > 0) {
      return asset.remoteId;
    }
    if (asset.localId !== undefined && asset.localId.length > 0) {
      return asset.localId;
    }
    if (asset.id.length > 0) {
      return asset.id;
    }
    if (asset.thumbnailUrl !== undefined && asset.thumbnailUrl.length > 0) {
      return asset.thumbnailUrl;
    }
    return '__missing_asset_key__';
  }

  private shouldAbortIdlePrefetchWork(token: number): boolean {
    return token !== this.idleWorkToken || this.isGridScrolling || this.pinchActive;
  }

  private async runIdlePrefetchWork(token: number, requestSize: number): Promise<void> {
    if (this.shouldAbortIdlePrefetchWork(token)) {
      return;
    }

    const requestSizes = this.resolveRemotePredownloadRequestSizes(requestSize);

    Thumbnail.flushDeferredThumbnailWritesIfIdle();
    await Shared.delay(Shared.HYBRID_BACKGROUND_PREDOWNLOAD_YIELD_MS);
    if (this.shouldAbortIdlePrefetchWork(token)) {
      return;
    }

    Thumbnail.trimRemoteThumbnailCacheIfNeeded(this.context);
    this.startInitialRemotePredownloadIfNeeded();
    if (this.initialRemotePredownloadRunning || !this.initialRemotePredownloadCompleted) {
      return;
    }

    this.prefetchVisibleAndAheadAfterScrollStop(true);
    if (this.shouldAbortIdlePrefetchWork(token)) {
      return;
    }

    await this.predownloadSectionsForRequestSizes(
      this.sections,
      true,
      requestSizes,
      Number.MAX_SAFE_INTEGER,
      true,
      Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE,
      Thumbnail.HybridRemotePredownloadPriorityHint.NEARBY,
    );
    if (this.shouldAbortIdlePrefetchWork(token)) {
      return;
    }

    const pendingSections = this.pendingWarmupSections.splice(0, this.pendingWarmupSections.length);
    if (pendingSections.length > 0) {
      await this.predownloadSectionsForRequestSizes(
        pendingSections,
        false,
        requestSizes,
        Number.MAX_SAFE_INTEGER,
        true,
        Shared.HYBRID_BACKGROUND_PREDOWNLOAD_BATCH_SIZE,
        Thumbnail.HybridRemotePredownloadPriorityHint.NEARBY,
      );
      if (this.shouldAbortIdlePrefetchWork(token)) {
        return;
      }
    }

    this.startBackgroundPredownload();
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

    const restoreToken = this.renderVersion;
    this.transitionTimeoutId = setTimeout((): void => {
      this.continueRestoreFillPosition(form, restoreToken);
    }, FILL_POSITION_RESTORE_DELAY_MS);
  }

  private continueRestoreFillPosition(form: FormIndex, restoreToken: number): void {
    if (this.activeForm !== form || this.pinchActive || restoreToken !== this.renderVersion) {
      this.transitionTimeoutId = undefined;
      return;
    }

    if (this.stateProxy.switchStateManager.isSwitchingAsm.currentState) {
      this.transitionTimeoutId = setTimeout((): void => {
        this.continueRestoreFillPosition(form, restoreToken);
      }, 32) as number;
      return;
    }

    this.transitionTimeoutId = undefined;
    const state = this.getGridState(form);
    state.fillPosition = this.timelineDataManager.resolveSourceFillPositionForForm(form);
    this.currentGridItems = this.buildCommittedGridItems();
    this.reconcileFormGridItems(form, this.currentGridItems);
    this.syncStateProxyRuntime('restoreFillPosition.ready');
    this.notifyStateChanged();
  }

  private updateSwitchTransitionState(
    isSwitching: boolean,
    fromForm: FormIndex,
    toForm: FormIndex,
    reason: string,
  ): void {
    this.stateProxy.switchStateManager.updateTransitionState(isSwitching, fromForm, toForm, reason);
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
    const isActiveWindow = reason === TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW ||
      reason === TimelinePreloadReason.POST_COMMIT;
    const normalizedFillPosition = reason === TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW
      ? fillPosition
      : Math.max(0, fillPosition);
    let backwardBuffer: number;
    let forwardBuffer: number;
    if (isPinchPreSwitch) {
      backwardBuffer = Math.max(viewportItemCount, state.columns * 2);
      forwardBuffer = Math.max(viewportItemCount * 2, state.columns * 6);
    } else if (isActiveWindow) {
      backwardBuffer = Math.max(
        viewportItemCount * Shared.HYBRID_KEEP_ABOVE_SCREEN_MULTIPLIER,
        state.columns * Shared.HYBRID_ACTIVE_ROW_KEEP_BEHIND,
      );
      forwardBuffer = Math.max(
        viewportItemCount * Shared.HYBRID_KEEP_BELOW_SCREEN_MULTIPLIER,
        state.columns * Shared.HYBRID_ACTIVE_ROW_KEEP_AHEAD,
      );
    } else {
      backwardBuffer = Math.max(state.columns, Math.floor(viewportItemCount / 2));
      forwardBuffer = Math.max(viewportItemCount, state.columns * 4);
    }
    return {
      form: form,
      firstIndex: Math.max(0, firstIndex),
      anchorPhotoOffset: Math.max(0, anchorPhotoOffset),
      fillPosition: normalizedFillPosition,
      includeTail: includeTail,
      reason: reason,
      viewportItemCount: viewportItemCount,
      backwardBufferItemCount: backwardBuffer,
      forwardBufferItemCount: forwardBuffer,
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
    const fallbackPhotoOffset = this.timelineDataManager.getSourceWindowStartOffset() +
      Math.max(0, this.getGridState(this.activeForm).firstVisibleIndex);
    if (this.currentGridItems.length <= 0) {
      return fallbackPhotoOffset;
    }

    const startIndex = Math.max(0, Math.min(this.lastVisibleGridStart, this.currentGridItems.length - 1));
    const endIndex = Math.max(startIndex, Math.min(this.lastVisibleGridEnd, this.currentGridItems.length - 1));
    for (let index = startIndex; index <= endIndex; index += 1) {
      const photoOffset = this.resolveGlobalPhotoOffsetFromGridItem(this.currentGridItems[index]);
      if (photoOffset !== undefined) {
        return photoOffset;
      }
    }

    for (let index = 0; index < this.currentGridItems.length; index += 1) {
      const photoOffset = this.resolveGlobalPhotoOffsetFromGridItem(this.currentGridItems[index]);
      if (photoOffset !== undefined) {
        return photoOffset;
      }
    }
    return fallbackPhotoOffset;
  }

  private resolveGlobalPhotoOffsetFromGridItem(item: GridItem): number | undefined {
    if (item.kind !== 'photo' || item.sourceIndex === undefined) {
      return undefined;
    }
    return Math.max(0, item.sourceIndex);
  }

  private resolveSourceLocalPhotoOffset(globalPhotoOffset: number): number {
    return Math.max(0, globalPhotoOffset - this.timelineDataManager.getSourceWindowStartOffset());
  }

  private syncActiveWindowToVisibleAnchor(
    force: boolean = false,
    _syncDataSource: boolean = true,
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
      previousWindowPhotoCount === activeWindowResult.windowPhotoCount) {
      return false;
    }

    activeState.firstVisibleIndex = Math.max(0, activeRequest.anchorPhotoOffset - activeWindowResult.windowStartPhotoOffset);
    this.lastWindowAnchorGridIndex = activeWindowResult.anchorGridIndex;
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
    if (!clearDataSource && state.gridItems.length > 0) {
      return;
    }
    this.clearFormGridItems(form, clearDataSource);
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
      this.updateFormGridItems(request.form, preloadResult.gridItems);
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
    this.cancelBackgroundPredownloadRetry();
  }

  private cancelBackgroundPredownloadRetry(): void {
    if (this.backgroundPredownloadRetryTimeoutId !== undefined) {
      clearTimeout(this.backgroundPredownloadRetryTimeoutId);
      this.backgroundPredownloadRetryTimeoutId = undefined;
    }
  }

  private notifyStateChanged(): void {
    this.stateListeners.forEach((listener: () => void) => {
      listener();
    });
  }
}
