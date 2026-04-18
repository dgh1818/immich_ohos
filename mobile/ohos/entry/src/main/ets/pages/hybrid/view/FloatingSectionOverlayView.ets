import { IrregularView } from './IrregularView';

@Component
export struct FloatingSectionOverlayView {
  @Prop topInset: number = 56;
  public addStateListenerHandler: (listener: () => void) => void = (_listener: () => void): void => {};
  public removeStateListenerHandler: (listener: () => void) => void = (_listener: () => void): void => {};
  public resolveTitleHandler: () => string = (): string => '';
  public resolveCountHandler: () => number = (): number => 0;

  @State private title: string = '';
  @State private count: number = 0;

  private readonly stateListener: () => void = (): void => {
    this.syncState();
  };

  aboutToAppear(): void {
    this.syncState();
    this.addStateListenerHandler(this.stateListener);
  }

  aboutToDisappear(): void {
    this.removeStateListenerHandler(this.stateListener);
  }

  private syncState(): void {
    const nextTitle = this.resolveTitleHandler();
    const nextCount = this.resolveCountHandler();
    if (this.title === nextTitle && this.count === nextCount) {
      return;
    }
    this.title = nextTitle;
    this.count = nextCount;
  }

  build() {
    IrregularView({
      title: this.title,
      count: this.count,
      topInset: this.topInset,
    });
  }
}