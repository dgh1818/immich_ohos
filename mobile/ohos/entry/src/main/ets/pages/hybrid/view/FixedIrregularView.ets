import { PhotoGridViewId, PhotoGridZIndex } from '../viewcontroller/PhotoGridViewController';

@Component
export struct FixedIrregularView {
  build() {
    Column() {}
      .id(PhotoGridViewId.FIXED_IRREGULAR)
      .zIndex(PhotoGridZIndex.FIXED_IRREGULAR)
      .width('100%')
      .height(0)
      .hitTestBehavior(HitTestMode.None);
  }
}
