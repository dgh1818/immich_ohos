import { AbstractInitialAble } from './AbstractInitialAble';

const ONLY_ONE_OBSERVER: number = 1;
const NO_OBSERVER: number = 0;

/**
 * 观察者接口
 */
export interface IObserver {
}

/**
 * 观察者管理器接口
 */
export interface IObserverManager<E extends IObserver> {
  /**
   * 注册观察者
   */
  registerObserver(observer: E): void;

  /**
   * 注销观察者
   */
  unRegisterObserver(observer: E): void;
}

/**
 * 观察者管理类
 */
export class ObserverManager<E extends IObserver, T = number> extends AbstractInitialAble<T>
  implements IObserverManager<E> {
  /**
   * 观察者列表
   */
  private readonly _observers: Set<E> = new Set<E>();

  /**
   * 注册观察者
   */
  public registerObserver(observer: E, isCallbackImmediately: boolean = false): void {
    this._observers.add(observer);
    if (this.observerSize === ONLY_ONE_OBSERVER) {
      this.onObserverStateChange?.(true);
    }
    if (isCallbackImmediately) {
      this.doImmediatelyCallback?.(observer);
    }
  }

  /**
   * 注销观察者
   */
  public unRegisterObserver(observer: E): void {
    if (this._observers.delete(observer)) {
      if (this.observerSize === NO_OBSERVER) {
        this.onObserverStateChange?.(false);
      }
    }
  }

  protected override doInit(param?: T): void {
    if (this._persistentId !== undefined || param === undefined) {
      return;
    }
    if (param instanceof AbstractInitialAble) {
      this._persistentId = param.persistentId;
    } else {
      this._persistentId = param as number;
    }
  }

  protected override doRelease(): void {
    this._observers.clear();
  }

  /**
   * 判断是否有观察者
   */
  protected hasObserver(): boolean {
    return this._observers.size > 0;
  }

  /**
   * 获取观察者数目
   */
  protected get observerSize(): number {
    return this._observers.size;
  }

  /**
   * 执行立即回调
   */
  protected doImmediatelyCallback?(observer: E): void;

  /**
   * 有无观察者状态变更回调
   */
  protected onObserverStateChange?(hasObserver: boolean): void;

  /**
   * 回调监听者
   */
  protected callbackObservers(callback: (observer: E) => void): void {
    if (this.hasObserver()) {
      this._observers.forEach(observer => callback(observer));
    }
  }
}
