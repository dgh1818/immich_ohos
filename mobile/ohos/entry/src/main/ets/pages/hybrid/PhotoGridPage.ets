import { PhotoGridBasePage } from './view/PhotoGridBasePage';

@Component
export struct PhotoGridPage {
  @Prop topInset: number = 56;

  build() {
    PhotoGridBasePage({
      topInset: this.topInset,
    });
  }
}
