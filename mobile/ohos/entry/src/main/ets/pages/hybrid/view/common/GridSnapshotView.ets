import { HybridPhotoGridViewId, HybridPhotoGridZIndex } from '../../viewcontroller/HybridPhotoGridVc';

@Component
export struct HybridGridSnapshotView {
  @Prop snapshotImage?: PixelMap = undefined;
  @Prop visible: boolean = false;

  build() {
    if (this.visible && this.snapshotImage) {
      Image(this.snapshotImage as PixelMap)
        .id(HybridPhotoGridViewId.DAY_GRID_SNAPSHOT)
        .zIndex(HybridPhotoGridZIndex.DAY_GRID_SNAPSHOT)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .hitTestBehavior(HitTestMode.None);
    }
  }
}
