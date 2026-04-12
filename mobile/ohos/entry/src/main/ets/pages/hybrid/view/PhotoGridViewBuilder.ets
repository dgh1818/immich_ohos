import { TimelinePageLoader } from './TimelinePageLoader';

@Component
export struct PhotoGridViewBuilder {
  @Prop topInset: number = 56;

  build() {
    TimelinePageLoader({
      topInset: this.topInset,
    });
  }
}
