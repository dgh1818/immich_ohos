import { HybridPhotoGridViewId, HybridPhotoGridZIndex } from '../viewcontroller/HybridPhotoGridVc';

@Component
export struct HybridGridNoDataView {
  @Prop visible: boolean = false;

  build() {
    if (this.visible) {
      Column({ space: 8 }) {
        Text('No photos yet')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(0xFF111827);

        Text('Hybrid timeline data source is empty')
          .fontSize(13)
          .fontColor(0xFF64748B);
      }
      .id(HybridPhotoGridViewId.NO_DATA)
      .zIndex(HybridPhotoGridZIndex.NO_DATA)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None);
    }
  }
}
