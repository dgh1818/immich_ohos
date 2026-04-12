import { PhotoGridViewId, PhotoGridZIndex } from '../../viewcontroller/PhotoGridViewController';

@Component
export struct GridSnapshotView {
  @Prop snapshotImage?: PixelMap = undefined;
  @Prop visible: boolean = false;
  @Prop opacityValue: number = 1;
  @Prop offsetY: number = 0;

  build() {
    if (this.visible && this.snapshotImage) {
      Image(this.snapshotImage as PixelMap)
        .id(PhotoGridViewId.GRID_SNAPSHOT)
        .zIndex(PhotoGridZIndex.GRID_SNAPSHOT)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(this.opacityValue)
        .translate({ x: 0, y: this.offsetY })
        .hitTestBehavior(HitTestMode.None);
    }
  }
}
