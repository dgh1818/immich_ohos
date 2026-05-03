import { common } from "@kit.AbilityKit";
import { HYBRID_REQUEST_SIZE, HybridPhotoAsset } from "./HybridPhotoGridShared";
import {
  buildThumbnailCacheKey,
  HybridThumbnailCache,
  loadVisibleAssetThumbnail,
  prefetchResidentRemoteAssetThumbnail,
  warmupAssetThumbnail,
} from "./HybridPhotoThumbnail";

export enum HybridPhotoTileReleasePolicy {
  DELAYED = 0,
  AGGRESSIVE = 1,
  ACTIVE_ONLY = 2,
}

export enum HybridPhotoTilePlaceholderMode {
  GLASS = 0,
  SOLID_LIGHT = 1,
}

const HYBRID_TILE_DELAYED_RELEASE_MS: number = 220;
const HYBRID_TILE_AGGRESSIVE_RELEASE_MS: number = 48;

@Reusable
@Component
export struct HybridPhotoTile {
  private context = getContext(this) as common.UIAbilityContext;
  private displayedAssetId: string = "";
  private isInVisibleArea: boolean = false;
  private releaseTimeoutId?: number;

  @Watch("onAssetChanged")
  @Prop
  asset: HybridPhotoAsset = { id: "", isVideo: false, durationInSeconds: 0 };

  @Watch("onRequestSizeChanged")
  @Prop
  requestSize: number = HYBRID_REQUEST_SIZE;

  @Watch("onLayerActiveChanged")
  @Prop
  layerActive: boolean = true;

  @Watch("onWarmActiveChanged")
  @Prop
  warmActive: boolean = false;

  @Prop
  releasePolicy: HybridPhotoTileReleasePolicy = HybridPhotoTileReleasePolicy.DELAYED;

  @Prop
  invisibleReleaseDelayMs: number = HYBRID_TILE_DELAYED_RELEASE_MS;

  @Prop
  placeholderMode: HybridPhotoTilePlaceholderMode = HybridPhotoTilePlaceholderMode.GLASS;

  @Prop suppressRelease: boolean = false;

  @State pixelMap: PixelMap | undefined = undefined;
  @State isLoading: boolean = true;
  @State hasError: boolean = false;
  @State loadVersion: number = 0;

  aboutToAppear() {
    this.ensureLoaded();
  }

  aboutToReuse(_params: ESObject): void {
    this.cancelPendingRelease();
    this.reloadForCurrentAsset();
  }

