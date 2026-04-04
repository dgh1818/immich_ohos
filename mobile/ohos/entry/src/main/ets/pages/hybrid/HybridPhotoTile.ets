import { common } from '@kit.AbilityKit';
import { HYBRID_REQUEST_SIZE, HybridPhotoAsset } from './HybridPhotoGridShared';
import {
  HybridThumbnailCache,
  loadVisibleAssetThumbnail,
} from './HybridPhotoThumbnail';

@Reusable
@Component
export struct HybridPhotoTile {
  private context = getContext(this) as common.UIAbilityContext;
  private displayedAssetId: string = '';
  private isInVisibleArea: boolean = false;

  @Watch('onAssetChanged')
  @Prop asset: HybridPhotoAsset = { id: '', isVideo: false, durationInSeconds: 0 };
  @Watch('onRequestSizeChanged')
  @Prop requestSize: number = HYBRID_REQUEST_SIZE;
  @State pixelMap: PixelMap | undefined = undefined;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State loadVersion: number = 0;

  aboutToAppear() {
    this.ensureLoaded();
  }

  aboutToReuse(_params: ESObject): void {
    this.reloadForCurrentAsset();
  }

  aboutToRecycle(): void {
    this.loadVersion += 1;
    this.releaseDisplayedAsset();
    this.pixelMap = undefined;
    this.hasError = false;
    this.isLoading = false;
  }

  aboutToDisappear() {
    this.aboutToRecycle();
  }

  private onAssetChanged(): void {
    this.reloadForCurrentAsset();
  }

  private onRequestSizeChanged(): void {
    this.reloadForCurrentAsset();
  }

  private releaseDisplayedAsset(): void {
    if (!this.displayedAssetId) {
      return;
    }
    HybridThumbnailCache.release(this.displayedAssetId);
    this.displayedAssetId = '';
  }

  private reloadForCurrentAsset(): void {
    this.loadVersion += 1;
    this.releaseDisplayedAsset();
    this.pixelMap = undefined;
    this.hasError = false;
    this.isLoading = true;
    this.ensureLoaded();
  }

  private handleVisibleAreaChange(isVisible: boolean, currentRatio: number): void {
    const nextVisible = isVisible && currentRatio > 0;
    if (nextVisible === this.isInVisibleArea) {
      return;
    }

    this.isInVisibleArea = nextVisible;
    if (nextVisible) {
      this.ensureLoaded();
      return;
    }

    this.loadVersion += 1;
    this.releaseDisplayedAsset();
    this.pixelMap = undefined;
    this.isLoading = false;
  }

  private async ensureLoaded(): Promise<void> {
    if (this.pixelMap || this.hasError) {
      return;
    }

    const asset: HybridPhotoAsset = this.asset;
    const assetId: string = asset.id;
    const requestSize: number = this.requestSize;

    const cachedPixelMap = HybridThumbnailCache.acquire(assetId);
    if (cachedPixelMap) {
      this.releaseDisplayedAsset();
      this.displayedAssetId = assetId;
      this.pixelMap = cachedPixelMap;
      this.isLoading = false;
      this.hasError = false;
      return;
    }

    const version = ++this.loadVersion;
    this.isLoading = true;
    this.hasError = false;

    try {
      const pixelMap = await HybridThumbnailCache.load(assetId, () =>
        loadVisibleAssetThumbnail(this.context, asset, requestSize)
      );
      if (version !== this.loadVersion) {
        HybridThumbnailCache.release(assetId);
        return;
      }

      this.releaseDisplayedAsset();
      this.displayedAssetId = assetId;
      this.pixelMap = pixelMap;
      this.isLoading = false;
    } catch (error) {
      if (version !== this.loadVersion) {
        return;
      }

      this.isLoading = false;
      this.hasError = true;
      console.error(`[HybridPhotoTile] load failed for ${assetId}: ${error}`);
    }
  }

  private formatDuration(totalSeconds: number): string {
    if (totalSeconds <= 0) {
      return '0:00';
    }

    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }

    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  }

  @Builder
  private buildGlassPlaceholder() {
    Stack() {
      Column({ space: 10 }) {
        Blank()
          .width('64%')
          .height(14)
          .borderRadius(8)
          .backgroundColor(0x42FFFFFF);

        Blank()
          .width('38%')
          .height(14)
          .borderRadius(8)
          .backgroundColor(0x30FFFFFF);
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 135,
      colors: [
        [0x66F8FAFC, 0.0],
        [0x52E2E8F0, 0.52],
        [0x3AD1D9E6, 1.0],
      ],
    })
    .backgroundColor(0x40FFFFFF)
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THIN)
    .border({
      width: 0.6,
      color: 0x28FFFFFF,
    });
  }

  build() {
    Stack() {
      if (this.pixelMap) {
        Image(this.pixelMap as PixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover);
      } else if (this.isLoading) {
        this.buildGlassPlaceholder();
      } else {
        Column() {
          Text('No preview')
            .fontSize(10)
            .fontColor(0xFF6B7280);
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(0xFFE5E7EB);
      }

      if (this.asset.isVideo) {
        Row() {
          Text(this.formatDuration(this.asset.durationInSeconds))
            .fontSize(9)
            .fontColor(0xFFFFFFFF)
            .fontWeight(FontWeight.Medium);
        }
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .backgroundColor(0x88000000)
        .borderRadius(6)
        .align(Alignment.BottomStart)
        .margin({ left: 4, bottom: 4 });
      }
    }
    .layoutWeight(1)
    .aspectRatio(1)
    .onVisibleAreaChange([0.0, 0.01], (isVisible: boolean, currentRatio: number) => {
      this.handleVisibleAreaChange(isVisible, currentRatio);
    })
    .backgroundColor(0xFFE5E7EB);
  }
}
