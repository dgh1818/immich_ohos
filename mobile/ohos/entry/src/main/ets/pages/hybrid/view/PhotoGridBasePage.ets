import { PhotoGridViewBuilder } from './PhotoGridViewBuilder';

@Component
export struct PhotoGridBasePage {
  @Prop topInset: number = 56;

  @Builder
  private buildPhotoGridView() {
    PhotoGridViewBuilder({
      topInset: this.topInset,
    });
  }

  build() {
    Column() {
      this.buildPhotoGridView();
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .backgroundColor($r('app.color.start_window_background'));
  }
}