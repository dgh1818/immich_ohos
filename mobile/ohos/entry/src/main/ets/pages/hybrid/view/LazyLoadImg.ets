@Component
export struct LazyLoadImg {
  @Prop touchScrollEnd: boolean = true;
  @Prop allowLoadWhileScrolling: boolean = false;
  @Builder private defaultChild() {}
  @BuilderParam child: () => void = this.defaultChild;

  build() {
    Row() {
      this.child();
    }
    .width('100%')
    .height('100%');
  }
}
