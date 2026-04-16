import { AttributeStateManager } from '../common/model/AttributeStateManager';
import { StateChangeCallback, StateObserverManager } from '../common/model/StateObserverManager';
import { AnimationScale } from '../viewcontroller/animation/AnimationDefine';
import { SwitchStartInfo } from './common/SwitchStartInfo';
import { FORM_SIZE, FormIndex } from './constants/GridDefine';
import { PINCH_SPEED_THRESHOLD, PinchAction, PinchDirection } from './constants/PinchDefine';
import { GridFormFsm } from './GridFormFsm';

const DEFAULT_SCALE: number = 1.0;

/**
 * 捏合状态更新参数
 */
export class PinchStateUpdateParams {
  /**
   * 捏合动作
   */
  public pinchAction: PinchAction = PinchAction.NONE;

  /**
   * 捏合事件
   */
  public pinchEvent?: GestureEvent;

  /**
   * 切换开始信息
   */
  public pinchStartInfo?: SwitchStartInfo;

  /**
   * 即将到达的形态索引
   */
  public willArriveForm?: FormIndex;

  /**
   * 捏合方向
   */
  public pinchDirection?: PinchDirection;

  /**
   * 目标形态
   */
  public targetForm?: FormIndex;
}

/**
 * 捏合事件监听
 */
export interface PinchEventListener {
  /**
   * 捏合状态变化
   */
  onPinchStateChange?: (pinchState: PinchAction) => void;

  /**
   * 形态即将达到
   */
  onPinchWillArrive?: (formIndex: FormIndex, direction?: PinchDirection) => void;

  /**
   * 捏合动效结束通知
   */
  onPinchEndAnimation?: (formIndex: FormIndex) => void;

  /**
   * 形态切换前动作
   */
  onPreFromSwitch?: (targetForm: FormIndex) => void;
}

/**
 * 捏合观察者代理
 */
export class PinchObserverProxy {
  private readonly _pinchStateManager: PinchStateManager;

  public constructor(pinchStateManager: PinchStateManager) {
    this._pinchStateManager = pinchStateManager;
  }

  /**
   * 获取捏合开始信息
   */
  public get switchStartInfo(): SwitchStartInfo | undefined {
    return this._pinchStateManager.switchStartInfo;
  }

  /**
   * 获取捏合速度阈值
   */
  public get pinchSpeedThreshold(): number {
    return this._pinchStateManager.pinchSpeedThreshold;
  }

  /**
   * 查询宫格捏合放缩系数
   */
  public getGridPinchScale(gridForm: FormIndex, callback?: StateChangeCallback<number>): number {
    const manager = this._pinchStateManager.getScaleManager(gridForm);
    if (callback) {
      manager.registerObserver({
        onStateChange: callback
      }, true);
    }
    return manager.currentState;
  }
}

/**
 * 捏合状态管理器
 */
export class PinchStateManager extends StateObserverManager<PinchAction, string> {
  /**
   * 宫格捏合放缩系数管理器列表
   */
  private readonly _pinchScaleManagers: AttributeStateManager<number>[] = [];

  /**
   * 捏合标准系数
   */
  private readonly _pinchStandardScales: number[] = new Array(FORM_SIZE).fill(DEFAULT_SCALE);

  /**
   * 捏合放缩系数
   */
  private _pinchScale: number = DEFAULT_SCALE;

  /**
   * 捏合开始信息
   */
  private _switchStartInfo?: SwitchStartInfo;

  /**
   * 捏合速度阈值
   */
  private _pinchSpeedThreshold: number = PINCH_SPEED_THRESHOLD;

  /**
   * 宫格形态状态机
   */
  private readonly _formFsm: GridFormFsm;

  /**
   * 监听者列表
   */
  private readonly _listeners: PinchEventListener[] = [];

  public constructor(persistentId: number, formFsm: GridFormFsm) {
    super(persistentId, PinchAction.NONE, 'PinchStateManager');
    this._formFsm = formFsm;

    for (let formIndex = 0; formIndex < FORM_SIZE; formIndex++) {
      this._pinchScaleManagers.push(
        new AttributeStateManager(persistentId, DEFAULT_SCALE, `${FormIndex[formIndex]}Scale`, false)
      );
    }
  }

  public override get currentState(): PinchAction {
    return this._pinchScale !== DEFAULT_SCALE ? PinchAction.UPDATE : PinchAction.NONE;
  }

