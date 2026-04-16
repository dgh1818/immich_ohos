import lazy { AttributeUpdater } from '@kit.ArkUI';

export class GridAttributeUpdater extends AttributeUpdater<GridAttribute> {
  private readonly lowZIndex: number = -1;
  private readonly highZIndex: number = 0;
  private scaleOptions: ScaleOptions = { x: 1, y: 1 };
  private opacityValue: number = 1.0;
  private widthValue: Length = '100%';
  private heightValue: Length = '100%';
  private visibilityValue: Visibility = Visibility.Visible;
  private zIndexValue: number = this.highZIndex;
  private isLowGrid: boolean = false;
  private hitTestMode: HitTestMode = HitTestMode.Default;
  private showBackground: boolean = true;
  private enabledValue: boolean = true;

  public override initializeModifier(instance: GridAttribute): void {
    instance
      .scale(this.scaleOptions)
      .opacity(this.opacityValue)
      .width(this.widthValue)
      .height(this.heightValue)
      .visibility(this.visibilityValue)
      .zIndex(this.zIndexValue)
      .hitTestBehavior(this.hitTestMode)
      .enabled(this.enabledValue);
  }

  public override onComponentChanged(instance: GridAttribute): void {
    instance
      .scale(this.scaleOptions)
      .opacity(this.opacityValue)
      .width(this.widthValue)
      .height(this.heightValue)
      .visibility(this.visibilityValue)
      .zIndex(this.zIndexValue)
      .hitTestBehavior(this.hitTestMode)
      .enabled(this.enabledValue);
  }

  public updateScale(scaleOptions: ScaleOptions): void {
    this.scaleOptions = scaleOptions;
    this.attribute?.scale(this.scaleOptions);
  }

  public updateOpacity(opacity: number): void {
    this.opacityValue = Math.max(0, Math.min(1, opacity));
    this.attribute?.opacity(this.opacityValue);
  }

  public updateSize(width: Length, height: Length): void {
    this.widthValue = width;
    this.heightValue = height;
    this.attribute?.width(this.widthValue);
    this.attribute?.height(this.heightValue);
  }

  public updateVisibility(visibility: Visibility): void {
    this.visibilityValue = visibility;
    this.attribute?.visibility(this.visibilityValue);
  }

  public updateZIndex(zIndex: number): void {
    this.zIndexValue = zIndex;
    this.attribute?.zIndex(this.zIndexValue);
  }

  public updateIsLowGrid(isLowGrid: boolean): void {
    if (this.isLowGrid === isLowGrid) {
      return;
    }
    this.isLowGrid = isLowGrid;
    this.updateZIndex(this.getZIndex());
  }

  public updateHitTestMode(hitTestMode: HitTestMode): void {
    if (this.hitTestMode === hitTestMode) {
      return;
    }
    this.hitTestMode = hitTestMode;
    this.attribute?.hitTestBehavior(this.hitTestMode);
  }

  public updateShowBackground(showBackground: boolean): void {
    this.showBackground = showBackground;
  }

  public updateEnable(enabled: boolean): void {
    this.enabledValue = enabled;
    this.attribute?.enabled(this.enabledValue);
  }

  public getZIndex(): number {
    return this.isLowGrid ? this.lowZIndex : this.highZIndex;
  }

  public getHitTestMode(): HitTestMode {
    return this.hitTestMode;
  }

  public getShowBackground(): boolean {
    return this.showBackground;
  }

  public restoreZIndex(): void {
    this.updateIsLowGrid(false);
    this.updateEnable(true);
  }

  public setLowZIndex(): void {
    this.updateIsLowGrid(true);
  }
}
