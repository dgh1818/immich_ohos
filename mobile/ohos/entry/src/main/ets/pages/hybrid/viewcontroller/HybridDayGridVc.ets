/**
 * HybridDayGridVc - 日宫格视图控制器
 * 负责管理视图状态、属性更新、动画控制等
 * 参考官方 DayGridVc.ets 架构
 */

import lazy { AttributeUpdater } from '@kit.ArkUI';
import { HybridDayGridVm, DataLoadListener, ScrollStateListener, PinchGestureListener } from '../viewmodel/HybridDayGridVm';
import * as Shared from '../HybridPhotoGridShared';
import { FormIndex, FORM_SIZE } from '../statemanager/constants/GridDefine';
import { FormStateType, FormStateTypeUtils } from '../statemanager/GridFormFsm';
import { PinchAction } from '../statemanager/constants/PinchDefine';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridTimelineItem = Shared.HybridTimelineItem;

/**
 * Grid 属性更新器
 */
export class HybridGridAttributeUpdater extends AttributeUpdater<GridAttribute> {
  private scaleOptions: ScaleOptions = { x: 1, y: 1 };
  private opacityValue: number = 1.0;
  private widthValue: Length = '100%';
  private heightValue: Length = '100%';
  private visibilityValue: Visibility = Visibility.Visible;
  private zIndexValue?: number;

  public override initializeModifier(instance: GridAttribute): void {
    instance
      .scale(this.scaleOptions)
      .opacity(this.opacityValue)
      .width(this.widthValue)
      .height(this.heightValue)
      .visibility(this.visibilityValue);
    if (this.zIndexValue !== undefined) {
      instance.zIndex(this.zIndexValue);
    }
  }

  public override onComponentChanged(instance: GridAttribute): void {
    instance
      .scale(this.scaleOptions)
      .opacity(this.opacityValue)
      .width(this.widthValue)
      .height(this.heightValue)
      .visibility(this.visibilityValue);
    if (this.zIndexValue !== undefined) {
      instance.zIndex(this.zIndexValue);
    }
  }

  public updateScale(scaleOptions: ScaleOptions): void {
    this.scaleOptions = scaleOptions;
    this.attribute?.scale(this.scaleOptions);
  }

  public updateOpacity(opacity: number): void {
    this.opacityValue = Math.max(0, Math.min(1, opacity));
    this.attribute?.opacity(this.opacityValue);
  }

  public updateSize(width: Length, height: Length): void {
    this.widthValue = width;
    this.heightValue = height;
    this.attribute?.width(this.widthValue);
    this.attribute?.height(this.heightValue);
  }

  public updateVisibility(visibility: Visibility): void {
    this.visibilityValue = visibility;
    this.attribute?.visibility(this.visibilityValue);
  }

  public updateZIndex(zIndex: number): void {
    this.zIndexValue = zIndex;
    this.attribute?.zIndex(this.zIndexValue);
  }
}

/**
 * 视图状态类型
 */
export enum ViewStateType {
  INIT = 0,
  SHOWING = 1,
  HIDDEN = 2,
  PINCH_PREVIEW = 3,
}

/**
 * 视图状态监听器
 */
export interface ViewStateListener {
  onStateChange?: (oldState: ViewStateType, newState: ViewStateType) => void;
  onShow?: () => void;
  onHide?: () => void;
}

/**
 * 日宫格视图控制器
 */
@Observed
export class HybridDayGridVc {
  private readonly tag: string = 'HybridDayGridVc';

  // ========== 视图状态 ==========
  @Track public isCanShow: boolean = true;
  @Track public isShow: boolean = false;
  @Track public isSelectMode: boolean = false;
  @Track public isMinimalism: boolean = false;
  @Track public isRefreshGrid: boolean = true;

  // ========== Pinch 状态 ==========
  @Track public pinchActive: boolean = false;
  @Track public pinchPreviewMode: boolean = false;
  @Track public pinchProgress: number = 0;
  @Track public pinchLiveScale: number = 1;
  @Track public pinchFromColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @Track public pinchToColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @Track public pinchCenterX: number = 0;
  @Track public pinchCenterY: number = 0;

  // ========== Grid 配置 ==========
  @Track public gridColumns: number = Shared.HYBRID_GRID_COLUMNS;
  @Track public columnsTemplate: string = '1fr 1fr 1fr 1fr';
  @Track public gridScale: number = 1;

