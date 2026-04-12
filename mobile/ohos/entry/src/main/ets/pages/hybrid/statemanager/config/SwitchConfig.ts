import { AbstractConfig } from '../../common/model/AbstractConfig';
import { SwitchMode } from '../constants/SwitchDefine';

export interface ISwitchVariableConfig {
  switchMode?: SwitchMode;
  isSwitching?: boolean;
}

export interface ISwitchConfig extends ISwitchVariableConfig {
  isSupportSwitch?: boolean;
}

export class SwitchConfig extends AbstractConfig<ISwitchConfig> implements ISwitchConfig {
  private supportSwitchValue: boolean = true;
  private switchModeValue: SwitchMode = SwitchMode.NORMAL;
  private switchingValue: boolean = false;

  public get isSupportSwitch(): boolean {
    return this.supportSwitchValue;
  }

  public get switchMode(): SwitchMode {
    return this.switchModeValue;
  }

  public get isSwitching(): boolean {
    return this.switchingValue;
  }

  protected override doInit(config?: ISwitchConfig): void {
    this.supportSwitchValue = this.getValue(config?.isSupportSwitch, true);
    this.switchModeValue = this.getValue(config?.switchMode, SwitchMode.NORMAL);
    this.switchingValue = this.getValue(config?.isSwitching, false);
  }
}
