import { PhotoGridViewId, PhotoGridZIndex } from '../viewcontroller/PhotoGridViewController';

@Component
export struct GridNoDataView {
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
      .id(PhotoGridViewId.NO_DATA)
      .zIndex(PhotoGridZIndex.NO_DATA)
      .width('100%')
      .height('100%')
      .alignRules({
        top: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Top },
        bottom: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Bottom },
        start: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.Start },
        end: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.End },
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None);
    }
  }
}
