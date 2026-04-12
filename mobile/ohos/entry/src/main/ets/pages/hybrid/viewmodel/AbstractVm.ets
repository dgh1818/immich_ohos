import { GridStateObserverProxy } from '../statemanager/GridStateObserverProxy';
import { GridStateProxy } from '../statemanager/GridStateProxy';
import { DisplayStateManager } from '../statemanager/DisplayStateManager';
import { GridStateManager } from '../statemanager/GridStateManager';
import { ScrollerStateManager } from '../statemanager/ScrollerStateManager';
import { SwitchStateManager } from '../statemanager/SwitchStateManager';

export class AbstractVm extends GridStateObserverProxy {
  public constructor(tag?: string) {
    super(tag ?? 'AbstractVm');
  }

  public bindStateProxy(stateProxy: GridStateProxy): void {
    if (this.persistentId === stateProxy.persistentId) {
      return;
    }
    this.release();
    this.init(stateProxy.persistentId);
  }

  protected get stateProxy(): GridStateProxy {
    return this.proxy;
  }

  protected get gridStateManager(): GridStateManager {
    return this.proxy.gridStateManager;
  }

  protected get switchStateManager(): SwitchStateManager {
    return this.proxy.switchStateManager;
  }

  protected get displayStateManager(): DisplayStateManager {
    return this.proxy.displayStateManager;
  }

  protected get scrollerStateManager(): ScrollerStateManager {
    return this.proxy.scrollerStateManager;
  }
}
