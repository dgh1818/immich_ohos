import common from '@ohos.app.ability.common';
import * as Shared from '../PhotoGridShared';
import { GridSnapshotController } from '../viewcontroller/GridSnapshotController';
import { GridTitleBarMaskController } from '../viewcontroller/GridTitleBarMaskController';
import { PhotoGridViewController, PhotoGridViewId, PhotoGridZIndex } from '../viewcontroller/PhotoGridViewController';
import { PhotoGridViewModel } from '../viewmodel/PhotoGridViewModel';
import { FixedIrregularView } from './FixedIrregularView';
import { FloatingSectionOverlayView } from './FloatingSectionOverlayView';
import { GridNoDataView } from './GridNoDataView';
import { GridTitleBarMaskView } from './GridTitleBarMaskView';
import { YearGridView } from './YearGridView';
import { MonthGridView } from './MonthGridView';
import { DayGridView } from './DayGridView';
import { GroupGridView } from './GroupGridView';
import { GridSnapshotView } from './common/GridSnapshotView';
import { FormIndex } from '../statemanager/constants/GridDefine';

@Component
export struct TimelineView {
  private readonly context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  @Prop topInset: number = 56;

  @State private renderTick: number = 0;
  @State private viewController: PhotoGridViewController = new PhotoGridViewController();
  @State private snapshotController: GridSnapshotController = new GridSnapshotController();
  @State private titleBarMaskController: GridTitleBarMaskController = new GridTitleBarMaskController();
  private readonly viewModel: PhotoGridViewModel = new PhotoGridViewModel(this.context);
  private readonly stateListener: () => void = (): void => {
    this.renderTick += 1;
  };

  aboutToAppear(): void {
    this.viewController.updateTopInset(this.topInset);
    this.titleBarMaskController.updateTopInset(this.topInset);
    this.viewModel.updateTopInset(this.topInset);
    this.viewModel.bindSnapshotController(this.snapshotController);
    this.viewModel.addStateListener(this.stateListener);
    void this.viewModel.init();
  }

  aboutToDisappear(): void {
    this.viewModel.removeStateListener(this.stateListener);
    this.viewModel.release();
  }

  @Builder
  private buildLoadingView() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(28)
        .height(28)
        .color(0xFF111827);

