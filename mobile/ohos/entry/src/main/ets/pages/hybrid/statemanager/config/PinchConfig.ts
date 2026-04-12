import { AbstractConfig } from '../../common/model/AbstractConfig';
import { PINCH_SPEED_THRESHOLD } from '../constants/PinchDefine';

export interface IPinchVariableConfig {
  pinchSpeedThreshold?: number;
}

export interface IPinchConfig extends IPinchVariableConfig {
  isSupportPinch?: boolean;
}

export class PinchConfig extends AbstractConfig<IPinchConfig> implements IPinchConfig {
  private supportPinchValue: boolean = true;
  private pinchSpeedThresholdValue: number = PINCH_SPEED_THRESHOLD;

  public get isSupportPinch(): boolean {
    return this.supportPinchValue;
  }

  public get pinchSpeedThreshold(): number {
    return this.pinchSpeedThresholdValue;
  }

  protected override doInit(config?: IPinchConfig): void {
    this.supportPinchValue = this.getValue(config?.isSupportPinch, true);
    this.pinchSpeedThresholdValue = this.getValue(
      config?.pinchSpeedThreshold,
      PINCH_SPEED_THRESHOLD,
      (value: number | undefined): boolean => (value ?? 0) > 0,
    );
  }
}
