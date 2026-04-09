import { HybridPhotoGridViewId, HybridPhotoGridZIndex } from '../viewcontroller/HybridPhotoGridVc';

@Component
export struct HybridGridTitleBarMaskView {
  @Prop maskHeight: number = 72;
  @Prop opacityValue: number = 1;

  build() {
    Column() {}
      .id(HybridPhotoGridViewId.TITLE_BAR_MASK)
      .zIndex(HybridPhotoGridZIndex.TITLE_BAR_MASK)
      .width('100%')
      .height(this.maskHeight)
      .opacity(this.opacityValue)
      .linearGradient({
        angle: 180,
        colors: [
          [0xE510141A, 0],
          [0xA810141A, 0.22],
          [0x4A10141A, 0.56],
          [0x0010141A, 1],
        ],
      })
      .hitTestBehavior(HitTestMode.None);
  }
}
