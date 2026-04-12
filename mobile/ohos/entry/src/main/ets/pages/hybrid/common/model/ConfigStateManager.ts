import { IObserver, ObserverManager } from '../utils/ObserverManager';
import { AbstractConfig } from './AbstractConfig';

export interface IGetConfig<C> {
  get config(): C;
}

export abstract class ConfigStateManager<C extends AbstractConfig<T>, T, V, L = IObserver>
  extends ObserverManager<L, T> implements IGetConfig<C> {
  public abstract readonly config: C;

  public constructor(persistentId: number, tag?: string) {
    super(tag);
    this._persistentId = persistentId;
  }

  public abstract updateStateFromVariableConfig(config?: V, reason?: string): void;

  protected abstract updateStateFromInitConfig(config: C, reason?: string): void;

  protected override doInit(config?: T): void {
    super.doInit(config);
    this.config.setPersistentId(this.persistentId);
    this.config.init(config);
    this.updateStateFromInitConfig(this.config, 'initConfig');
  }

  protected override doRelease(): void {
    this.config.release();
    super.doRelease();
  }
}
