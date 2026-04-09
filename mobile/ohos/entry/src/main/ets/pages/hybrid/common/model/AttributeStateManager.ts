import { StateObserverManager } from './StateObserverManager';

/**
 * 属性状态管理类
 */
export class AttributeStateManager<S, E = string> extends StateObserverManager<S, E> {
  /**
   * 当前状态值
   */
  private _currentState: S;

  /**
   * 是否记录日志
   */
  private readonly _withLog: boolean;

  public constructor(persistentId: number, initState: S, tag?: string, withLog: boolean = true) {
    super(persistentId, initState, tag !== undefined ? (tag + 'Asm') : undefined);
    this._currentState = initState;
    this._withLog = withLog;
  }

  public override get currentState(): S {
    return this._currentState;
  }

  /**
   * 更新状态
   */
  public updateState(newState: S, reason?: E): void {
    if (newState !== undefined && this._currentState !== newState) {
      const oldState: S = this._currentState;
      this._currentState = newState;
      if (this._withLog) {
        console.info(`[${this.tag}] updateState: <${this.logState(oldState)} -> ${this.logState(newState)}>, reason: ${this.logReason(reason)}`);
      }
      this.callbackObservers(observer => observer.onStateChange(oldState, newState, reason));
    }
  }

  /**
   * 记录状态
   */
  protected logState(state: S): string {
    return `${state}`;
  }

  /**
   * 记录原因
   */
  protected logReason(reason?: E): string {
    return `${reason ?? 'unknown'}`;
  }
}
