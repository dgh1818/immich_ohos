@Observed
export class HybridGridSnapshotVc {
  @Track public snapshotImage?: PixelMap;
  @Track public isVisible: boolean = false;

  public showSnapshot(snapshotImage?: PixelMap): void {
    if (this.snapshotImage && this.snapshotImage !== snapshotImage) {
      try {
        this.snapshotImage.release();
      } catch (_) {}
    }
    this.snapshotImage = snapshotImage;
    this.isVisible = snapshotImage !== undefined;
  }

  public hideSnapshot(): void {
    const currentSnapshot = this.snapshotImage;
    this.snapshotImage = undefined;
    this.isVisible = false;
    if (currentSnapshot) {
      try {
        currentSnapshot.release();
      } catch (_) {}
    }
  }
}
