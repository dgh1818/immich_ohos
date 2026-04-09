import { HybridPhotoGridView } from './view/HybridPhotoGridView';

@Component
export struct HybridPhotoGrid {
  @Prop topInset: number = 56;

  build() {
    HybridPhotoGridView({
      topInset: this.topInset,
    });
  }
}
