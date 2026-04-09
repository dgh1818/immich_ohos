import { HybridPhotoGridViewId, HybridPhotoGridZIndex } from '../viewcontroller/HybridPhotoGridVc';

@Component
export struct HybridIrregularView {
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
      .id(HybridPhotoGridViewId.IRREGULAR)
      .zIndex(HybridPhotoGridZIndex.IRREGULAR)
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      .borderRadius(18)
      .margin({ left: 8, top: this.topInset + 4 })
      .hitTestBehavior(HitTestMode.None);
    }
  }
}
