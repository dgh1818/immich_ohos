import { PhotoGridViewId, PhotoGridZIndex } from '../viewcontroller/PhotoGridViewController';

@Component
export struct IrregularView {
  @Prop title: string = '';
  @Prop count: number = 0;
  @Prop topInset: number = 56;

  build() {
    if (this.title) {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(0xFF111827);

        Text(`${this.count} items`)
          .fontSize(10)
          .fontColor(0xFF64748B);
      }
      .id(PhotoGridViewId.IRREGULAR)
      .zIndex(PhotoGridZIndex.IRREGULAR)
      .alignRules({
        top: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Top },
        start: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.Start },
      })
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor('#E0E0E0')
      .borderRadius(18)
      .margin({ left: 8, top: this.topInset + 4 })
      .hitTestBehavior(HitTestMode.None);
    }
  }
}
