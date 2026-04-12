import common from '@ohos.app.ability.common';
import { HybridPhotoGridVm } from '../viewmodel/HybridPhotoGridVm';
import * as Shared from '../HybridPhotoGridShared';
import { HybridGridKind, HybridPhotoGridVc } from '../viewcontroller/HybridPhotoGridVc';
import { HybridGridSnapshotVc } from '../viewcontroller/HybridGridSnapshotVc';
import { HybridGridTitleBarMaskVc } from '../viewcontroller/HybridGridTitleBarMaskVc';
import { HybridDayGridA } from './DayGridView';
import { HybridDayGridB } from './DayPreviewGridView';
import { HybridDayGridC } from './DayGridC';
import { HybridGridSnapshotView } from './common/GridSnapshotView';
import { HybridGridNoDataView } from './GridNoDataView';
import { HybridGridTitleBarMaskView } from './GridTitleBarMaskView';
import { HybridIrregularView } from './IrregularView';
import { HybridFixedIrregularView } from './FixedIrregularView';

@Component
export struct HybridPhotoGridView {
  private readonly context = getContext(this) as common.UIAbilityContext;
  @Prop topInset: number = 56;

  @State private renderTick: number = 0;
  @State private viewController: HybridPhotoGridVc = new HybridPhotoGridVc();
  @State private snapshotController: HybridGridSnapshotVc = new HybridGridSnapshotVc();
  @State private titleBarMaskController: HybridGridTitleBarMaskVc = new HybridGridTitleBarMaskVc();
  @State private viewModel: HybridPhotoGridVm = new HybridPhotoGridVm(this.context);
  private readonly stateListener: () => void = (): void => {
    const nextRenderTick = this.renderTick + 1;
    this.renderTick = nextRenderTick;
    console.info(
      `[HybridPhotoGridView] state tick=${nextRenderTick}, firstLoad=${this.viewModel.hasCompletedFirstLoad ? 1 : 0}, loading=${this.viewModel.isLoading ? 1 : 0}, itemCount=${this.viewModel.itemCount}, error=${this.viewModel.errorText ? 1 : 0}`,
    );
  };

  aboutToAppear(): void {
    this.viewController.updateTopInset(this.topInset);
    this.titleBarMaskController.updateTopInset(this.topInset);
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
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private buildBottomHelperView() {
  }

  @Builder
  private buildDayView() {
    Stack({ alignContent: Alignment.TopStart }) {
      HybridDayGridA({
        columns: this.viewModel.gridColumnsA,
        cacheRows: this.viewModel.gridCacheRowsA,
        visible: this.viewModel.gridVisibleA,
        interactive: this.viewModel.gridInteractiveA,
        warmActive: this.viewModel.gridWarmActiveA,
        hasMore: this.viewModel.hasMore,
        requestSize: this.viewModel.resolveRequestSizeForKind(HybridGridKind.A),
        scaleValue: this.viewModel.gridScaleA,
        opacityValue: this.viewModel.gridOpacityA,
        centerX: this.viewModel.pinchCenterX,
        centerY: this.viewModel.pinchCenterY,
        zIndexValue: this.viewModel.gridZIndexA,
        attributeUpdater: this.viewModel.gridAttributeUpdaterA,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScrollerA(scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource): void => {
          this.viewModel.bindDataSourceA(dataSource);
        },
        assetTapHandler: (asset: Shared.HybridPhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onScrollStart();
        },
        scrollStopHandler: (): void => {
          this.viewModel.onScrollStop();
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onScrollIndex(start, end);
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

      HybridDayGridB({
        columns: this.viewModel.gridColumnsB,
        cacheRows: this.viewModel.gridCacheRowsB,
        visible: this.viewModel.gridVisibleB,
        interactive: this.viewModel.gridInteractiveB,
        warmActive: this.viewModel.gridWarmActiveB,
        hasMore: this.viewModel.hasMore,
        requestSize: this.viewModel.resolveRequestSizeForKind(HybridGridKind.B),
        scaleValue: this.viewModel.gridScaleB,
        opacityValue: this.viewModel.gridOpacityB,
        centerX: this.viewModel.pinchCenterX,
        centerY: this.viewModel.pinchCenterY,
        zIndexValue: this.viewModel.gridZIndexB,
        attributeUpdater: this.viewModel.gridAttributeUpdaterB,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScrollerB(scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource): void => {
          this.viewModel.bindDataSourceB(dataSource);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        assetTapHandler: (asset: Shared.HybridPhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onPreviewScrollStart();
        },
        scrollStopHandler: (): void => {
          this.viewModel.onPreviewScrollStop();
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onPreviewScrollIndex(start, end);
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

      HybridDayGridC({
        columns: this.viewModel.gridColumnsC,
        cacheRows: this.viewModel.gridCacheRowsC,
        visible: this.viewModel.gridVisibleC,
        interactive: this.viewModel.gridInteractiveC,
        warmActive: this.viewModel.gridWarmActiveC,
        hasMore: this.viewModel.hasMore,
        requestSize: this.viewModel.resolveRequestSizeForKind(HybridGridKind.C),
        scaleValue: this.viewModel.gridScaleC,
        opacityValue: this.viewModel.gridOpacityC,
        centerX: this.viewModel.pinchCenterX,
        centerY: this.viewModel.pinchCenterY,
        zIndexValue: this.viewModel.gridZIndexC,
        attributeUpdater: this.viewModel.gridAttributeUpdaterC,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindScrollerC(scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource): void => {
          this.viewModel.bindDataSourceC(dataSource);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onGridAreaChange(width, height);
        },
        assetTapHandler: (asset: Shared.HybridPhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
        scrollStartHandler: (): void => {
          this.viewModel.onScrollStart();
        },
        scrollStopHandler: (): void => {
          this.viewModel.onScrollStop();
        },
        scrollIndexHandler: (start: number, end: number): void => {
          this.viewModel.onScrollIndex(start, end);
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

      HybridGridSnapshotView({
        snapshotImage: this.snapshotController.snapshotImage,
        visible: this.snapshotController.isVisible,
      });
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor(Color.Transparent)
    .alignRules({
      top: { anchor: '__container__', align: VerticalAlign.Top },
      bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
      start: { anchor: '__container__', align: HorizontalAlign.Start },
      end: { anchor: '__container__', align: HorizontalAlign.End },
    });
  }

  @Builder
  private buildGrid() {
    RelativeContainer() {
      if (this.viewController.isIrregularViewInit) {
        HybridIrregularView({
          title: this.viewModel.floatingSectionTitle,
          count: this.viewModel.floatingSectionCount,
          topInset: this.topInset,
        });
      }

      if (this.viewController.isFixedIrregularViewInit) {
        HybridFixedIrregularView();
      }

      if (this.viewController.isNoDataViewInit) {
        HybridGridNoDataView({
          visible: this.viewModel.isNoDataVisible(),
        });
      }

      if (this.viewController.isDayViewInit) {
        this.buildDayView();
      }

      if (this.viewController.isTitleBarMaskInit) {
        HybridGridTitleBarMaskView({
          maskHeight: this.titleBarMaskController.height,
          opacityValue: this.titleBarMaskController.opacityValue,
        });
      }

      this.buildBottomHelperView();
    }
    .id('__container__')
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor(Color.Transparent);
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
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]);
  }
}
