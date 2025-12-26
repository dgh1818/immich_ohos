@Component
export struct LightDarkTheme {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content();
    }
    .width('100%')
    .height('100%');
  }
}
