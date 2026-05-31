import { BasicPrefetcher } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import * as Shared from '../PhotoGridShared';
import { buildThumbnailCacheKey, hasRemoteThumbnailCache, HybridThumbnailCache } from '../HybridPhotoThumbnail';
import { GridAttributeUpdater } from '../viewcontroller/GridAttributeUpdater';
import { PhotoGridViewId } from '../viewcontroller/PhotoGridViewController';
import { ImageGridItemComponent, ImageGridItemReleasePolicy } from '../common/ImageGridItemComponent';
import { LazyLoadImg } from './LazyLoadImg';

type GridItem = Shared.GridItem;
type PhotoAsset = Shared.PhotoAsset;

const DAY_GRID_SCROLLER: Scroller = new Scroller();
const DAY_GRID_DATA_SOURCE: Shared.GridDataSource = new Shared.GridDataSource();
const DAY_GRID_PREFETCHER: BasicPrefetcher = new BasicPrefetcher(DAY_GRID_DATA_SOURCE);

@Component
export struct DayGridView {
  private context = getContext(this) as common.UIAbilityContext;
  @Prop visible: boolean = false;
  @Prop interactive: boolean = false;
  @Prop warmActive: boolean = false;
  @Prop columns: number = Shared.GRID_COLUMNS;
  @Prop layoutOptions: GridLayoutOptions = { regularSize: [1, 1], irregularIndexes: [] };
  @Prop headSpacerHeight: number = 0;
  @Prop tailSpacerHeight: number = 0;
  @Prop gap: number = Shared.GRID_GAP;
  @Prop tailFillPositions: Array<number> = [];
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
  public didScrollHandler: (offset: number, state: number) => void = (_offset: number, _state: number): void => {};
  public reachStartHandler: () => void = (): void => {};
  public reachEndHandler: () => void = (): void => {};
  public willScrollHandler: (offset: number, state: number, source: number) => void =
    (_offset: number, _state: number, _source: number): void => {};
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

  private shouldAllowLoadWhileScrolling(asset: PhotoAsset): boolean {
    if (this.touchScrollEnd) {
      return true;
    }

    const cacheKey = buildThumbnailCacheKey(asset.id, this.requestSize);
    if (HybridThumbnailCache.hasReady(cacheKey)) {
      return true;
    }

    const remoteUrl = asset.thumbnailUrl;
    if (!remoteUrl || remoteUrl.length <= 0) {
      return true;
    }

    return hasRemoteThumbnailCache(this.context, remoteUrl, this.requestSize, false);
  }

  @Builder
  private buildPhotoCell(asset: PhotoAsset) {
    Stack() {
      LazyLoadImg({
        touchScrollEnd: this.touchScrollEnd,
        allowLoadWhileScrolling: this.shouldAllowLoadWhileScrolling(asset),
      }) {
        Stack() {
          ImageGridItemComponent({
            asset: asset,
            requestSize: this.requestSize,
            suppressRelease: false,
            layerActive: this.visible && this.opacityValue > 0.01,
            warmActive: this.warmActive,
            releasePolicy: this.interactive ? ImageGridItemReleasePolicy.DELAYED : ImageGridItemReleasePolicy.ACTIVE_ONLY,
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
      .backgroundColor('#E0E0E0');
  }

  @Builder
  private buildHeadSpacer() {
    if (this.headSpacerHeight > 0) {
      GridItem() {
        Column() {}
          .width('100%')
          .height(this.headSpacerHeight)
          .backgroundColor('#E0E0E0');
      }
      .columnStart(0)
      .columnEnd(this.columns + 1);
    }
  }

  @Builder
  private buildTailFillItems() {
    ForEach(this.tailFillPositions, (item: number) => {
      GridItem() {
        this.buildPlaceholderCell();
      }
      .reuseId(`tailFill_${item}`);
    }, (item: number) => `day_tail_fill_${item}`);
  }

  @Builder
  private buildTailSpacer() {
    if (this.tailSpacerHeight > 0) {
      GridItem() {
        Column() {}
          .width('100%')
          .height(this.tailSpacerHeight)
          .backgroundColor('#E0E0E0');
      }
      .columnStart(0)
      .columnEnd(this.columns + 1);
    }
  }

  build() {
    Grid(DAY_GRID_SCROLLER, this.layoutOptions) {
      this.buildHeadSpacer();
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
      this.buildTailFillItems();
      this.buildTailSpacer();
    }
      .id(PhotoGridViewId.DAY_GRID)
      .attributeModifier(this.attributeUpdater)
      .columnsTemplate(this.resolveColumnsTemplate())
      .rowsGap(this.gap)
      .columnsGap(this.gap)
      .cachedCount(Math.max(1, this.cacheRows))
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
      .draggable(false)
      .clip(false)
      .width('100%')
      .height('100%')
      .backgroundColor('#E0E0E0')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .hitTestBehavior(this.visible && this.interactive ? HitTestMode.Default : HitTestMode.None)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.areaChangeHandler(Number(newValue.width), Number(newValue.height));
      })
      .onScrollStart((): void => {
        this.scrollStartHandler();
      })
      .onScrollStop((): void => {
        this.touchStateHandler(false);
        this.scrollStopHandler();
      })
      .onTouch((event: TouchEvent): void => {
        if (event.type === TouchType.Down || event.type === TouchType.Move) {
          this.touchStateHandler(true);
          return;
        }
        if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.touchStateHandler(false);
        }
      })
      .onScrollIndex((start: number, end: number): void => {
        DAY_GRID_DATA_SOURCE.updatePrefetchViewport(start, end);
        DAY_GRID_PREFETCHER.visibleAreaChanged(start, end);
        this.scrollIndexHandler(start, end);
      })
      .onDidScroll((offset: number, state: number): void => {
        this.didScrollHandler(offset, state);
      })
      .onReachStart((): void => {
        this.reachStartHandler();
      })
      .onReachEnd((): void => {
        this.reachEndHandler();
      })
      .onWillScroll((offset: number, state: number, source: number): void => {
        this.willScrollHandler(offset, state, source);
      })
      .backToTop(false)
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
