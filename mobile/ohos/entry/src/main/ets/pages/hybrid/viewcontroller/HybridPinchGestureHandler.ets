import * as Shared from '../HybridPhotoGridShared';
import { AnchorInfo, HybridSwitchCalc, SwitchCalcParams } from '../viewmodel/HybridSwitchCalc';

export class PinchState {
  public isActive: boolean = false;
  public startColumns: number = 0;
  public targetColumns: number = 0;
  public currentScale: number = 1.0;
  public anchor: AnchorInfo = new AnchorInfo();
  public startScrollOffset: number = 0;
  public centerX: number = 0;
  public centerY: number = 0;
  public gridWidth: number = 0;
  public gridHeight: number = 0;
  public topInset: number = 0;
}

export class PinchAnimationConfig {
  public quickPinchDuration: number = 200;
  public slowPinchDuration: number = 400;
  public switchDuration: number = 200;
  public minScale: number = 0.97;
  public maxScale: number = 1.05;
  public scaleThreshold: number = 0.02;
}

export class PinchEndResult {
  public columns: number = 0;
  public scrollOffset: number = 0;
}

export const DEFAULT_PINCH_CONFIG: PinchAnimationConfig = new PinchAnimationConfig();

export class HybridPinchGestureHandler {
  private readonly tag: string = 'HybridPinchGestureHandler';
  private readonly config: PinchAnimationConfig;
  private state: PinchState | null = null;
  private readonly minColumns: number;
  private readonly maxColumns: number;
  private onStateChange?: (state: PinchState) => void;
  private onScaleUpdate?: (scale: number, centerX: number, centerY: number) => void;
  private onColumnsChange?: (columns: number, scrollOffset: number) => void;

  public constructor(
    config: PinchAnimationConfig = DEFAULT_PINCH_CONFIG,
    minColumns: number = Shared.HYBRID_GRID_MIN_COLUMNS,
    maxColumns: number = Shared.HYBRID_GRID_MAX_COLUMNS,
  ) {
    this.config = config;
    this.minColumns = minColumns;
    this.maxColumns = maxColumns;
  }

  public start(
    currentColumns: number,
    pinchCenterX: number,
    pinchCenterY: number,
    scrollOffset: number,
    gridWidth: number,
    gridHeight: number,
    topInset: number,
  ): PinchState {
    const anchor = HybridSwitchCalc.calculateAnchor(
      pinchCenterX,
      pinchCenterY,
      scrollOffset,
      currentColumns,
      gridWidth,
      gridHeight,
      topInset,
    );

    const state = new PinchState();
    state.isActive = true;
    state.startColumns = currentColumns;
    state.targetColumns = currentColumns;
    state.currentScale = 1.0;
    state.anchor = anchor;
    state.startScrollOffset = scrollOffset;
    state.centerX = anchor.anchorCenterX;
    state.centerY = anchor.anchorCenterY;
    state.gridWidth = gridWidth;
    state.gridHeight = gridHeight;
    state.topInset = topInset;

    this.state = state;
    console.log(
      `[${this.tag}] Pinch started: anchor=${anchor.itemIndex}, center=(${state.centerX}, ${state.centerY})`,
    );

    this.onStateChange?.(state);
    return state;
  }

  public update(
    scale: number,
    pinchCenterX: number,
    pinchCenterY: number,
    gridWidth: number,
  ): PinchState | null {
    if (!this.state) {
      return null;
    }

    const clampedScale = Math.max(0.5, Math.min(2.0, scale));
    this.state.centerX = pinchCenterX;
    this.state.centerY = pinchCenterY;
    this.state.currentScale = clampedScale;
    this.state.targetColumns = this.calculateTargetColumns(this.state.startColumns, clampedScale, gridWidth);

    this.onScaleUpdate?.(
      clampedScale,
      this.state.anchor.anchorCenterX,
      this.state.anchor.anchorCenterY,
    );
    this.onStateChange?.(this.state);
    return this.state;
  }

  public end(): PinchEndResult | null {
    if (!this.state) {
      return null;
    }

    const calcParams = new SwitchCalcParams();
    calcParams.startColumns = this.state.startColumns;
    calcParams.targetColumns = this.state.targetColumns;
    calcParams.startScrollOffset = this.state.startScrollOffset;
    calcParams.anchor = this.state.anchor;
    calcParams.gridWidth = this.state.gridWidth;
    calcParams.gridHeight = this.state.gridHeight;
    calcParams.topInset = this.state.topInset;

    const calcResult = HybridSwitchCalc.calcSwitch(calcParams);
    const result = new PinchEndResult();
    result.columns = this.state.targetColumns;
    result.scrollOffset = calcResult.scrollOffset;

    console.log(
      `[${this.tag}] Pinch ended: columns=${result.columns}, offset=${result.scrollOffset}, centerX=${calcResult.anchorCenterX}`,
    );

    this.state = null;
    return result;
  }

  private calculateTargetColumns(
    startColumns: number,
    scale: number,
    gridWidth: number,
  ): number {
    let targetColumns = startColumns;

    if (scale < 1.0 - this.config.scaleThreshold) {
      targetColumns = Math.min(this.maxColumns, Math.ceil(startColumns / scale));
    } else if (scale > 1.0 + this.config.scaleThreshold) {
      targetColumns = Math.max(this.minColumns, Math.floor(startColumns / scale));
    }

    return Math.max(this.minColumns, Math.min(this.maxColumns, targetColumns));
  }

  public getState(): PinchState | null {
    return this.state;
  }

  public isActive(): boolean {
    return this.state !== null && this.state.isActive;
  }

  public setOnStateChange(listener: (state: PinchState) => void): void {
    this.onStateChange = listener;
  }

  public setOnScaleUpdate(listener: (scale: number, centerX: number, centerY: number) => void): void {
    this.onScaleUpdate = listener;
  }

  public setOnColumnsChange(listener: (columns: number, scrollOffset: number) => void): void {
    this.onColumnsChange = listener;
  }

  public getConfig(): PinchAnimationConfig {
    return this.config;
  }

  public getAnimationDuration(isQuickPinch: boolean): number {
    return isQuickPinch ? this.config.quickPinchDuration : this.config.slowPinchDuration;
  }

  public getAnimationCurve(): Curve {
    return Curve.FastOutSlowIn;
  }
}
