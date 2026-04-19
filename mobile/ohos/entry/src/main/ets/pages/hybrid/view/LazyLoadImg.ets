@Component
export struct LazyLoadImg {
  @Watch('onTouchScrollEndChange')
  @Prop touchScrollEnd: boolean = true;
  @Watch('onAllowLoadWhileScrollingChange')
  @Prop allowLoadWhileScrolling: boolean = false;
  @State private deferLoad: boolean = false;
  @Builder private defaultChild() {}
  @BuilderParam child: () => void = this.defaultChild;

  aboutToAppear(): void {
    this.refreshDeferLoadState();
  }

  private onTouchScrollEndChange(): void {
    this.refreshDeferLoadState();
  }

  private onAllowLoadWhileScrollingChange(): void {
    this.refreshDeferLoadState();
  }

  private refreshDeferLoadState(): void {
    this.deferLoad = !this.touchScrollEnd && !this.allowLoadWhileScrolling;
  }

  @Builder
  private buildPlaceholder() {
    Row() {}
      .width('100%')
      .height('100%')
      .backgroundColor('#E0E0E0');
  }

  build() {
    Row() {
      if (!this.touchScrollEnd && this.deferLoad) {
        this.buildPlaceholder();
      } else {
        this.child();
      }
    }
    .width('100%')
    .height('100%')
    .onAppear((): void => {
      this.refreshDeferLoadState();
    });
  }
}
