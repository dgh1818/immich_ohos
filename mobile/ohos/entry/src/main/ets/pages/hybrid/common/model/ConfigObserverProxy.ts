import { IObserverManager } from '../utils/ObserverManager';
import { AbstractObserverProxy } from './AbstractObserverProxy';
import { IGetConfig } from './ConfigStateManager';

export interface IObserverGetConfig<C, L> extends IGetConfig<C>, IObserverManager<L> {}

export class ConfigObserverProxy<P extends IGetConfig<C>, C> extends AbstractObserverProxy<P>
  implements IGetConfig<C> {
  public get config(): C {
    return this.proxy.config;
  }
}

export class ConfigListenerObserverProxy<P extends IObserverGetConfig<C, L>, C, L>
  extends ConfigObserverProxy<P, C> {
  private readonly listeners: Set<L> = new Set<L>();

  public registerEventListener(listener: L): void {
    this.listeners.add(listener);
    this.proxy.registerObserver(listener);
  }

  public unRegisterEventListener(listener: L): void {
    this.listeners.delete(listener);
    this.proxy.unRegisterObserver(listener);
  }

  protected override doRelease(): void {
    if (this.listeners.size > 0) {
      for (const listener of this.listeners) {
        this.proxy.unRegisterObserver(listener);
      }
      this.listeners.clear();
    }
    super.doRelease();
  }
}
