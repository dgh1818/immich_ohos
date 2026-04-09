import * as Shared from '../HybridPhotoGridShared';
import { HybridPhotoTile, HybridPhotoTileReleasePolicy } from '../HybridPhotoTile';
import { HybridPhotoGridZIndex } from '../viewcontroller/HybridPhotoGridVc';

type HybridGridItem = Shared.HybridGridItem;
type HybridPhotoAsset = Shared.HybridPhotoAsset;

const HYBRID_IDLE_SHRINK_GRID_SCROLLER: Scroller = new Scroller();
const HYBRID_IDLE_SHRINK_GRID_DATA_SOURCE: Shared.HybridGridDataSource = new Shared.HybridGridDataSource();

@Component
export struct HybridIdleShrinkGridView {
  @Prop visible: boolean = false;
  @Prop warmActive: boolean = false;
  @Prop columns: number = Shared.HYBRID_GRID_COLUMNS;
  @Prop requestSize: number = Shared.HYBRID_REQUEST_SIZE;
  @Prop opacityValue: number = 1;
  @Prop scaleValue: number = 1;
  @Prop centerX: number = 0;
  @Prop centerY: number = 0;
  @Prop zIndexValue: number = HybridPhotoGridZIndex.DAY_PREVIEW_GRID;
  public scrollerAttachHandler: (scroller: Scroller) => void = (_scroller: Scroller): void => {};
  public gridDataSourceAttachHandler: (dataSource: Shared.HybridGridDataSource) => void =
    (_dataSource: Shared.HybridGridDataSource): void => {};
  public areaChangeHandler: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  public assetTapHandler: (asset: HybridPhotoAsset) => void = (_asset: HybridPhotoAsset): void => {};

  aboutToAppear(): void {
    this.scrollerAttachHandler(HYBRID_IDLE_SHRINK_GRID_SCROLLER);
    this.gridDataSourceAttachHandler(HYBRID_IDLE_SHRINK_GRID_DATA_SOURCE);
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
        releasePolicy: HybridPhotoTileReleasePolicy.AGGRESSIVE,
        invisibleReleaseDelayMs: 48,
      })
        .width('100%')
        .height('100%')
        .onClick((): void => {
          this.assetTapHandler(asset);
        });
    }
    .width('100%')
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
    Grid(HYBRID_IDLE_SHRINK_GRID_SCROLLER) {
      LazyForEach(
        HYBRID_IDLE_SHRINK_GRID_DATA_SOURCE,
        (item: HybridGridItem) => {
          GridItem() {
            if (item.kind === 'photo' && item.asset) {
              this.buildPhotoCell(item.asset);
            } else {
              this.buildPlaceholderCell();
            }
          }
        },
        (item: HybridGridItem) => `idle_preview_${item.id}`,
      );
    }
      .id('__hybrid_idle_shrink_grid__')
      .zIndex(this.zIndexValue)
      .columnsTemplate(this.resolveColumnsTemplate())
      .rowsGap(Shared.HYBRID_GRID_GAP)
      .columnsGap(Shared.HYBRID_GRID_GAP)
      .cachedCount(Shared.HYBRID_LIST_CACHE_COUNT)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .clip(false)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .opacity(this.visible ? this.opacityValue : 0)
      .hitTestBehavior(HitTestMode.None)
      .scale({
        x: this.scaleValue,
        y: this.scaleValue,
        centerX: this.centerX,
        centerY: this.centerY,
      })
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.areaChangeHandler(Number(newValue.width), Number(newValue.height));
      });
  }
}
