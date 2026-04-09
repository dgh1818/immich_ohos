import { HybridPhotoGridViewId, HybridPhotoGridZIndex } from '../viewcontroller/HybridPhotoGridVc';

@Component
export struct HybridFixedIrregularView {
  build() {
    Column() {}
      .id(HybridPhotoGridViewId.FIXED_IRREGULAR)
      .zIndex(HybridPhotoGridZIndex.FIXED_IRREGULAR)
      .width('100%')
      .height(0)
      .hitTestBehavior(HitTestMode.None);
  }
}
