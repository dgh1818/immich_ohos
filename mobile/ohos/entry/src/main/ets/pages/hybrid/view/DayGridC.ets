import * as Shared from '../HybridPhotoGridShared';
import { HybridPhotoTile, HybridPhotoTileReleasePolicy } from '../HybridPhotoTile';
import { HybridGridAttributeUpdater } from '../viewcontroller/HybridDayGridVc';
import { HybridPhotoGridViewId, HybridPhotoGridZIndex } from '../viewcontroller/HybridPhotoGridVc';

type HybridGridItem = Shared.HybridGridItem;
type HybridPhotoAsset = Shared.HybridPhotoAsset;

const HYBRID_DAY_GRID_C_SCROLLER: Scroller = new Scroller();
const HYBRID_DAY_GRID_C_DATA_SOURCE: Shared.HybridGridDataSource = new Shared.HybridGridDataSource();

@Component
export struct HybridDayGridC {
  @Prop visible: boolean = false;
  @Prop interactive: boolean = false;
  @Prop warmActive: boolean = false;
  @Prop columns: number = Shared.HYBRID_GRID_COLUMNS;
  @Prop cacheRows: number = Shared.HYBRID_LIST_CACHE_COUNT;
  @Prop requestSize: number = Shared.HYBRID_REQUEST_SIZE;
  @Prop opacityValue: number = 1;
  @Prop scaleValue: number = 1;
  @Prop centerX: number = 0;
  @Prop centerY: number = 0;
  @Prop hasMore: boolean = true;
  @Prop zIndexValue: number = HybridPhotoGridZIndex.DAY_GRID_C;
  public attributeUpdater: HybridGridAttributeUpdater = new HybridGridAttributeUpdater();
  public scrollerAttachHandler: (scroller: Scroller) => void = (_scroller: Scroller): void => {};
  public gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource) => void =
    (_dataSource: Shared.HybridGridDataSource): void => {};
  public areaChangeHandler: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  public scrollStartHandler: () => void = (): void => {};
  public scrollStopHandler: () => void = (): void => {};
  public scrollIndexHandler: (start: number, end: number) => void = (_start: number, _end: number): void => {};
  public assetTapHandler: (asset: HybridPhotoAsset) => void = (_asset: HybridPhotoAsset): void => {};
  public pinchStartHandler: (centerX: number, centerY: number) => void = (_centerX: number, _centerY: number): void => {};
  public pinchUpdateHandler: (scale: number, centerX: number, centerY: number) => void =
    (_scale: number, _centerX: number, _centerY: number): void => {};
  public pinchEndHandler: () => void = (): void => {};

  aboutToAppear(): void {
    this.scrollerAttachHandler(HYBRID_DAY_GRID_C_SCROLLER);
    this.gridDataSourceAttachHandler(HYBRID_DAY_GRID_C_DATA_SOURCE);
  }

  private resolveColumnsTemplate(): string {
    return '1fr '.repeat(Math.max(1, this.columns)).trim();
  }

  @Builder
  private buildPhotoCell(asset: HybridPhotoAsset) {
    Stack() {
      HybridPhotoTile({
        asset: asset,
        requestSize: this.requestSize,
        suppressRelease: false,
        layerActive: this.visible && this.opacityValue > 0.01,
        warmActive: this.warmActive,
        releasePolicy: this.interactive ? HybridPhotoTileReleasePolicy.DELAYED : HybridPhotoTileReleasePolicy.ACTIVE_ONLY,
        invisibleReleaseDelayMs: this.interactive ? 220 : 0,
      })
        .width('100%')
        .height('100%')
        .onClick((): void => {
          this.assetTapHandler(asset);
        });
    }
    .width('100%')
    .clip(false)
    .aspectRatio(1);
  }

  @Builder
  private buildPlaceholderCell() {
    Column() {}
      .width('100%')
      .aspectRatio(1)
      .backgroundColor(Color.Transparent);
  }

  build() {
    Grid(HYBRID_DAY_GRID_C_SCROLLER) {
      LazyForEach(
        HYBRID_DAY_GRID_C_DATA_SOURCE,
        (item: HybridGridItem) => {
          GridItem() {
            if (item.kind === 'photo' && item.asset) {
              this.buildPhotoCell(item.asset);
            } else {
              this.buildPlaceholderCell();
            }
          }
          .reuseId(item.kind === 'photo' ? 'photoTile' : 'placeholder');
        },
        (item: HybridGridItem) => `expand_${item.id}`,
      );
    }
      .id(HybridPhotoGridViewId.DAY_GRID_C)
      .attributeModifier(this.attributeUpdater)
      .columnsTemplate(this.resolveColumnsTemplate())
      .rowsGap(Shared.HYBRID_GRID_GAP)
      .columnsGap(Shared.HYBRID_GRID_GAP)
      .cachedCount(Math.max(1, this.cacheRows))
      .scrollBar(BarState.Off)
      .edgeEffect(this.interactive ? EdgeEffect.Spring : EdgeEffect.None)
      .clip(false)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(this.visible && this.interactive ? HitTestMode.Default : HitTestMode.None)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.areaChangeHandler(Number(newValue.width), Number(newValue.height));
      })
      .onScrollStart((): void => {
        this.scrollStartHandler();
      })
      .onScrollStop((): void => {
        this.scrollStopHandler();
      })
      .onScrollIndex((start: number, end: number): void => {
        this.scrollIndexHandler(start, end);
      })
      .gesture(
        GestureGroup(
          GestureMode.Parallel,
          PinchGesture({ fingers: 2 })
            .onActionStart((event: GestureEvent): void => {
              this.pinchStartHandler(event.pinchCenterX, event.pinchCenterY);
              this.pinchUpdateHandler(event.scale, event.pinchCenterX, event.pinchCenterY);
            })
            .onActionUpdate((event: GestureEvent): void => {
              this.pinchUpdateHandler(event.scale, event.pinchCenterX, event.pinchCenterY);
            })
            .onActionEnd((_event: GestureEvent): void => {
              this.pinchEndHandler();
            })
            .onActionCancel((_event: GestureEvent): void => {
              this.pinchEndHandler();
            }),
        ),
      );
  }
}