  /**
   * 获取捏合开始信息
   */
  public get switchStartInfo(): SwitchStartInfo | undefined {
    return this._switchStartInfo;
  }

  /**
   * 获取捏合速度阈值
   */
  public get pinchSpeedThreshold(): number {
    return this._pinchSpeedThreshold;
  }

  /**
   * 获取放缩系数管理器
   */
  public getScaleManager(formIndex: FormIndex): AttributeStateManager<number> {
    return this._pinchScaleManagers[formIndex];
  }

  /**
   * 注册监听者
   */
  public addListener(listener: PinchEventListener): void {
    if (!this._listeners.includes(listener)) {
      this._listeners.push(listener);
    }
  }

  /**
   * 移除监听者
   */
  public removeListener(listener: PinchEventListener): void {
    const index = this._listeners.indexOf(listener);
    if (index >= 0) {
      this._listeners.splice(index, 1);
    }
  }

  /**
   * 更新捏合状态
   */
  public updatePinchState(updateParams: PinchStateUpdateParams): void {
    // 初始化事件
    if (updateParams.pinchAction === PinchAction.START) {
      this._switchStartInfo = updateParams.pinchStartInfo;
      this.updatePinchScales(DEFAULT_SCALE, `Pinch_${PinchAction[updateParams.pinchAction]}`);
    } else {
      // 更新缩放系数
      if (updateParams.pinchEvent) {
        this.updatePinchScales(updateParams.pinchEvent.scale, `Pinch_${PinchAction[updateParams.pinchAction]}`);
      }

      // 广播即将到达形态
      if (updateParams.willArriveForm !== undefined) {
        const targetForm = updateParams.willArriveForm;
        this.callbackListeners(listener => listener.onPinchWillArrive?.(targetForm, updateParams.pinchDirection));
      }
    }

    // 更新状态，触发子页面写入捏合初始信息
    if (updateParams.targetForm !== undefined && updateParams.targetForm !== this._formFsm.getCurrentForm()) {
      this.callbackListeners(listener => listener.onPreFromSwitch?.(updateParams.targetForm!));
    }
    this.callbackListeners(listener => listener.onPinchStateChange?.(updateParams.pinchAction));
  }

  /**
   * 清空切换开始信息
   */
  public clearStartInfo(): void {
    this._switchStartInfo = undefined;
  }

  /**
   * 设置切换开始信息（用于非捏合触发的切换，如点击切换）
   */
  public setSwitchStartInfo(startInfo: SwitchStartInfo): void {
    this._switchStartInfo = startInfo;
  }

  /**
   * 更新标准放缩系数
   */
  public updateStandardScales(standardScales: number[], reason?: string): void {
    if (!standardScales || standardScales.length !== FORM_SIZE) {
      console.warn(`[${this.tag}] updateStandardScales invalid standardScales.`);
      return;
    }
    for (let formIndex = 0; formIndex < FORM_SIZE; formIndex++) {
      if (standardScales[formIndex] <= 0) {
        console.warn(`[${this.tag}] updateStandardScales invalid index: ${formIndex} - ${standardScales[formIndex]}.`);
        continue;
      }
      this._pinchStandardScales[formIndex] = standardScales[formIndex];
    }
    this.updatePinchScales(this._pinchScale, reason);
  }

  /**
   * 通知捏合动效结束
   */
  public notifyAnimationFinished(formIndex: FormIndex): void {
    this.callbackListeners(listener => listener.onPinchEndAnimation?.(formIndex));
  }

  /**
   * 更新缩放系数
   */
  private updatePinchScales(scale: number, reason?: string): void {
    this._pinchScale = Math.max(
      this._pinchStandardScales[0] * AnimationScale.MIN_SCALE,
      Math.min(this._pinchStandardScales[FORM_SIZE - 1] * AnimationScale.MAX_SCALE, scale)
    );
    for (let formIndex = 0; formIndex < FORM_SIZE; formIndex++) {
      this.getScaleManager(formIndex).updateState(
        this._pinchScale / this._pinchStandardScales[formIndex], reason
      );
    }
  }

  /**
   * 回调所有监听者
   */
  private callbackListeners(callback: (listener: PinchEventListener) => void): void {
    for (const listener of this._listeners) {
      try {
        callback(listener);
      } catch (e) {
        console.error(`[${this.tag}] callback error: ${e}`);
      }
    }
  }

  protected override doRelease(): void {
    super.doRelease();
    this._listeners.length = 0;
  }
}
