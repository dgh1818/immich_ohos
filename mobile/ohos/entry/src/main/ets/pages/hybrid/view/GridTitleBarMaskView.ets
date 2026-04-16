import { PhotoGridViewId, PhotoGridZIndex } from '../viewcontroller/PhotoGridViewController';

@Component
export struct GridTitleBarMaskView {
  @Prop maskHeight: number = 72;
  @Prop opacityValue: number = 1;

  build() {
    Column() {}
      .id(PhotoGridViewId.TITLE_BAR_MASK)
      .zIndex(PhotoGridZIndex.TITLE_BAR_MASK)
      .width('100%')
      .height(this.maskHeight)
      .alignRules({
        top: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Top },
        start: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.Start },
        end: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.End },
      })
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
