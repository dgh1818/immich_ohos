import * as Shared from '../PhotoGridShared';
import { GridAttributeUpdater } from '../viewcontroller/GridAttributeUpdater';
import { PhotoGridViewId } from '../viewcontroller/PhotoGridViewController';
import { PhotoTile, PhotoTileReleasePolicy } from '../PhotoTile';
import { LazyLoadImg } from './LazyLoadImg';

type GridItem = Shared.GridItem;
type PhotoAsset = Shared.PhotoAsset;

const DAY_GRID_SCROLLER: Scroller = new Scroller();
const DAY_GRID_DATA_SOURCE: Shared.GridDataSource = new Shared.GridDataSource();

@Component
export struct DayGridView {
  @Prop visible: boolean = false;
  @Prop interactive: boolean = false;
  @Prop warmActive: boolean = false;
  @Prop columns: number = Shared.GRID_COLUMNS;
  @Prop cacheRows: number = Shared.LIST_CACHE_COUNT;
  @Prop hasMore: boolean = true;
  @Prop requestSize: number = Shared.REQUEST_SIZE;
  @Prop touchScrollEnd: boolean = true;
  @Prop scaleValue: number = 1;
  @Prop opacityValue: number = 1;
  @Prop centerX: number = 0;
  @Prop centerY: number = 0;
  public attributeUpdater: GridAttributeUpdater = new GridAttributeUpdater();
  public scrollerAttachHandler: (scroller: Scroller) => void = (_scroller: Scroller): void => {};
  public gridDataSourceAttachHandler: (dataSource: Shared.GridDataSource) => void =
    (_dataSource: Shared.GridDataSource): void => {};
  public assetTapHandler: (asset: Shared.PhotoAsset) => void = (_asset: Shared.PhotoAsset): void => {};
  public areaChangeHandler: (width: number, height: number) => void = (_width: number, _height: number): void => {};
  public scrollStartHandler: () => void = (): void => {};
  public scrollStopHandler: () => void = (): void => {};
  public touchStateHandler: (touching: boolean) => void = (_touching: boolean): void => {};
  public scrollIndexHandler: (start: number, end: number) => void = (_start: number, _end: number): void => {};
  public pinchStartHandler: (centerX: number, centerY: number) => void = (_centerX: number, _centerY: number): void => {};
  public pinchUpdateHandler: (scale: number, centerX: number, centerY: number) => void =
    (_scale: number, _centerX: number, _centerY: number): void => {};
  public pinchEndHandler: () => void = (): void => {};

  aboutToAppear(): void {
    this.scrollerAttachHandler(DAY_GRID_SCROLLER);
    this.gridDataSourceAttachHandler(DAY_GRID_DATA_SOURCE);
  }

  private resolveColumnsTemplate(): string {
    return '1fr '.repeat(Math.max(1, this.columns)).trim();
  }

  @Builder
  private buildPhotoCell(asset: PhotoAsset) {
    Stack() {
      LazyLoadImg({
        touchScrollEnd: this.touchScrollEnd,
      }) {
        Stack() {
          PhotoTile({
            asset: asset,
            requestSize: this.requestSize,
            suppressRelease: false,
            layerActive: this.visible && this.opacityValue > 0.01,
            warmActive: this.warmActive,
            releasePolicy: this.interactive ? PhotoTileReleasePolicy.DELAYED : PhotoTileReleasePolicy.ACTIVE_ONLY,
            invisibleReleaseDelayMs: this.interactive ? 220 : 0,
          })
            .width('100%')
            .height('100%')
            .onClick((): void => {
              this.assetTapHandler(asset);
            });
        }
        .width('100%')
        .height('100%');
      }
    }
    .width('100%')
    .clip(false)
    .aspectRatio(1);
  }

  @Builder
  private buildPlaceholderCell() {
    Column() {}
      .width('100%')
      .clip(false)
      .aspectRatio(1)
      .backgroundColor(Color.Transparent);
  }

  build() {
    Grid(DAY_GRID_SCROLLER) {
      LazyForEach(
        DAY_GRID_DATA_SOURCE,
        (item: GridItem) => {
          GridItem() {
            if (item.kind === 'photo' && item.asset) {
              this.buildPhotoCell(item.asset);
            } else {
              this.buildPlaceholderCell();
            }
          }
          .reuseId(item.kind === 'photo' ? 'photoTile' : 'placeholder');
        },
        (item: GridItem) => `day_${item.id}`,
      );
    }
      .id(PhotoGridViewId.DAY_GRID)
      .attributeModifier(this.attributeUpdater)
      .columnsTemplate(this.resolveColumnsTemplate())
      .rowsGap(Shared.GRID_GAP)
      .columnsGap(Shared.GRID_GAP)
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
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down) {
          this.touchStateHandler(true);
          return;
        }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.touchStateHandler(false);
        }
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
