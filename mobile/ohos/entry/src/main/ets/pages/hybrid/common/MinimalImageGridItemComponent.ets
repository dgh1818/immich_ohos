import { HYBRID_REQUEST_SIZE, HybridPhotoAsset } from '../HybridPhotoGridShared';
import {
  HybridPhotoTilePlaceholderMode,
  HybridPhotoTileReleasePolicy,
} from '../HybridPhotoTile';
import { ImageGridItemComponent } from './ImageGridItemComponent';

@Reusable
@Component
export struct MinimalImageGridItemComponent {
  @Prop
  asset: HybridPhotoAsset = { id: '', isVideo: false, durationInSeconds: 0 };

  @Prop
  requestSize: number = HYBRID_REQUEST_SIZE;

  @Prop
  layerActive: boolean = true;

  @Prop
  warmActive: boolean = false;

  @Prop
  releasePolicy: HybridPhotoTileReleasePolicy = HybridPhotoTileReleasePolicy.DELAYED;

  @Prop
  invisibleReleaseDelayMs: number = 220;

  @Prop
  placeholderMode: HybridPhotoTilePlaceholderMode = HybridPhotoTilePlaceholderMode.GLASS;

  @Prop
  suppressRelease: boolean = false;

  build() {
    ImageGridItemComponent({
      asset: this.asset,
      requestSize: this.requestSize,
      layerActive: this.layerActive,
      warmActive: this.warmActive,
      releasePolicy: this.releasePolicy,
      invisibleReleaseDelayMs: this.invisibleReleaseDelayMs,
      placeholderMode: this.placeholderMode,
      suppressRelease: this.suppressRelease,
    });
  }
}