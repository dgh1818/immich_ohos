import { AttributeStateManager } from '../common/model/AttributeStateManager';
import { ConfigObserverProxy } from '../common/model/ConfigObserverProxy';
import { ConfigStateManager } from '../common/model/ConfigStateManager';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { DisplayConfig, GridAreaSize, IDisplayConfig, IDisplayVariableConfig } from './config/DisplayConfig';

export class DisplayObserverProxy extends ConfigObserverProxy<DisplayStateManager, DisplayConfig> {
  public constructor(getProxyFunc: (persistentId: number) => DisplayStateManager) {
    super(getProxyFunc, 'DisplayObserverProxy');
  }

  public getIsGridShow(callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.gridShowAsm, callback);
  }

  public getIsGridActive(callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.gridActiveAsm, callback);
  }

  public getIsHorizontal(callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.horizontalAsm, callback);
  }

  public getBottomAvoidHeight(callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.bottomAvoidHeightAsm, callback);
  }

  public getTopAvoidHeight(callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.topAvoidHeightAsm, callback);
  }

  public getGridAreaSize(callback?: StateChangeCallback<GridAreaSize>): GridAreaSize {
    return this.getState<GridAreaSize>(this.proxy.gridAreaSizeAsm, callback);
  }
}

export class DisplayStateManager
  extends ConfigStateManager<DisplayConfig, IDisplayConfig, IDisplayVariableConfig> {
  public override readonly config: DisplayConfig = new DisplayConfig();

  public readonly gridShowAsm: AttributeStateManager<boolean>;
  public readonly gridActiveAsm: AttributeStateManager<boolean>;
  public readonly horizontalAsm: AttributeStateManager<boolean>;
  public readonly bottomAvoidHeightAsm: AttributeStateManager<number>;
  public readonly topAvoidHeightAsm: AttributeStateManager<number>;
  public readonly gridAreaSizeAsm: AttributeStateManager<GridAreaSize>;

  public constructor(persistentId: number) {
    super(persistentId, 'DisplayStateManager');
    this.gridShowAsm = new AttributeStateManager<boolean>(persistentId, true, 'GridShow');
    this.gridActiveAsm = new AttributeStateManager<boolean>(persistentId, true, 'GridActive');
    this.horizontalAsm = new AttributeStateManager<boolean>(persistentId, false, 'GridHorizontal');
    this.bottomAvoidHeightAsm = new AttributeStateManager<number>(persistentId, 0, 'BottomAvoidHeight');
    this.topAvoidHeightAsm = new AttributeStateManager<number>(persistentId, 56, 'TopAvoidHeight');
    this.gridAreaSizeAsm = new AttributeStateManager<GridAreaSize>(
      persistentId,
      { width: 0, height: 0 },
      'GridAreaSize',
    );
  }

  public override updateStateFromVariableConfig(config?: IDisplayVariableConfig, reason?: string): void {
    if (!config) {
      return;
    }
    if (config.areaSize) {
      this.gridAreaSizeAsm.updateState(config.areaSize, reason);
    }
    if (config.isGridShow !== undefined) {
      this.gridShowAsm.updateState(config.isGridShow, reason);
    }
    if (config.isGridActive !== undefined) {
      this.gridActiveAsm.updateState(config.isGridActive, reason);
    }
    if (config.isHorizontal !== undefined) {
      this.horizontalAsm.updateState(config.isHorizontal, reason);
    }
    if (config.bottomAvoidHeight !== undefined) {
      this.bottomAvoidHeightAsm.updateState(config.bottomAvoidHeight, reason);
    }
    if (config.topAvoidHeight !== undefined) {
      this.topAvoidHeightAsm.updateState(config.topAvoidHeight, reason);
    }
  }

  protected override updateStateFromInitConfig(config: DisplayConfig, reason?: string): void {
    this.updateStateFromVariableConfig(config, reason);
  }
}