  // ========== 属性更新器 ==========
  public readonly attributeUpdater: HybridGridAttributeUpdater;
  public readonly targetAttributeUpdater: HybridGridAttributeUpdater;

  // ========== ViewModel ==========
  private viewModel?: HybridDayGridVm;

  // ========== 视图状态 ==========
  private viewState: ViewStateType = ViewStateType.INIT;
  private viewStateListeners: Array<ViewStateListener> = [];

  // ========== 滚动器 ==========
  private scroller?: Scroller;
  private targetScroller?: Scroller;

  // ========== 数据监听器 ==========
  private readonly dataLoadListener: DataLoadListener = {
    onDataLoaded: (items: Array<HybridTimelineItem>, hasMore: boolean): void => {
      this.isRefreshGrid = !this.isRefreshGrid; // 触发刷新
    },
    onDataLoadError: (error: string): void => {
      console.error(`[${this.tag}] Data load error: ${error}`);
    },
    onDataLoading: (isLoading: boolean): void => {
      // 可以在这里显示加载指示器
    },
  };

  private readonly scrollStateListener: ScrollStateListener = {
    onScrollStart: (): void => {
      this.updateMinimalismState(true, true);
    },
    onScrollStop: (): void => {
      this.updateMinimalismState(false, false);
    },
    onScrollIndex: (firstIndex: number, lastIndex: number): void => {
      // 可以在这里更新浮动标题等
    },
  };

  private readonly pinchGestureListener: PinchGestureListener = {
    onPinchStart: (centerX: number, centerY: number): void => {
      this.pinchActive = true;
      this.pinchPreviewMode = true;
      this.pinchCenterX = centerX;
      this.pinchCenterY = centerY;
      this.pinchProgress = 0;
      this.pinchLiveScale = 1;
      this.gridScale = 1;
    },
    onPinchUpdate: (scale: number, centerX: number, centerY: number): void => {
      this.pinchCenterX = centerX;
      this.pinchCenterY = centerY;
      this.pinchLiveScale = scale;
      this.gridScale = scale;

      this.attributeUpdater.updateScale({
        x: scale,
        y: scale,
        centerX: centerX,
        centerY: centerY,
      });
    },
    onPinchEnd: (): void => {
      // 动画结束后重置状态
    },
  };

  public constructor(attributeUpdater?: HybridGridAttributeUpdater, targetAttributeUpdater?: HybridGridAttributeUpdater) {
    this.attributeUpdater = attributeUpdater ?? new HybridGridAttributeUpdater();
    this.targetAttributeUpdater = targetAttributeUpdater ?? new HybridGridAttributeUpdater();
  }

  // ========== 初始化 ==========

  /**
   * 初始化控制器
   */
  public init(viewModel: HybridDayGridVm, scroller: Scroller, targetScroller: Scroller): void {
    this.viewModel = viewModel;
    this.scroller = scroller;
    this.targetScroller = targetScroller;

    // 注册监听器
    this.viewModel.addDataLoadListener(this.dataLoadListener);
    this.viewModel.addScrollStateListener(this.scrollStateListener);
    this.viewModel.addPinchGestureListener(this.pinchGestureListener);

    // 初始化状态
    this.initStates();
    this.initObservers();

    console.log(`[${this.tag}] Initialized`);
  }

  /**
   * 初始化状态
   */
  private initStates(): void {
    this.isCanShow = true;
    this.isShow = true;
    this.isSelectMode = false;
    this.isMinimalism = false;
    this.pinchActive = false;
    this.pinchPreviewMode = false;
    this.pinchProgress = 0;
    this.pinchLiveScale = 1;
    this.gridScale = 1;
    this.gridColumns = this.viewModel?.getGridColumns() ?? Shared.HYBRID_GRID_COLUMNS;
    this.updateColumnsTemplate();
  }

  /**
   * 初始化观察者
   */
  private initObservers(): void {
    if (!this.viewModel) {
      return;
    }

    // 监听状态机状态变化
    this.viewModel.getFormFsm().registerObserver({
      onStateChange: (oldState: FormStateType, newState: FormStateType, event: number): void => {
        this.onFormStateChange(oldState, newState);
      }
    });
  }

