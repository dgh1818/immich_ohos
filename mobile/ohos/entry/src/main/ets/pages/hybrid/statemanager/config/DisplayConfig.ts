import { AbstractConfig } from '../../common/model/AbstractConfig';
import { DEFAULT_BOTTOM_AVOID_HEIGHT, DEFAULT_TOP_AVOID_HEIGHT } from '../constants/DisplayDefine';

export interface GridAreaSize {
  width: number;
  height: number;
}

export interface IDisplayVariableConfig {
  areaSize?: GridAreaSize;
  isGridShow?: boolean;
  isGridActive?: boolean;
  isHorizontal?: boolean;
  bottomAvoidHeight?: number;
  topAvoidHeight?: number;
}

export interface IDisplayConfig extends IDisplayVariableConfig {}

export class DisplayConfig extends AbstractConfig<IDisplayConfig> implements IDisplayConfig {
  private areaSizeValue: GridAreaSize = { width: 0, height: 0 };
  private gridShowValue: boolean = true;
  private gridActiveValue: boolean = true;
  private horizontalValue: boolean = false;
  private bottomAvoidHeightValue: number = DEFAULT_BOTTOM_AVOID_HEIGHT;
  private topAvoidHeightValue: number = DEFAULT_TOP_AVOID_HEIGHT;

  public get areaSize(): GridAreaSize {
    return { width: this.areaSizeValue.width, height: this.areaSizeValue.height };
  }

  public get isGridShow(): boolean {
    return this.gridShowValue;
  }

  public get isGridActive(): boolean {
    return this.gridActiveValue;
  }

  public get isHorizontal(): boolean {
    return this.horizontalValue;
  }

  public get bottomAvoidHeight(): number {
    return this.bottomAvoidHeightValue;
  }

  public get topAvoidHeight(): number {
    return this.topAvoidHeightValue;
  }

  protected override doInit(config?: IDisplayConfig): void {
    this.areaSizeValue = this.getValue(config?.areaSize, this.areaSizeValue);
    this.gridShowValue = this.getValue(config?.isGridShow, true);
    this.gridActiveValue = this.getValue(config?.isGridActive, true);
    this.horizontalValue = this.getValue(config?.isHorizontal, false);
    this.bottomAvoidHeightValue = this.getValue(config?.bottomAvoidHeight, DEFAULT_BOTTOM_AVOID_HEIGHT);
    this.topAvoidHeightValue = this.getValue(config?.topAvoidHeight, DEFAULT_TOP_AVOID_HEIGHT);
  }
}
