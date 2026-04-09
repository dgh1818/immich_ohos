@Observed
export class HybridGridTitleBarMaskVc {
  @Track public height: number = 72;
  @Track public opacityValue: number = 1;

  public updateTopInset(topInset: number): void {
    this.height = Math.max(40, topInset + 40);
  }

  public updateOpacity(opacityValue: number): void {
    this.opacityValue = Math.max(0, Math.min(1, opacityValue));
  }
}
