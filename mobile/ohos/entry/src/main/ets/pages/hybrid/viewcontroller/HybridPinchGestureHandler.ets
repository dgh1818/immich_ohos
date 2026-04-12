import * as Shared from '../HybridPhotoGridShared';
import { PINCH_SPEED_THRESHOLD } from '../statemanager/constants/PinchDefine';
import { AnchorInfo, HybridSwitchCalc, SwitchCalcParams } from '../viewmodel/HybridSwitchCalc';
import { AnimationDuration, AnimationScale } from './animation/AnimationDefine';

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
  public lastScale: number = 1.0;
  public lastTimestamp: number = 0;
  public velocity: number = 0;
  public standardScales: number[] = [];
  public minAllowedScale: number = 1.0;
  public maxAllowedScale: number = 1.0;
}

export class PinchAnimationConfig {
  public pinchSpeedThreshold: number = PINCH_SPEED_THRESHOLD;
  public quickPinchDuration: number = AnimationDuration.QUICK_PINCH;
  public slowPinchDuration: number = AnimationDuration.SLOW_PINCH;
  public switchDuration: number = AnimationDuration.SWITCH;
  public minScale: number = AnimationScale.MIN_SCALE;
  public maxScale: number = AnimationScale.MAX_SCALE;
  public scaleThreshold: number = 0.02;
}

export class PinchEndResult {
  public columns: number = 0;
  public scrollOffset: number = 0;
  public anchorItemIndex: number = 0;
  public extraOffset: number = 0;
  public isQuickPinch: boolean = false;
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
    state.lastScale = 1.0;
    state.lastTimestamp = Date.now();
    state.velocity = 0;
    state.standardScales = this.createStandardScales(currentColumns);
    state.minAllowedScale = this.resolveMinAllowedScale(state.standardScales);
    state.maxAllowedScale = this.resolveMaxAllowedScale(state.standardScales);

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

    const clampedScale = Math.max(this.state.minAllowedScale, Math.min(this.state.maxAllowedScale, scale));
    const timestamp = Date.now();
    const deltaTime = Math.max(0, timestamp - this.state.lastTimestamp);
    const deltaScale = clampedScale - this.state.lastScale;
    if (deltaTime > 0 && Math.abs(deltaScale) > 0.0001) {
      this.state.velocity = (deltaScale * 100000) / deltaTime;
    }
    this.state.lastScale = clampedScale;
    this.state.lastTimestamp = timestamp;
    this.state.centerX = pinchCenterX;
    this.state.centerY = pinchCenterY;
    this.state.currentScale = clampedScale;
    this.state.targetColumns = this.calculateTargetColumns(
      this.state.startColumns,
      clampedScale,
      this.state.standardScales,
      this.state.targetColumns,
    );

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
    const scrollToIndexParams = HybridSwitchCalc.calcScrollToIndexParams(
      this.state.anchor,
      this.state.targetColumns,
      this.state.startScrollOffset,
      this.state.gridWidth,
      this.state.topInset,
    );
    const result = new PinchEndResult();
    result.columns = this.state.targetColumns;
    result.scrollOffset = calcResult.scrollOffset;
    result.anchorItemIndex = scrollToIndexParams.itemIndex;
    result.extraOffset = scrollToIndexParams.extraOffset;
    result.isQuickPinch = Math.abs(this.state.velocity) > this.config.pinchSpeedThreshold;

    console.log(
      `[${this.tag}] Pinch ended: columns=${result.columns}, offset=${result.scrollOffset}, ` +
        `index=${result.anchorItemIndex}, extraOffset=${result.extraOffset}, ` +
        `velocity=${this.state.velocity}, quick=${result.isQuickPinch}, centerX=${calcResult.anchorCenterX}`,
    );

    this.state = null;
    return result;
  }

  private calculateTargetColumns(
    startColumns: number,
    scale: number,
    standardScales: number[],
    currentTargetColumns: number,
  ): number {
    let targetColumns = Math.max(this.minColumns, Math.min(this.maxColumns, currentTargetColumns || startColumns));
    let closestDistance = Number.MAX_VALUE;

    for (let columns = this.minColumns; columns <= this.maxColumns; columns++) {
      const standardScale = standardScales[columns];
      if (standardScale <= 0) {
        continue;
      }

      const distance = Math.abs(scale - standardScale);
      if (distance + 0.000001 < closestDistance) {
        closestDistance = distance;
        targetColumns = columns;
        continue;
      }

      if (Math.abs(distance - closestDistance) <= 0.000001 && columns === currentTargetColumns) {
        targetColumns = columns;
      }
    }

    return Math.max(this.minColumns, Math.min(this.maxColumns, targetColumns));
  }

  private createStandardScales(startColumns: number): number[] {
    const standardScales: number[] = [];
    for (let columns = this.minColumns; columns <= this.maxColumns; columns++) {
      standardScales[columns] = startColumns / columns;
    }
    return standardScales;
  }

  private resolveMinAllowedScale(standardScales: number[]): number {
    let minStandardScale = Number.MAX_VALUE;
    for (let columns = this.minColumns; columns <= this.maxColumns; columns++) {
      const standardScale = standardScales[columns];
      if (standardScale > 0 && standardScale < minStandardScale) {
        minStandardScale = standardScale;
      }
    }

    if (minStandardScale === Number.MAX_VALUE) {
      return this.config.minScale;
    }
    return minStandardScale * this.config.minScale;
  }

  private resolveMaxAllowedScale(standardScales: number[]): number {
    let maxStandardScale = 0;
    for (let columns = this.minColumns; columns <= this.maxColumns; columns++) {
      const standardScale = standardScales[columns];
      if (standardScale > maxStandardScale) {
        maxStandardScale = standardScale;
      }
    }

    if (maxStandardScale <= 0) {
      return this.config.maxScale;
    }
    return maxStandardScale * this.config.maxScale;
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
