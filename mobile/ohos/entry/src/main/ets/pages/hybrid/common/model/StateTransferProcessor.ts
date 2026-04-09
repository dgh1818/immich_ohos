import { IStateChangeObserver } from './StateObserverManager';
import { ObserverManager } from '../utils/ObserverManager';

/**
 * 状态转移动作
 */
export interface StateTransferAction<S, E> {
  /**
   * 动作名称
   */
  actionName?: string;

  /**
   * 判断状态转移是否匹配
   */
  isStateTransferMatched: (oldState: S, newState: S, event?: E) => boolean;

  /**
   * 是否需要动效
   */
  isNeedAnimation?: () => boolean;

  /**
   * 是否立即执行动画
   */
  isAnimateImmediately?: (oldState: S, newState: S, event?: E) => boolean;

  /**
   * 动效参数：不设置即表示状态转移时不需要动效
   */
  animationParam?: (oldState: S, newState: S, event?: E) => AnimateParam | undefined;

  /**
   * 动效前准备动作
   */
  prepareAction?: (oldState: S, newState: S, event?: E) => void;

  /**
   * 目标动作
   */
  targetAction?: (oldState: S, newState: S, event?: E) => void;
}

/**
 * 状态转移执行器
 */
export class StateTransferProcessor<S, E> extends ObserverManager<StateTransferAction<S, E>>
  implements IStateChangeObserver<S, E> {
  
  private observerStateListener?: (hasObserver: boolean) => void;

  public onStateChange(oldState: S, newState: S, event?: E): void {
    if (!this.hasObserver()) {
      return;
    }
    const matchedActions: string[] = [];
    this.callbackObservers(stateTransferAction => {
      if (stateTransferAction.isStateTransferMatched(oldState, newState, event)) {
        this.doStateTransferAction(stateTransferAction, oldState, newState, event);
        if (stateTransferAction.actionName) {
          matchedActions.push(stateTransferAction.actionName);
        }
      }
    });
    if (matchedActions.length > 0) {
      this.logTransition?.(matchedActions, oldState, newState, event);
    }
  }

  /**
   * 设置观察者状态监听器
   */
  public setObserverStateListener(observerStateListener?: (hasObserver: boolean) => void): void {
    this.observerStateListener = observerStateListener;
  }

  /**
   * 记录匹配信息
   */
  protected logTransition?(matchedActions: string[], oldState: S, newState: S, event?: E): void;

  protected override doInit(persistentId?: number): void {
    super.doInit(persistentId);
    this._persistentId = persistentId;
  }

  protected override onObserverStateChange(hasObserver: boolean): void {
    this.observerStateListener?.(hasObserver);
  }

  private doStateTransferAction(action: StateTransferAction<S, E>, oldState: S, newState: S, event?: E): void {
    action.prepareAction?.(oldState, newState, event);
    const animateParam: AnimateParam | undefined = action.animationParam?.(oldState, newState, event);
    if ((!action.isNeedAnimation || action.isNeedAnimation()) && animateParam) {
      if (action.isAnimateImmediately?.(oldState, newState, event) === true) {
        animateToImmediately(animateParam, () => action.targetAction?.(oldState, newState, event));
      } else {
        animateTo(animateParam, () => action.targetAction?.(oldState, newState, event));
      }
    } else {
      action.targetAction?.(oldState, newState, event);
    }
  }
}
