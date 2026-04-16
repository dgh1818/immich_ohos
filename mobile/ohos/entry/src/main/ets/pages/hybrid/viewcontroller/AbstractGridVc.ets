import { StateTransferProcessor } from '../common/model/StateTransferProcessor';
import { AnimationCurve, AnimationDuration, AnimationOpacity } from './animation/AnimationDefine';
import { AbstractFormVc } from './AbstractFormVc';
import { GridAttributeUpdater } from './GridAttributeUpdater';
import { FormIndex } from '../statemanager/constants/GridDefine';
import { PinchStateManager, PinchEventListener, PinchObserverProxy } from '../statemanager/PinchStateManager';
import { GridFormFsm, FormStateType, FormEventType, FormStateTypeUtils, FormEventTypeUtils } from '../statemanager/GridFormFsm';
import { PinchAction, PinchDirection } from '../statemanager/constants/PinchDefine';

/**
 * 抽象宫格控制器
 * 
 * 核心职责：
 * 1. 监听状态机状态变化
 * 2. 使用 StateTransferProcessor 注册状态转换动作
 * 3. 协调 scale/opacity/zIndex 动画
 */
export abstract class AbstractGridVc extends AbstractFormVc implements PinchEventListener {
  /**
   * 宫格形态
   */

  /**
   * 状态机
   */
  protected readonly formFsm: GridFormFsm;

  /**
   * 捏合状态管理器
   */
  protected readonly pinchStateManager: PinchStateManager;

  /**
   * 捏合观察者代理
   */
  protected readonly pinchObserverProxy: PinchObserverProxy;

  /**
   * 属性更新器
   */
  protected readonly attributeUpdater: GridAttributeUpdater;

  /**
   * 状态转移处理器
   */
  protected readonly formStp: StateTransferProcessor<FormStateType, FormEventType>;

  /**
   * 是否已初始化
   */
  protected isInitialized: boolean = false;

  protected switchAnimationEndCallback?: (gridForm: FormIndex) => void;

  public constructor(
    gridForm: FormIndex,
    formFsm: GridFormFsm,
    pinchStateManager: PinchStateManager,
    attributeUpdater?: GridAttributeUpdater
  ) {
    super(gridForm, `AbstractGridVc_${FormIndex[gridForm]}`);
    this.formFsm = formFsm;
    this.pinchStateManager = pinchStateManager;
    this.pinchObserverProxy = new PinchObserverProxy(pinchStateManager);
    this.attributeUpdater = attributeUpdater ?? new GridAttributeUpdater();
    this.formStp = new StateTransferProcessor<FormStateType, FormEventType>();
  }

  /**
   * 初始化
   */
  public init(): void {
    if (this.isInitialized) {
      return;
    }
    this.isInitialized = true;

    // 先注册动作，避免初始状态同步时丢失 transition 处理
    this.registerActions();
    this.registerAnimationListeners();

    this.formFsm.registerObserver(this.formStp, true);
    this.pinchStateManager.addListener(this);
  }

  /**
   * 销毁
   */
  public destroy(): void {
    this.pinchStateManager.removeListener(this);
    this.formFsm.unRegisterObserver(this.formStp);
    this.formStp.release();
    this.isInitialized = false;
  }

  /**
   * 注册状态转换动作
   */
  protected registerActions(): void {
    this.registerFollowHandArriveAction();
    this.registerFollowHandLeaveAction();
    this.registerLeaveHandAction();
    this.registerSwitchArriveScaleAction();
    this.registerSwitchArriveOpacityAction();
    this.registerSwitchLeaveScaleAction();
    this.registerSwitchLeaveOpacityAction();
    this.registerSwitchOverAction();
  }

