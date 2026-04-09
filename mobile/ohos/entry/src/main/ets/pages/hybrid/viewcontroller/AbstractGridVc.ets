import { StateTransferProcessor, StateTransferAction } from '../common/model/StateTransferProcessor';
import { AnimationCurve, AnimationDuration, AnimationOpacity } from './animation/AnimationDefine';
import { AbstractVc, GridAttributeUpdater } from './AbstractVc';
import { FormIndex, getColumnsByFormIndex } from '../statemanager/constants/GridDefine';
import { PinchStateManager, PinchEventListener, PinchObserverProxy } from '../statemanager/PinchStateManager';
import { GridFormFsm, FormStateType, FormEventType, FormStateTypeUtils, FormEventTypeUtils } from '../statemanager/GridFormFsm';
import { SwitchStartInfo, SwitchType } from '../statemanager/common/SwitchStartInfo';

/**
 * 抽象宫格控制器
 * 
 * 核心职责：
 * 1. 监听状态机状态变化
 * 2. 使用 StateTransferProcessor 注册状态转换动作
 * 3. 协调 scale/opacity/zIndex 动画
 */
export abstract class AbstractGridVc extends AbstractVc implements PinchEventListener {
  /**
   * 宫格形态
   */
  protected readonly gridForm: FormIndex;

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

  public constructor(
    gridForm: FormIndex,
    formFsm: GridFormFsm,
    pinchStateManager: PinchStateManager
  ) {
    super(`AbstractGridVc_${FormIndex[gridForm]}`);
    this.gridForm = gridForm;
    this.formFsm = formFsm;
    this.pinchStateManager = pinchStateManager;
    this.pinchObserverProxy = new PinchObserverProxy(pinchStateManager);
    this.attributeUpdater = new GridAttributeUpdater();
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

    // 注册状态机监听
    this.formFsm.registerObserver(this.formStp, true);

    // 注册捏合状态监听
    this.pinchStateManager.addListener(this);

    // 注册状态转换动作
    this.registerActions();

    // 注册动画监听
    this.registerAnimationListeners();
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
        return !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               FormStateTypeUtils.isInFollowHandState(newState);
      },
      isAnimateImmediately: () => true,
      animationParam: (oldState, newState, event) => ({
        curve: AnimationCurve.SHARP_CURVE,
        duration: FormEventTypeUtils.isQuickPinchEvent(event) ?
          AnimationDuration.QUICK_PINCH : AnimationDuration.SLOW_PINCH,
      }),
      prepareAction: () => {
        this.attributeUpdater.restoreZIndex();
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
        return FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFollowHandState(oldState) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               FormStateTypeUtils.isInFollowHandState(newState);
      },
      isAnimateImmediately: () => true,
      animationParam: (oldState, newState, event) => ({
        curve: AnimationCurve.SHARP_CURVE,
        duration: FormEventTypeUtils.isQuickPinchEvent(event) ?
          AnimationDuration.QUICK_PINCH : AnimationDuration.SLOW_PINCH,
      }),
      prepareAction: () => {
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
        return FormStateTypeUtils.isInFollowHandState(oldState) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: (oldState, newState, event) => ({
        curve: AnimationCurve.LEAVE_HAND_CURVE,
        duration: FormEventTypeUtils.isQuickPinchEvent(event) ?
          AnimationDuration.QUICK_PINCH : AnimationDuration.SLOW_PINCH,
        onFinish: () => {
          if (FormStateTypeUtils.isInFormState(newState, this.gridForm)) {
            this.onPinchAnimationEnd();
          }
        },
      }),
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
        return !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        curve: AnimationCurve.SHARP_CURVE,
        duration: AnimationDuration.SWITCH,
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
        return !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        curve: AnimationCurve.SHARP_CURVE,
        duration: AnimationDuration.SWITCH,
      }),
      prepareAction: () => {
        this.attributeUpdater.restoreZIndex();
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
        return FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        curve: AnimationCurve.SHARP_CURVE,
        duration: AnimationDuration.SWITCH,
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
        return FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
               !FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
               !FormStateTypeUtils.isInFollowHandState(newState);
      },
      animationParam: () => ({
        curve: AnimationCurve.SHARP_CURVE,
        duration: AnimationDuration.SWITCH,
        onFinish: () => {
          this.attributeUpdater.setLowZIndex();
        },
      }),
      prepareAction: () => {
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
        return FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
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

  // ========== PinchEventListener 实现 ==========

  /**
   * 捏合状态变化回调
   */
  public onPinchStateChange?(pinchState: PinchAction): void {
    // 子类可重写
  }

  /**
   * 形态即将到达回调
   */
  public onPinchWillArrive?(formIndex: FormIndex, direction?: PinchDirection): void {
    // 子类可重写
  }

  /**
   * 捏合动画结束回调
   */
  public onPinchEndAnimation?(formIndex: FormIndex): void {
    // 子类可重写
  }

  /**
   * 形态切换前动作
   */
  public onPreFromSwitch?(targetForm: FormIndex): void {
    // 子类可重写
  }
}

import { PinchAction, PinchDirection } from '../statemanager/constants/PinchDefine';