  /**
   * 形态状态变化处理
   */
  private onFormStateChange(oldState: FormStateType, newState: FormStateType): void {
    console.log(`[${this.tag}] Form state change: ${FormStateType[oldState]} -> ${FormStateType[newState]}`);

    // 更新可见性
    if (FormStateTypeUtils.isInFollowHandState(newState)) {
      // 跟手态，显示预览
      this.pinchPreviewMode = true;
    } else {
      // 非跟手态，隐藏预览
      this.pinchPreviewMode = false;
    }

    // 更新当前形态
    const currentForm = FormStateTypeUtils.getFormFromStateType(newState);
    this.updateGridColumnsByForm(currentForm);
  }

  // ========== 视图状态管理 ==========

  /**
   * 更新可见性
   */
  public updateShowState(isShow: boolean, reason?: string): void {
    if (this.isShow === isShow) {
      return;
    }
    this.isShow = isShow;
    this.attributeUpdater.updateVisibility(isShow ? Visibility.Visible : Visibility.Hidden);
    console.log(`[${this.tag}] updateShowState: ${isShow}, reason: ${reason}`);

    // 通知监听器
    if (isShow) {
      this.viewStateListeners.forEach(listener => listener.onShow?.());
    } else {
      this.viewStateListeners.forEach(listener => listener.onHide?.());
    }
  }

  /**
   * 更新能否可见
   */
  public updateCanShowState(isCanShow: boolean): void {
    if (this.isCanShow === isCanShow) {
      return;
    }
    this.isCanShow = isCanShow;
    console.log(`[${this.tag}] updateCanShowState: ${isCanShow}`);
  }

  /**
   * 更新极简模式
   */
  private updateMinimalismState(isScrolling: boolean, isTouched: boolean): void {
    if (isTouched && isScrolling && !this.isSelectMode) {
      this.isMinimalism = true;
    } else {
      this.isMinimalism = false;
    }
    console.log(`[${this.tag}] updateMinimalismState: ${this.isMinimalism}`);
  }

  // ========== Grid 配置管理 ==========

  /**
   * 更新列数
   */
  public updateGridColumns(columns: number): void {
    const clampedColumns = Math.max(Shared.HYBRID_GRID_MIN_COLUMNS, Math.min(Shared.HYBRID_GRID_MAX_COLUMNS, columns));
    if (clampedColumns === this.gridColumns) {
      return;
    }

    console.log(`[${this.tag}] updateGridColumns: ${this.gridColumns} -> ${clampedColumns}`);
    this.gridColumns = clampedColumns;
    this.viewModel?.setGridColumns(clampedColumns);
    this.updateColumnsTemplate();
  }

  /**
   * 根据形态更新列数
   */
  private updateGridColumnsByForm(form: FormIndex): void {
    let columns = this.gridColumns;
    switch (form) {
      case FormIndex.YEAR:
        columns = 16;
        break;
      case FormIndex.MONTH:
        columns = 8;
        break;
      case FormIndex.DAY:
        columns = 4;
        break;
      case FormIndex.GROUP_DAY:
        columns = 3;
        break;
    }
    this.updateGridColumns(columns);
  }

  /**
   * 更新 columnsTemplate
   */
  private updateColumnsTemplate(): void {
    this.columnsTemplate = '1fr '.repeat(this.gridColumns).trim();
  }

  // ========== Pinch 动画管理 ==========

  /**
   * 开始 Pinch 动画
   */
  public startPinchAnimation(centerX: number, centerY: number): void {
    this.pinchActive = true;
    this.pinchPreviewMode = true;
    this.pinchFromColumns = this.gridColumns;
    this.pinchToColumns = Math.min(Shared.HYBRID_GRID_MAX_COLUMNS, this.gridColumns * 2);
    this.pinchCenterX = centerX;
    this.pinchCenterY = centerY;
    this.pinchProgress = 0;
    this.pinchLiveScale = 1;
    this.gridScale = 1;

    this.viewModel?.handlePinchStart(centerX, centerY);
  }