      Text('Loading photos...')
        .fontSize(14)
        .fontColor(0xFF475569);
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E0E0E0')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private buildErrorView() {
    Column({ space: 10 }) {
      Text('ArkUI photo grid is unavailable')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(0xFF111827);

      Text(this.viewModel.errorText)
        .fontSize(12)
        .fontColor(0xFF64748B)
        .margin({ left: 24, right: 24 })
        .textAlign(TextAlign.Center);

      Button('Retry')
        .margin({ top: 4 })
        .onClick((): void => {
          void this.viewModel.reload();
        });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E0E0E0')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private buildGridLayers() {
    Stack({ alignContent: Alignment.TopStart }) {
      YearGridView({
        visible: this.viewModel.yearGridState.visible,
        interactive: this.viewModel.yearGridState.interactive,
        warmActive: this.viewModel.yearGridState.warmActive,
        columns: this.viewModel.yearGridState.columns,
        layoutOptions: this.viewModel.resolveGridLayoutOptions(FormIndex.YEAR),
        headSpacerHeight: this.viewModel.resolveHeadSpacerHeight(FormIndex.YEAR),
        tailSpacerHeight: this.viewModel.resolveTailSpacerHeight(FormIndex.YEAR),
        gap: this.viewModel.resolveGridGap(FormIndex.YEAR),
        tailFillPositions: this.viewModel.resolveTailFillPositions(FormIndex.YEAR),
        cacheRows: this.viewModel.yearGridState.cacheRows,
        requestSize: this.viewModel.resolveRequestSize(FormIndex.YEAR),
        touchScrollEnd: this.viewModel.activeForm === FormIndex.YEAR ? this.viewModel.touchScrollEnd : true,
        opacityValue: this.viewModel.yearGridState.opacityValue,
        attributeUpdater: this.viewModel.yearGridState.attributeUpdater,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScroller(FormIndex.YEAR, scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.GridDataSource): void => {
          this.viewModel.bindDataSource(FormIndex.YEAR, dataSource);
        },
        assetTapHandler: (_asset: Shared.PhotoAsset): void => {
          this.viewModel.handleSingleTapEvent(FormIndex.YEAR);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onFormScrollStart(FormIndex.YEAR);
        },
        scrollStopHandler: (): void => {
          this.viewModel.onFormScrollStop(FormIndex.YEAR);
        },
        touchStateHandler: (touching: boolean): void => {
          this.viewModel.onFormTouchState(FormIndex.YEAR, touching);
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onFormScrollIndex(FormIndex.YEAR, start, end);
        },
        didScrollHandler: (offset: number, state: number): void => {
          this.viewModel.onFormDidScroll(FormIndex.YEAR, offset, state);
        },
        reachStartHandler: (): void => {
          this.viewModel.onFormReachStart(FormIndex.YEAR);
        },
        reachEndHandler: (): void => {
          this.viewModel.onFormReachEnd(FormIndex.YEAR);
        },
        willScrollHandler: (offset: number, state: number, source: number): void => {
          this.viewModel.onFormWillScroll(FormIndex.YEAR, offset, state, source);
        },
        pinchStartHandler: (centerX: number, centerY: number): void => {
          this.viewModel.onPinchStart(centerX, centerY);
        },
        pinchUpdateHandler: (scale: number, centerX: number, centerY: number): void => {
          this.viewModel.onPinchUpdate(scale, centerX, centerY);
        },
        pinchEndHandler: (): void => {
          this.viewModel.onPinchEnd();
        },
      });

      MonthGridView({
        interactive: this.viewModel.monthGridState.interactive,
        warmActive: this.viewModel.monthGridState.warmActive,
        columns: this.viewModel.monthGridState.columns,
        layoutOptions: this.viewModel.resolveGridLayoutOptions(FormIndex.MONTH),
        headSpacerHeight: this.viewModel.resolveHeadSpacerHeight(FormIndex.MONTH),
        tailSpacerHeight: this.viewModel.resolveTailSpacerHeight(FormIndex.MONTH),
        gap: this.viewModel.resolveGridGap(FormIndex.MONTH),
        tailFillPositions: this.viewModel.resolveTailFillPositions(FormIndex.MONTH),
        cacheRows: this.viewModel.monthGridState.cacheRows,
        requestSize: this.viewModel.resolveRequestSize(FormIndex.MONTH),
        touchScrollEnd: this.viewModel.activeForm === FormIndex.MONTH ? this.viewModel.touchScrollEnd : true,
        opacityValue: this.viewModel.monthGridState.opacityValue,
        attributeUpdater: this.viewModel.monthGridState.attributeUpdater,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScroller(FormIndex.MONTH, scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.GridDataSource): void => {
          this.viewModel.bindDataSource(FormIndex.MONTH, dataSource);
        },
        assetTapHandler: (_asset: Shared.PhotoAsset): void => {
          this.viewModel.handleSingleTapEvent(FormIndex.MONTH);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onFormScrollStart(FormIndex.MONTH);
        },
        scrollStopHandler: (): void => {
          this.viewModel.onFormScrollStop(FormIndex.MONTH);
        },
        touchStateHandler: (touching: boolean): void => {
          this.viewModel.onFormTouchState(FormIndex.MONTH, touching);
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onFormScrollIndex(FormIndex.MONTH, start, end);
        },
        didScrollHandler: (offset: number, state: number): void => {
          this.viewModel.onFormDidScroll(FormIndex.MONTH, offset, state);
        },
        reachStartHandler: (): void => {
          this.viewModel.onFormReachStart(FormIndex.MONTH);
        },
        reachEndHandler: (): void => {
          this.viewModel.onFormReachEnd(FormIndex.MONTH);
        },
        willScrollHandler: (offset: number, state: number, source: number): void => {
          this.viewModel.onFormWillScroll(FormIndex.MONTH, offset, state, source);
        },
        pinchStartHandler: (centerX: number, centerY: number): void => {
          this.viewModel.onPinchStart(centerX, centerY);
        },
        pinchUpdateHandler: (scale: number, centerX: number, centerY: number): void => {
          this.viewModel.onPinchUpdate(scale, centerX, centerY);
        },
        pinchEndHandler: (): void => {
          this.viewModel.onPinchEnd();
        },
      });

      DayGridView({
        visible: this.viewModel.dayGridState.visible,
        interactive: this.viewModel.dayGridState.interactive,
        warmActive: this.viewModel.dayGridState.warmActive,
        columns: this.viewModel.dayGridState.columns,
        layoutOptions: this.viewModel.resolveGridLayoutOptions(FormIndex.DAY),
        headSpacerHeight: this.viewModel.resolveHeadSpacerHeight(FormIndex.DAY),
        tailSpacerHeight: this.viewModel.resolveTailSpacerHeight(FormIndex.DAY),
        gap: this.viewModel.resolveGridGap(FormIndex.DAY),
        tailFillPositions: this.viewModel.resolveTailFillPositions(FormIndex.DAY),
        cacheRows: this.viewModel.dayGridState.cacheRows,
        requestSize: this.viewModel.resolveRequestSize(FormIndex.DAY),
        touchScrollEnd: this.viewModel.activeForm === FormIndex.DAY ? this.viewModel.touchScrollEnd : true,
        opacityValue: this.viewModel.dayGridState.opacityValue,
        attributeUpdater: this.viewModel.dayGridState.attributeUpdater,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScroller(FormIndex.DAY, scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.GridDataSource): void => {
          this.viewModel.bindDataSource(FormIndex.DAY, dataSource);
        },
        assetTapHandler: (asset: Shared.PhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onFormScrollStart(FormIndex.DAY);
        },
        scrollStopHandler: (): void => {
          this.viewModel.onFormScrollStop(FormIndex.DAY);
        },
        touchStateHandler: (touching: boolean): void => {
          this.viewModel.onFormTouchState(FormIndex.DAY, touching);
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onFormScrollIndex(FormIndex.DAY, start, end);
        },
        didScrollHandler: (offset: number, state: number): void => {
          this.viewModel.onFormDidScroll(FormIndex.DAY, offset, state);
        },
        reachStartHandler: (): void => {
          this.viewModel.onFormReachStart(FormIndex.DAY);
        },
        reachEndHandler: (): void => {
          this.viewModel.onFormReachEnd(FormIndex.DAY);
        },
        willScrollHandler: (offset: number, state: number, source: number): void => {
          this.viewModel.onFormWillScroll(FormIndex.DAY, offset, state, source);
        },
        pinchStartHandler: (centerX: number, centerY: number): void => {
          this.viewModel.onPinchStart(centerX, centerY);
        },
        pinchUpdateHandler: (scale: number, centerX: number, centerY: number): void => {
          this.viewModel.onPinchUpdate(scale, centerX, centerY);
        },
        pinchEndHandler: (): void => {
          this.viewModel.onPinchEnd();
        },
      });

      GroupGridView({
        visible: this.viewModel.groupDayGridState.visible,
        interactive: this.viewModel.groupDayGridState.interactive,
        warmActive: this.viewModel.groupDayGridState.warmActive,
        columns: this.viewModel.groupDayGridState.columns,
        layoutOptions: this.viewModel.resolveGridLayoutOptions(FormIndex.GROUP_DAY),
        headSpacerHeight: this.viewModel.resolveHeadSpacerHeight(FormIndex.GROUP_DAY),
        tailSpacerHeight: this.viewModel.resolveTailSpacerHeight(FormIndex.GROUP_DAY),
        gap: this.viewModel.resolveGridGap(FormIndex.GROUP_DAY),
        tailFillPositions: this.viewModel.resolveTailFillPositions(FormIndex.GROUP_DAY),
        cacheRows: this.viewModel.groupDayGridState.cacheRows,
        requestSize: this.viewModel.resolveRequestSize(FormIndex.GROUP_DAY),
        touchScrollEnd: this.viewModel.activeForm === FormIndex.GROUP_DAY ? this.viewModel.touchScrollEnd : true,
        opacityValue: this.viewModel.groupDayGridState.opacityValue,
        attributeUpdater: this.viewModel.groupDayGridState.attributeUpdater,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScroller(FormIndex.GROUP_DAY, scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.GridDataSource): void => {
          this.viewModel.bindDataSource(FormIndex.GROUP_DAY, dataSource);
        },
        assetTapHandler: (asset: Shared.PhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onFormScrollStart(FormIndex.GROUP_DAY);
        },
        scrollStopHandler: (): void => {
          this.viewModel.onFormScrollStop(FormIndex.GROUP_DAY);
        },
        touchStateHandler: (touching: boolean): void => {
          this.viewModel.onFormTouchState(FormIndex.GROUP_DAY, touching);
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onFormScrollIndex(FormIndex.GROUP_DAY, start, end);
        },
        didScrollHandler: (offset: number, state: number): void => {
          this.viewModel.onFormDidScroll(FormIndex.GROUP_DAY, offset, state);
        },
        reachStartHandler: (): void => {
          this.viewModel.onFormReachStart(FormIndex.GROUP_DAY);
        },
        reachEndHandler: (): void => {
          this.viewModel.onFormReachEnd(FormIndex.GROUP_DAY);
        },
        willScrollHandler: (offset: number, state: number, source: number): void => {
          this.viewModel.onFormWillScroll(FormIndex.GROUP_DAY, offset, state, source);
        },
        pinchStartHandler: (centerX: number, centerY: number): void => {
          this.viewModel.onPinchStart(centerX, centerY);
        },
        pinchUpdateHandler: (scale: number, centerX: number, centerY: number): void => {
          this.viewModel.onPinchUpdate(scale, centerX, centerY);
        },
        pinchEndHandler: (): void => {
          this.viewModel.onPinchEnd();
        },
      });

      GridSnapshotView({
        snapshotImage: this.snapshotController.snapshotImage,
        visible: this.snapshotController.isVisible,
        opacityValue: this.snapshotController.snapshotOpacity,
        offsetY: this.snapshotController.snapshotOffsetY,
      });
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor('#E0E0E0')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .alignRules({
      top: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Top },
      bottom: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Bottom },
      start: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.Start },
      end: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.End },
    });
  }

  @Builder
  private buildGrid() {
    RelativeContainer() {
      if (this.viewController.isIrregularViewInit) {
        FloatingSectionOverlayView({
          topInset: this.topInset,
          addStateListenerHandler: (listener: () => void): void => {
            this.viewModel.addStateListener(listener);
          },
          removeStateListenerHandler: (listener: () => void): void => {
            this.viewModel.removeStateListener(listener);
          },
          resolveTitleHandler: (): string => this.viewModel.floatingSectionTitle,
          resolveCountHandler: (): number => this.viewModel.floatingSectionCount,
        });
      }

      if (this.viewController.isFixedIrregularViewInit) {
        FixedIrregularView({
          areaChangeHandler: (_width: number, height: number): void => {
            this.viewModel.updateGridHeadSpacerHeight(height);
          },
        });
      }

      if (this.viewController.isNoDataViewInit) {
        GridNoDataView({
          visible: this.viewModel.isNoDataVisible(),
        });
      }

      if (this.viewController.isPhotoGridInit) {
        this.buildGridLayers();
      }

      this.buildBottomSafeAreaMask();

      if (this.viewController.isTitleBarMaskInit) {
        GridTitleBarMaskView({
          maskHeight: this.titleBarMaskController.height,
          opacityValue: this.titleBarMaskController.opacityValue,
        });
      }
    }
    .id(PhotoGridViewId.CONTAINER)
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor('#E0E0E0')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.renderTick >= 0 && this.viewModel.shouldShowInitialLoading()) {
        this.buildLoadingView();
      } else if (this.viewModel.shouldShowInitialError()) {
        this.buildErrorView();
      } else {
        this.buildGrid();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#E0E0E0')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
  }

  @Builder
  private buildBottomSafeAreaMask() {
    if (this.viewModel.bottomAvoidHeight > 0) {
      Column() {}
        .width('100%')
        .height(this.viewModel.bottomAvoidHeight + 18)
        .zIndex(PhotoGridZIndex.GRID_SNAPSHOT + 1)
        .alignRules({
          bottom: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Bottom },
          start: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.Start },
          end: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.End },
        })
        .linearGradient({
          angle: 0,
          colors: [
            [0x0010141A, 0],
            [0x4A10141A, 0.32],
            [0xC610141A, 0.78],
            [0xF010141A, 1],
          ],
        })
        .hitTestBehavior(HitTestMode.None);
    }
  }
}
