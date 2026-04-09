@Observed
export class HybridGridSnapshotVc {
  @Track public snapshotImage?: PixelMap;
  @Track public isVisible: boolean = false;

  public showSnapshot(snapshotImage?: PixelMap): void {
    this.snapshotImage = snapshotImage;
    this.isVisible = snapshotImage !== undefined;
  }

  public hideSnapshot(): void {
    this.snapshotImage = undefined;
    this.isVisible = false;
  }
}