  /**
   * 更新 Pinch 动画
   */
  public updatePinchAnimation(scale: number, centerX: number, centerY: number): void {
    const clampedScale = Math.max(0.5, Math.min(2.0, scale));
    this.pinchCenterX = centerX;
    this.pinchCenterY = centerY;
    this.pinchLiveScale = clampedScale;
    this.gridScale = clampedScale;

    this.attributeUpdater.updateScale({
      x: clampedScale,
      y: clampedScale,
      centerX: centerX,
      centerY: centerY,
    });

    // 计算目标列数
    let nextColumns = this.pinchFromColumns;
    if (clampedScale < 0.98) {
      nextColumns = Math.min(Shared.HYBRID_GRID_MAX_COLUMNS, this.pinchFromColumns * 2);
    } else if (clampedScale > 1.02) {
      nextColumns = Math.max(Shared.HYBRID_GRID_MIN_COLUMNS, Math.floor(this.pinchFromColumns / 2));
    }

    if (nextColumns !== this.pinchToColumns) {
      this.pinchToColumns = nextColumns;
    }

    // 计算进度
    const delta = Math.abs(clampedScale - 1);
    let progress = Math.max(0, Math.min(1, delta / 0.35));
    if (nextColumns !== this.gridColumns) {
      progress = Math.max(progress, 0.12);
    }
    this.pinchProgress = progress;

    this.viewModel?.handlePinchUpdate(scale, centerX, centerY);
  }

  /**
   * 结束 Pinch 动画
   */
  public endPinchAnimation(): void {
    const shouldApplyColumns = this.pinchToColumns !== this.gridColumns;

    this.viewModel?.handlePinchEnd();

    if (shouldApplyColumns) {
      this.updateGridColumns(this.pinchToColumns);
    }

    // 执行动画
    const uiContext = AppStorage.get<UIContext>('uiContext');
    if (uiContext) {
      uiContext.animateTo(
        {
          duration: shouldApplyColumns ? 200 : 160,
          curve: shouldApplyColumns ? Curve.FastOutSlowIn : Curve.EaseOut,
        },
        (): void => {
          this.pinchProgress = shouldApplyColumns ? 1 : 0;
          this.pinchLiveScale = 1;
          this.gridScale = 1;
          this.attributeUpdater.updateScale({ x: 1, y: 1 });
          this.attributeUpdater.updateSize('100%', '100%');
        },
      );
    } else {
      // 没有 UIContext，直接更新
      this.pinchProgress = shouldApplyColumns ? 1 : 0;
      this.pinchLiveScale = 1;
      this.gridScale = 1;
      this.attributeUpdater.updateScale({ x: 1, y: 1 });
      this.attributeUpdater.updateSize('100%', '100%');
    }

    // 重置状态
    setTimeout((): void => {
      this.pinchActive = false;
      this.pinchPreviewMode = false;
      this.pinchProgress = 0;
      this.pinchFromColumns = this.gridColumns;
      this.pinchToColumns = this.gridColumns;
    }, shouldApplyColumns ? 210 : 170);
  }

  // ========== 滚动管理 ==========

  /**
   * 获取当前滚动偏移
   */
  public getCurrentScrollOffset(): number {
    if (!this.scroller) {
      return 0;
    }
    try {
      return Math.max(0, this.scroller.currentOffset().yOffset);
    } catch (_) {
      return 0;
    }
  }

  /**
   * 滚动到指定位置
   */
  public scrollTo(offset: number): void {
    if (!this.scroller) {
      return;
    }
    try {
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: Math.max(0, offset),
      });
    } catch (_) {}
  }

  /**
   * 滚动到边缘
   */
  public scrollEdge(edge: Edge): void {
    if (!this.scroller) {
      return;
    }
    try {
      this.scroller.scrollEdge(edge);
    } catch (_) {}
  }

  // ========== 监听器管理 ==========

  public addViewStateListener(listener: ViewStateListener): void {
    this.viewStateListeners.push(listener);
  }

  public removeViewStateListener(listener: ViewStateListener): void {
    this.viewStateListeners = this.viewStateListeners.filter(l => l !== listener);
  }

  // ========== Getter ==========

  public getViewModel(): HybridDayGridVm | undefined {
    return this.viewModel;
  }

  public getScroller(): Scroller | undefined {
    return this.scroller;
  }

  public getTargetScroller(): Scroller | undefined {
    return this.targetScroller;
  }

  public getViewState(): ViewStateType {
    return this.viewState;
  }

  public isInShowState(): boolean {
    return this.isCanShow && this.isShow;
  }

  // ========== 释放资源 ==========

  public release(): void {
    if (this.viewModel) {
      this.viewModel.removeDataLoadListener(this.dataLoadListener);
      this.viewModel.removeScrollStateListener(this.scrollStateListener);
      this.viewModel.removePinchGestureListener(this.pinchGestureListener);
    }
    this.viewStateListeners = [];
    console.log(`[${this.tag}] Released`);
  }
}
