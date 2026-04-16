import { PhotoGridViewId, PhotoGridZIndex } from '../viewcontroller/PhotoGridViewController';

@Component
export struct FixedIrregularView {
  public areaChangeHandler: (width: number, height: number) => void = (_width: number, _height: number): void => {};

  build() {
    Column() {}
      .id(PhotoGridViewId.FIXED_IRREGULAR)
      .zIndex(PhotoGridZIndex.FIXED_IRREGULAR)
      .width('100%')
      .height(0)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        this.areaChangeHandler(Number(newValue.width), Number(newValue.height));
      })
      .alignRules({
        top: { anchor: PhotoGridViewId.CONTAINER, align: VerticalAlign.Top },
        start: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.Start },
        end: { anchor: PhotoGridViewId.CONTAINER, align: HorizontalAlign.End },
      })
      .hitTestBehavior(HitTestMode.None);
  }
}
