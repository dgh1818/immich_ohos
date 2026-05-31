@Component
export struct LazyLoadImg {
  @Prop touchScrollEnd: boolean = true;
  @Prop allowLoadWhileScrolling: boolean = false;
  @Builder private defaultChild() {}
  @BuilderParam child: () => void = this.defaultChild;

  build() {
    Row() {
      if (!this.touchScrollEnd && !this.allowLoadWhileScrolling) {
        Row()
          .width('100%')
          .aspectRatio(1)
          .backgroundColor('#E0E0E0')
      } else {
        this.child();
      }
    }
    .width('100%')
    .height('100%');
  }
}