  aboutToRecycle(): void {
    this.cancelPendingRelease();
    this.loadVersion += 1;
    this.releaseDisplayedAsset();
    this.pixelMap = undefined;
    this.hasError = false;
    this.isLoading = true;
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

  private onLayerActiveChanged(): void {
    if (this.shouldKeepReady()) {
      this.cancelPendingRelease();
      this.ensureLoaded();
      return;
    }

    this.scheduleRelease(this.resolveReleaseDelayMs(true));
  }

  private onWarmActiveChanged(): void {
    if (this.shouldKeepReady()) {
      this.cancelPendingRelease();
      this.ensureLoaded();
      return;
    }

    this.scheduleRelease(this.resolveReleaseDelayMs(true));
  }

  private releaseDisplayedAsset(): void {
    if (!this.displayedAssetId) {
      return;
    }
    HybridThumbnailCache.release(this.displayedAssetId);
    this.displayedAssetId = "";
  }

  private reloadForCurrentAsset(): void {
    this.cancelPendingRelease();
    this.loadVersion += 1;
    if (!this.shouldRetainDisplayedContent()) {
      this.releaseDisplayedAsset();
      this.pixelMap = undefined;
    }
    // Keep stale pixelMap visible while new image loads to avoid white flash
    this.hasError = false;
    this.isLoading = true;
    this.ensureLoaded();
  }

  private shouldKeepReady(): boolean {
    return this.layerActive || this.warmActive;
  }

  private shouldLoadContentNow(): boolean {
    return this.isInVisibleArea || this.layerActive || this.warmActive;
  }

  private shouldRetainDisplayedContent(): boolean {
    return this.isInVisibleArea || this.layerActive || this.warmActive;
  }

  private isRemoteAsset(asset: HybridPhotoAsset): boolean {
    return asset.thumbnailUrl !== undefined && asset.thumbnailUrl.length > 0;
  }

  private shouldWarmRemoteOffscreen(asset: HybridPhotoAsset): boolean {
    return !this.isInVisibleArea && this.layerActive && !this.warmActive && this.isRemoteAsset(asset);
  }

  private tryAcquireReadyCache(cacheKey: string): boolean {
    const cachedPixelMap = HybridThumbnailCache.acquire(
      cacheKey,
      this.asset.thumbnailUrl !== undefined && this.asset.thumbnailUrl.length > 0,
    );
    if (!cachedPixelMap) {
      return false;
    }

    this.releaseDisplayedAsset();
    this.displayedAssetId = cacheKey;
    this.pixelMap = cachedPixelMap;
    this.isLoading = false;
    this.hasError = false;
    return true;
  }

  private handleVisibleAreaChange(isVisible: boolean, currentRatio: number): void {
    const nextVisible = isVisible && currentRatio > 0;
    if (nextVisible === this.isInVisibleArea) {
      return;
    }

    this.isInVisibleArea = nextVisible;
    if (nextVisible) {
      this.cancelPendingRelease();
      this.ensureLoaded();
      return;
    }

    if (this.shouldRetainDisplayedContent()) {
      return;
    }

    const releaseDelayMs = this.resolveReleaseDelayMs(false);
    if (releaseDelayMs < 0) {
      return;
    }

    this.scheduleRelease(releaseDelayMs);
  }

  private cancelPendingRelease(): void {
    if (this.releaseTimeoutId === undefined) {
      return;
    }
    clearTimeout(this.releaseTimeoutId);
    this.releaseTimeoutId = undefined;
  }

  private scheduleRelease(delayMs: number): void {
    this.cancelPendingRelease();
    if (delayMs < 0) {
      return;
    }
    if (delayMs === 0) {
      this.releaseNow();
      return;
    }

    this.releaseTimeoutId = setTimeout((): void => {
      this.releaseTimeoutId = undefined;
      this.releaseNow();
    }, delayMs);
  }

  private releaseNow(): void {
    this.loadVersion += 1;
    this.releaseDisplayedAsset();
    this.pixelMap = undefined;
    this.hasError = false;
    this.isLoading = true;
  }

  private resolveReleaseDelayMs(layerInactive: boolean): number {
    if (this.suppressRelease && !layerInactive) {
      return -1;
    }

    if (layerInactive) {
      return this.releasePolicy === HybridPhotoTileReleasePolicy.DELAYED
        ? this.invisibleReleaseDelayMs
        : 0;
    }

    if (this.releasePolicy === HybridPhotoTileReleasePolicy.ACTIVE_ONLY) {
      return 0;
    }
    if (this.releasePolicy === HybridPhotoTileReleasePolicy.AGGRESSIVE) {
      return HYBRID_TILE_AGGRESSIVE_RELEASE_MS;
    }
    return Math.max(0, this.invisibleReleaseDelayMs);
  }

  private async ensureLoaded(): Promise<void> {
    if (!this.shouldLoadContentNow()) {
      return;
    }
    // Skip if already displaying the correct asset and has no error
    if (this.hasError) {
      return;
    }

    const asset: HybridPhotoAsset = this.asset;
    const assetId: string = asset.id;
    const requestSize: number = this.requestSize;
    const cacheKey = buildThumbnailCacheKey(assetId, requestSize);

    // Already displaying this exact asset — nothing to do
    if (this.pixelMap && this.displayedAssetId === cacheKey) {
      this.isLoading = false;
      return;
    }

    if (this.tryAcquireReadyCache(cacheKey)) {
      return;
    }

    if (this.shouldWarmRemoteOffscreen(asset)) {
      if (prefetchResidentRemoteAssetThumbnail(this.context, asset, requestSize)) {
        return;
      }
      warmupAssetThumbnail(this.context, asset, requestSize);
      return;
    }

    const version = ++this.loadVersion;
    // Keep stale pixelMap visible (isLoading=true but pixelMap stays)
    this.isLoading = true;
    this.hasError = false;

    try {
      const pixelMap = await HybridThumbnailCache.load(
        cacheKey,
        asset.thumbnailUrl !== undefined && asset.thumbnailUrl.length > 0,
        () =>
        loadVisibleAssetThumbnail(this.context, asset, requestSize),
      );
      if (version !== this.loadVersion) {
        HybridThumbnailCache.release(cacheKey);
        return;
      }

      this.releaseDisplayedAsset();
      this.displayedAssetId = cacheKey;
      this.pixelMap = pixelMap;
      this.isLoading = false;
      this.hasError = false;
    } catch (error) {
      if (version !== this.loadVersion) {
        return;
      }

      this.isLoading = false;
      this.hasError = true;
      // Clear stale pixelMap on error so error state shows
      this.releaseDisplayedAsset();
      this.pixelMap = undefined;
      console.error(`[HybridPhotoTile] load failed for ${assetId}: ${error}`);
    }
  }

  private formatDuration(totalSeconds: number): string {
    if (totalSeconds <= 0) {
      return "0:00";
    }

    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
    }

    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  }