  /**
   * 跟手到达动作
   */
  protected registerFollowHandArriveAction(): void {
    this.formStp.registerObserver({
      actionName: 'FollowHandArrive',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isPinchEvent(event) &&
           !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               FormStateTypeUtils.isInFollowHandState(newState);
      },
      isAnimateImmediately: () => true,
      animationParam: (_oldState, _newState, event) => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.SHARP_CURVE,
        duration: FormEventTypeUtils.isQuickPinchEvent(event) ?
          AnimationDuration.QUICK_PINCH : AnimationDuration.SLOW_PINCH,
      }),
      prepareAction: () => {
        this.attributeUpdater.restoreZIndex();
        this.attributeUpdater.updateHitTestMode(HitTestMode.Default);
        this.attributeUpdater.updateShowBackground(true);
      },
      targetAction: () => {
        this.updateGridOpacity(true);
      },
    });
  }

  /**
   * 跟手离开动作
   */
  protected registerFollowHandLeaveAction(): void {
    this.formStp.registerObserver({
      actionName: 'FollowHandLeave',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isPinchEvent(event) &&
           FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFollowHandState(oldState) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               FormStateTypeUtils.isInFollowHandState(newState);
      },
      isAnimateImmediately: () => true,
      animationParam: (_oldState, _newState, event) => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.SHARP_CURVE,
        duration: FormEventTypeUtils.isQuickPinchEvent(event) ?
          AnimationDuration.QUICK_PINCH : AnimationDuration.SLOW_PINCH,
      }),
      prepareAction: () => {
        this.attributeUpdater.updateEnable(false);
        this.attributeUpdater.updateHitTestMode(HitTestMode.None);
        this.attributeUpdater.updateShowBackground(false);
      },
      targetAction: () => {
        this.updateGridOpacity(false);
      },
    });
  }

  /**
   * 离手动作
   */
  protected registerLeaveHandAction(): void {
    this.formStp.registerObserver({
      actionName: 'LeaveHand',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isPinchEvent(event) &&
           FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
           FormStateTypeUtils.isInFollowHandState(oldState) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      isAnimateImmediately: () => true,
      animationParam: (_oldState, newState, _event) => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.LEAVE_HAND_CURVE,
        onFinish: () => {
          if (FormStateTypeUtils.isInFormState(newState, this.gridForm)) {
            this.onPinchAnimationEnd();
          }
          this.attributeUpdater.updateShowBackground(false);
        },
      }),
      prepareAction: (oldState, newState) => {
        if (!FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
          FormStateTypeUtils.isInFormState(newState, this.gridForm)) {
          this.attributeUpdater.restoreZIndex();
          this.updateGridOpacity(true);
        }
      },
      targetAction: () => {
        this.updateScaleToTarget();
      },
    });
  }

  /**
   * 切换到达缩放动作
   */
  protected registerSwitchArriveScaleAction(): void {
    this.formStp.registerObserver({
      actionName: 'SwitchArriveScale',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isSwitchEvent(event) &&
           !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.LEAVE_HAND_CURVE,
        onFinish: () => {
          this.onSwitchAnimationEnd();
        },
      }),
      targetAction: () => {
        this.updateScaleToTarget();
      },
    });
  }

  /**
   * 切换到达透明度动作
   */
  protected registerSwitchArriveOpacityAction(): void {
    this.formStp.registerObserver({
      actionName: 'SwitchArriveOpacity',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isSwitchEvent(event) &&
           !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.SHARP_CURVE,
        duration: AnimationDuration.SWITCH,
      }),
      prepareAction: () => {
        this.attributeUpdater.restoreZIndex();
        this.attributeUpdater.updateHitTestMode(HitTestMode.Default);
        this.attributeUpdater.updateShowBackground(true);
      },
      targetAction: () => {
        this.updateGridOpacity(true);
      },
    });
  }

  /**
   * 切换离开缩放动作
   */
  protected registerSwitchLeaveScaleAction(): void {
    this.formStp.registerObserver({
      actionName: 'SwitchLeaveScale',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isSwitchEvent(event) &&
           FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.LEAVE_HAND_CURVE,
      }),
      targetAction: () => {
        this.updateScaleToTarget();
      },
    });
  }

  /**
   * 切换离开透明度动作
   */
  protected registerSwitchLeaveOpacityAction(): void {
    this.formStp.registerObserver({
      actionName: 'SwitchLeaveOpacity',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isSwitchEvent(event) &&
           FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        finishCallbackType: FinishCallbackType.LOGICALLY,
        curve: AnimationCurve.SHARP_CURVE,
        duration: AnimationDuration.SWITCH,
        onFinish: () => {
          this.attributeUpdater.setLowZIndex();
        },
      }),
      prepareAction: () => {
        this.attributeUpdater.updateEnable(false);
        this.attributeUpdater.updateHitTestMode(HitTestMode.None);
        this.attributeUpdater.updateShowBackground(false);
      },
      targetAction: () => {
        this.updateGridOpacity(false);
      },
    });
  }

  /**
   * 跨层切换动作
   */
  protected registerSwitchOverAction(): void {
    this.formStp.registerObserver({
      actionName: 'SwitchOver',
      isStateTransferMatched: (oldState, newState, event) => {
         return FormEventTypeUtils.isSwitchEvent(event) &&
           FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      prepareAction: () => {
        this.attributeUpdater.setLowZIndex();
      },
      targetAction: () => {
        this.updateScaleToTarget();
      },
    });
  }

  /**
   * 注册动画监听
   */
  protected registerAnimationListeners(): void {
    // 监听缩放系数变化
    this.pinchObserverProxy.getGridPinchScale(this.gridForm, (_oldState, newState) => {
      if (!FormStateTypeUtils.isInFollowHandState(this.formFsm.currentState)) {
        return;
      }
      const switchStartInfo = this.pinchObserverProxy.switchStartInfo;
      this.attributeUpdater.updateScale({
        x: newState,
        y: newState,
        centerX: switchStartInfo?.anchorCenterX ?? 0,
        centerY: switchStartInfo?.anchorCenterY ?? 0,
      });
    });
  }

  /**
   * 更新 Grid 透明度
   */
  protected updateGridOpacity(visible: boolean): void {
    this.attributeUpdater.updateOpacity(visible ? AnimationOpacity.DEFAULT : AnimationOpacity.TRANSPARENT);
  }

  /**
   * 缩放到目标形态大小
   */
  protected updateScaleToTarget(): void {
    const switchStartInfo = this.pinchObserverProxy.switchStartInfo;
    const targetScale = this.getTargetScale();

    this.attributeUpdater.updateScale({
      x: targetScale,
      y: targetScale,
      centerX: switchStartInfo?.anchorCenterX ?? 0,
      centerY: switchStartInfo?.anchorCenterY ?? 0,
    });
  }

  /**
   * 获取目标缩放值
   */
  protected getTargetScale(): number {
    return 1.0;
  }

  /**
   * Pinch 动画结束回调
   */
  protected onPinchAnimationEnd(): void {
    this.pinchStateManager.notifyAnimationFinished(this.gridForm);
  }

  /**
   * Switch 动画结束回调
   */
  protected onSwitchAnimationEnd(): void {
    this.pinchStateManager.notifyAnimationFinished(this.gridForm);
    this.switchAnimationEndCallback?.(this.gridForm);
  }

  // ========== PinchEventListener 实现 ==========

  /**
   * 捏合状态变化回调
   */
  public onPinchStateChange?(_pinchState: PinchAction): void {
    // 子类可重写
  }

  /**
   * 形态即将到达回调
   */
  public onPinchWillArrive?(_formIndex: FormIndex, _direction?: PinchDirection): void {
    // 子类可重写
  }

  /**
   * 捏合动画结束回调
   */
  public onPinchEndAnimation?(_formIndex: FormIndex): void {
    // 子类可重写
  }

  /**
   * 形态切换前动作
   */
  public onPreFromSwitch?(_targetForm: FormIndex): void {
    // 子类可重写
  }
}
