import { IObserver, ObserverManager } from '../utils/ObserverManager';

/**
 * 状态变化观察者接口
 */
export interface IStateChangeObserver<S, E = string> extends IObserver {
  /**
   * 状态变化回调
   */
  onStateChange(oldState: S, newState: S, event?: E): void;
}

/**
 * 状态变化回调函数
 */
export type StateChangeCallback<S, E = string> = (oldState: S, newState: S, event?: E) => void;

/**
 * 状态观察者管理类
 */
export abstract class StateObserverManager<S, E = string> extends ObserverManager<IStateChangeObserver<S, E>> {
  /**
   * 初始状态值
   */
  private readonly _initState: S;

  protected constructor(persistentId: number, initState: S, tag?: string) {
    super(tag);
    this._persistentId = persistentId;
    this._initState = initState;
  }

  /**
   * 获取当前实例ID
   */
  public override get persistentId(): number {
    return this._persistentId ?? 0;
  }

  /**
   * 获取当前状态
   */
  public abstract get currentState(): S;

  /**
   * 获取初始状态
   */
  protected get initState(): S {
    return this._initState;
  }

  protected override doImmediatelyCallback(observer: IStateChangeObserver<S, E>): void {
    observer.onStateChange(this.initState, this.currentState);
  }
}