  @Builder
  private buildGlassPlaceholder() {
    Stack() {
      Column({ space: 10 }) {
        Blank()
          .width("64%")
          .height(14)
          .borderRadius(8)
          .backgroundColor(0x18364759)
        Blank()
          .width("38%")
          .height(14)
          .borderRadius(8)
          .backgroundColor(0x12364759)
      }
      .width("100%")
      .height("100%")
      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Start)
    }
    .width("100%")
    .height("100%")
    .linearGradient({
      angle: 135,
      colors: [
        [0x14cbd5e1, 0.0],
        [0x10b6c2cf, 0.52],
        [0x0aa7b4c2, 1.0],
      ],
    })
    .backgroundColor($r('app.color.start_window_background'));
  }

  @Builder
  private buildSolidPlaceholder() {
    Column() {}
      .width("100%")
      .height("100%")
      .backgroundColor($r('app.color.start_window_background'));
  }

  build() {
    Stack() {
      if (this.pixelMap) {
        Image(this.pixelMap as PixelMap)
          .width("100%")
          .height("100%")
          .objectFit(ImageFit.Cover)
          .enableAnalyzer(false)
          .draggable(false);
      } else if (this.isLoading || !this.hasError) {
        if (this.placeholderMode === HybridPhotoTilePlaceholderMode.SOLID_LIGHT) {
          this.buildSolidPlaceholder();
        } else {
          this.buildGlassPlaceholder();
        }
      } else {
        Column() {
          Text("No preview")
            .fontSize(10)
            .fontColor(0xff6b7280)
        }
        .width("100%")
        .height("100%")
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor($r('app.color.start_window_background'));
      }

      if (this.asset.isVideo) {
        Row() {
          Text(this.formatDuration(this.asset.durationInSeconds))
            .fontSize(9)
            .fontColor(0xffffffff)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .backgroundColor(0x88000000)
        .borderRadius(6)
        .align(Alignment.BottomStart)
        .margin({ left: 4, bottom: 4 });
      }
    }
    .width("100%")
    .height("100%")
    .clip(true)
    .draggable(false)
    .onVisibleAreaChange([0.0, 0.01], (isVisible: boolean, currentRatio: number) => {
      this.handleVisibleAreaChange(isVisible, currentRatio);
    })
    .backgroundColor($r('app.color.start_window_background'));
  }
}
