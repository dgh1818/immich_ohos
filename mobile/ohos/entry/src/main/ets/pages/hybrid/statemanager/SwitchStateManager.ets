import { AttributeStateManager } from '../common/model/AttributeStateManager';
import { ConfigObserverProxy } from '../common/model/ConfigObserverProxy';
import { ConfigStateManager } from '../common/model/ConfigStateManager';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { FormIndex } from './constants/GridDefine';
import { SwitchConfig, ISwitchConfig, ISwitchVariableConfig } from './config/SwitchConfig';
import { SwitchMode } from './constants/SwitchDefine';

export class SwitchObserverProxy extends ConfigObserverProxy<SwitchStateManager, SwitchConfig> {
  public constructor(getProxyFunc: (persistentId: number) => SwitchStateManager) {
    super(getProxyFunc, 'SwitchObserverProxy');
  }

  public getIsSwitching(callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.isSwitchingAsm, callback);
  }

  public getSwitchMode(callback?: StateChangeCallback<SwitchMode>): SwitchMode {
    return this.getState<SwitchMode>(this.proxy.switchModeAsm, callback);
  }

  public getTransitionFromForm(callback?: StateChangeCallback<FormIndex>): FormIndex {
    return this.getState<FormIndex>(this.proxy.transitionFromFormAsm, callback);
  }

  public getTransitionToForm(callback?: StateChangeCallback<FormIndex>): FormIndex {
    return this.getState<FormIndex>(this.proxy.transitionToFormAsm, callback);
  }
}

export class SwitchStateManager
  extends ConfigStateManager<SwitchConfig, ISwitchConfig, ISwitchVariableConfig> {
  public override readonly config: SwitchConfig = new SwitchConfig();

  public readonly isSwitchingAsm: AttributeStateManager<boolean>;
  public readonly switchModeAsm: AttributeStateManager<SwitchMode>;
  public readonly transitionFromFormAsm: AttributeStateManager<FormIndex>;
  public readonly transitionToFormAsm: AttributeStateManager<FormIndex>;

  public constructor(persistentId: number) {
    super(persistentId, 'SwitchStateManager');
    this.isSwitchingAsm = new AttributeStateManager<boolean>(persistentId, false, 'IsSwitching');
    this.switchModeAsm = new AttributeStateManager<SwitchMode>(persistentId, SwitchMode.NORMAL, 'SwitchMode');
    this.transitionFromFormAsm = new AttributeStateManager<FormIndex>(
      persistentId,
      FormIndex.DAY,
      'TransitionFromForm',
    );
    this.transitionToFormAsm = new AttributeStateManager<FormIndex>(
      persistentId,
      FormIndex.DAY,
      'TransitionToForm',
    );
  }

  public updateTransitionState(
    isSwitching: boolean,
    fromForm: FormIndex,
    toForm: FormIndex,
    reason?: string,
  ): void {
    this.isSwitchingAsm.updateState(isSwitching, reason);
    this.transitionFromFormAsm.updateState(fromForm, reason);
    this.transitionToFormAsm.updateState(toForm, reason);
  }

  public override updateStateFromVariableConfig(config?: ISwitchVariableConfig, reason?: string): void {
    if (!config) {
      return;
    }
    if (config.switchMode !== undefined) {
      this.switchModeAsm.updateState(config.switchMode, reason);
    }
    if (config.isSwitching !== undefined) {
      this.isSwitchingAsm.updateState(config.isSwitching, reason);
    }
  }

  protected override updateStateFromInitConfig(config: SwitchConfig, reason?: string): void {
    this.updateStateFromVariableConfig(config, reason);
  }
}
