import { AbstractInitialAble } from '../utils/AbstractInitialAble';
import { IObserver, ObserverManager } from '../utils/ObserverManager';
import { IStateChangeObserver, StateChangeCallback, StateObserverManager } from './StateObserverManager';

class ObserverWrapper<S, E = string> extends AbstractInitialAble {
  private readonly observer: IStateChangeObserver<S, E>;
  private readonly observerManager: StateObserverManager<S, E>;
  private readonly callbackFn: StateChangeCallback<S, E>;
  private readonly callbackImmediately: boolean;

  public constructor(
    observerManager: StateObserverManager<S, E>,
    callbackFn: StateChangeCallback<S, E>,
    callbackImmediately: boolean = true,
  ) {
    super();
    this.observer = { onStateChange: callbackFn };
    this.observerManager = observerManager;
    this.callbackFn = callbackFn;
    this.callbackImmediately = callbackImmediately;
  }

  public get callback(): Function {
    return this.callbackFn;
  }

  protected override doInit(): void {
    this.observerManager.registerObserver(this.observer, this.callbackImmediately);
  }

  protected override doRelease(): void {
    this.observerManager.unRegisterObserver(this.observer);
  }
}

export abstract class AbstractObserverProxy<P, T = number, E = number | string>
  extends ObserverManager<ObserverWrapper<IObserver, E>, T> {
  protected readonly getProxyFunc: (persistentId: number) => P;

  public constructor(getProxyFunc: (persistentId: number) => P, tag?: string) {
    super(tag);
    this.getProxyFunc = getProxyFunc;
  }

  public releaseCallback<S>(callback: StateChangeCallback<S, E>): void {
    this.callbackObservers((observerProxy: ObserverWrapper<IObserver, E>): void => {
      if (observerProxy.callback === callback) {
        observerProxy.release();
        this.unRegisterObserver(observerProxy);
      }
    });
  }

  protected get proxy(): P {
    return this.getProxyFunc(this.persistentId);
  }

  protected getState<S>(
    observerManager: StateObserverManager<S, E>,
    callback?: StateChangeCallback<S, E>,
    callbackImmediately: boolean = true,
  ): S {
    const currentState: S = observerManager.currentState;
    if (callback) {
      const observerProxy = new ObserverWrapper<S, E>(observerManager, callback, callbackImmediately);
      observerProxy.init();
      this.registerObserver(observerProxy as unknown as ObserverWrapper<IObserver, E>);
    }
    return currentState;
  }

  protected override doRelease(): void {
    this.callbackObservers((observerProxy: ObserverWrapper<IObserver, E>): void => {
      observerProxy.release();
      this.unRegisterObserver(observerProxy);
    });
    super.doRelease();
  }
}
