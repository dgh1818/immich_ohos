@Component
export struct LazyLoadImg {
  @Prop @Watch('onTouchScrollEndChange') touchScrollEnd: boolean = true;
  @Builder private defaultChild() {}
  @BuilderParam child: () => void = this.defaultChild;

  @State private deferLoad: boolean = false;

  aboutToAppear(): void {
    this.onTouchScrollEndChange();
  }

  private onTouchScrollEndChange(): void {
    if (this.touchScrollEnd) {
      this.deferLoad = false;
      return;
    }
    this.deferLoad = true;
  }

  private shouldShowPlaceholder(): boolean {
    return !this.touchScrollEnd && this.deferLoad;
  }

  build() {
    Row() {
      if (this.shouldShowPlaceholder()) {
        Row()
          .width('100%')
          .aspectRatio(1)
          .backgroundColor('#E0E0E0');
      } else {
        this.child();
      }
    }
    .width('100%')
    .height('100%')
    .onAppear((): void => {
      this.onTouchScrollEndChange();
    });
  }
}
