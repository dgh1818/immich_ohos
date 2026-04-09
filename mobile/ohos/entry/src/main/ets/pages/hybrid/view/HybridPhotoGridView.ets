import common from '@ohos.app.ability.common';
import { HybridPhotoGridVm } from '../viewmodel/HybridPhotoGridVm';
import * as Shared from '../HybridPhotoGridShared';
import { HybridPhotoGridVc } from '../viewcontroller/HybridPhotoGridVc';
import { HybridGridSnapshotVc } from '../viewcontroller/HybridGridSnapshotVc';
import { HybridGridTitleBarMaskVc } from '../viewcontroller/HybridGridTitleBarMaskVc';
import { HybridDayGridView } from './DayGridView';
import { HybridDayPreviewGridView } from './DayPreviewGridView';
import { HybridIdleShrinkGridView } from './DayIdleShrinkGridView';
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
      HybridIdleShrinkGridView({
        columns: this.viewModel.idlePreviewColumns,
        visible: this.viewModel.previewVisible && this.viewModel.useIdlePrebuiltPreview,
        warmActive: this.viewModel.idlePreviewWarmActive,
        requestSize: this.viewModel.resolveIdlePreviewRequestSize(),
        opacityValue: this.viewModel.previewOpacity,
        scaleValue: this.viewModel.previewScale,
        centerX: this.viewModel.pinchCenterX,
        centerY: this.viewModel.pinchCenterY,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindIdlePreviewScroller(scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource): void => {
          this.viewModel.bindIdlePreviewGridDataSource(dataSource);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onIdlePreviewAreaChange(width, height);
        },
        assetTapHandler: (asset: Shared.HybridPhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
      });

      HybridDayPreviewGridView({
        columns: this.viewModel.previewColumns,
        visible: this.viewModel.previewVisible && !this.viewModel.useIdlePrebuiltPreview,
        interactive: this.viewModel.isPreviewLayerInteractive(),
        warmActive: this.viewModel.previewWarmActive,
        requestSize: this.viewModel.resolvePreviewRequestSize(),
        opacityValue: this.viewModel.previewOpacity,
        scaleValue: this.viewModel.previewScale,
        translateX: this.viewModel.previewTranslateX,
        translateY: this.viewModel.previewTranslateY,
        centerX: this.viewModel.pinchCenterX,
        centerY: this.viewModel.pinchCenterY,
        hasMore: this.viewModel.hasMore,
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindPreviewScroller(scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource): void => {
          this.viewModel.bindPreviewGridDataSource(dataSource);
        },
        areaChangeHandler: (width: number, height: number): void => {
          this.viewModel.onPreviewAreaChange(width, height);
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
        assetTapHandler: (asset: Shared.HybridPhotoAsset): void => {
          void this.viewModel.openPreviewAssetViewer(asset);
        },
      });

      HybridDayGridView({
        columns: this.viewModel.gridColumns,
        hasMore: this.viewModel.hasMore,
        requestSize: this.viewModel.resolveMainRequestSize(),
        scaleValue: this.viewModel.mainGridScale,
        opacityValue: this.viewModel.mainGridOpacity,
        centerX: this.viewModel.pinchCenterX,
        centerY: this.viewModel.pinchCenterY,
        isVisible: this.viewModel.isMainLayerVisible(),
        scrollerAttachHandler: (scroller: Scroller): void => {
          this.viewModel.bindMainScroller(scroller);
        },
        gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource): void => {
          this.viewModel.bindMainGridDataSource(dataSource);
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
