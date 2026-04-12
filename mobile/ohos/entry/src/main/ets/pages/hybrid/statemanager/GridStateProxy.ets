import { IDisplayConfig } from './config/DisplayConfig';
import { IGridConfig } from './config/GridConfig';
import { PinchConfig, IPinchConfig } from './config/PinchConfig';
import { IScrollerConfig } from './config/ScrollerConfig';
import { ISwitchConfig } from './config/SwitchConfig';
import { DisplayStateManager } from './DisplayStateManager';
import { GridFormFsm } from './GridFormFsm';
import { GridStateManager } from './GridStateManager';
import { PinchStateManager } from './PinchStateManager';
import { ScrollerStateManager } from './ScrollerStateManager';
import { SwitchStateManager } from './SwitchStateManager';

export interface GridStateProxyInitConfig {
  gridConfig?: IGridConfig;
  switchConfig?: ISwitchConfig;
  scrollerConfig?: IScrollerConfig;
  displayConfig?: IDisplayConfig;
  pinchConfig?: IPinchConfig;
}

export class GridStateProxy {
  private static readonly INSTANCES: Map<number, GridStateProxy> = new Map<number, GridStateProxy>();
  private static nextId: number = 1;

  public static getNewProxyId(): number {
    const persistentId = GridStateProxy.nextId;
    GridStateProxy.nextId += 1;
    return persistentId;
  }

  public static getInstance(persistentId: number): GridStateProxy {
    const existingInstance = GridStateProxy.INSTANCES.get(persistentId);
    if (existingInstance) {
      return existingInstance;
    }
    const nextInstance = new GridStateProxy(persistentId);
    GridStateProxy.INSTANCES.set(persistentId, nextInstance);
    return nextInstance;
  }

  public static checkInstance(persistentId: number): boolean {
    return GridStateProxy.INSTANCES.has(persistentId);
  }

  public static releaseInstance(persistentId: number): void {
    const instance = GridStateProxy.INSTANCES.get(persistentId);
    if (!instance) {
      return;
    }
    instance.release();
    GridStateProxy.INSTANCES.delete(persistentId);
  }

  public readonly persistentId: number;
  public readonly formFsm: GridFormFsm;
  public readonly displayStateManager: DisplayStateManager;
  public readonly gridStateManager: GridStateManager;
  public readonly switchStateManager: SwitchStateManager;
  public readonly pinchStateManager: PinchStateManager;
  public readonly scrollerStateManager: ScrollerStateManager;
  public readonly pinchConfig: PinchConfig = new PinchConfig();

  private constructor(persistentId: number) {
    this.persistentId = persistentId;
    this.formFsm = new GridFormFsm(persistentId);
    this.displayStateManager = new DisplayStateManager(persistentId);
    this.gridStateManager = new GridStateManager(persistentId, this.formFsm, this.displayStateManager);
    this.switchStateManager = new SwitchStateManager(persistentId);
    this.pinchStateManager = new PinchStateManager(persistentId, this.formFsm);
    this.scrollerStateManager = new ScrollerStateManager(persistentId);
  }

  public init(config?: GridStateProxyInitConfig): void {
    this.displayStateManager.init(config?.displayConfig as IDisplayConfig | undefined);
    this.gridStateManager.init(config?.gridConfig as IGridConfig | undefined);
    this.switchStateManager.init(config?.switchConfig as ISwitchConfig | undefined);
    this.scrollerStateManager.init(config?.scrollerConfig as IScrollerConfig | undefined);
    this.pinchConfig.init(config?.pinchConfig);
  }

  public release(): void {
    this.pinchConfig.release();
    this.scrollerStateManager.release();
    this.switchStateManager.release();
    this.gridStateManager.release();
    this.displayStateManager.release();
    this.pinchStateManager.release();
    this.formFsm.release();
  }
}
