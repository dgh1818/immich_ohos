import { FormIndex, getFormIndexByColumns, getColumnsByFormIndex, DEFAULT_COLUMN } from '../statemanager/constants/GridDefine';
import { PinchAction, PinchDirection } from '../statemanager/constants/PinchDefine';
import { GridFormFsm, FormEventType, FormStateTypeUtils } from '../statemanager/GridFormFsm';
import { PinchStateManager, PinchStateUpdateParams } from '../statemanager/PinchStateManager';
import { SwitchStartInfo, SwitchType } from '../statemanager/common/SwitchStartInfo';

/**
 * Pinch 视图模型
 * 
 * 核心职责：
 * 1. 处理 Pinch 手势事件
 * 2. 计算目标形态和方向
 * 3. 提交状态更新
 */
export class GridPinchVm {
  /**
   * 状态机
   */
  private readonly formFsm: GridFormFsm;

  /**
   * 捏合状态管理器
   */
  private readonly pinchStateManager: PinchStateManager;

  /**
   * 当前列数
   */
  private currentColumns: number = DEFAULT_COLUMN[0];

  /**
   * 捏合开始时的列数
   */
  private pinchStartColumns: number = DEFAULT_COLUMN[0];

  /**
   * 捏合开始时的缩放值
   */
  private pinchStartScale: number = 1.0;

  /**
   * Grid 宽度
   */
  private gridWidth: number = 0;

  /**
   * Grid 高度
   */
  private gridHeight: number = 0;

  public constructor(formFsm: GridFormFsm, pinchStateManager: PinchStateManager) {
    this.formFsm = formFsm;
    this.pinchStateManager = pinchStateManager;
  }

  /**
   * 设置 Grid 尺寸
   */
  public setGridSize(width: number, height: number): void {
    this.gridWidth = width;
    this.gridHeight = height;
  }

  /**
   * 设置当前列数
   */
  public setCurrentColumns(columns: number): void {
    this.currentColumns = columns;
  }

  /**
   * 处理捏合开始
   */
  public handlePinchStart(
    scale: number,
    centerX: number,
    centerY: number,
    scrollOffsetY: number,
    anchorItemIndex?: number
  ): void {
    this.pinchStartColumns = this.currentColumns;
    this.pinchStartScale = scale;

    const startForm = getFormIndexByColumns(this.currentColumns);

    // 构建切换开始信息
    const switchStartInfo = new SwitchStartInfo(
      SwitchType.PINCH_GRID,
      startForm,
      centerX,
      centerY,
      anchorItemIndex
    );

    // 提交捏合开始
    const params = new PinchStateUpdateParams();
    params.pinchAction = PinchAction.START;
    params.pinchStartInfo = switchStartInfo;
    this.pinchStateManager.updatePinchState(params);

    // 提交状态机事件
    this.formFsm.submitEvent(FormEventType.PINCH_START);
  }

  /**
   * 处理捏合更新
   */
  public handlePinchUpdate(
    scale: number,
    centerX: number,
    centerY: number
  ): void {
    // 计算目标列数
    const targetColumns = this.calculateTargetColumns(scale);
    const targetForm = getFormIndexByColumns(targetColumns);
    const currentForm = getFormIndexByColumns(this.currentColumns);

    // 计算捏合方向
    const direction = this.calculatePinchDirection(scale);

    // 提交捏合更新
    const params = new PinchStateUpdateParams();
    params.pinchAction = PinchAction.UPDATE;
    params.pinchEvent = { scale } as GestureEvent;
    params.willArriveForm = targetForm !== currentForm ? targetForm : undefined;
    params.pinchDirection = direction;
    params.targetForm = targetForm;
    this.pinchStateManager.updatePinchState(params);
  }

  /**
   * 处理捏合结束
   */
  public handlePinchEnd(
    scale: number,
    velocity: number = 0
  ): number {
    // 计算最终列数
    const targetColumns = this.calculateTargetColumns(scale);

    // 判断是否快速捏合
    const isQuickPinch = Math.abs(velocity) > this.pinchStateManager.pinchSpeedThreshold;
    const eventType = isQuickPinch ? FormEventType.PINCH_END_QUICK : FormEventType.PINCH_END;

    // 提交捏合结束
    const params = new PinchStateUpdateParams();
    params.pinchAction = PinchAction.END;
    params.pinchEvent = { scale } as GestureEvent;
    this.pinchStateManager.updatePinchState(params);

    // 提交状态机事件
    this.formFsm.submitEvent(eventType);

    // 清空开始信息
    this.pinchStateManager.clearStartInfo();

    return targetColumns;
  }

  /**
   * 计算目标列数
   */
  private calculateTargetColumns(scale: number): number {
    // 缩放比例：scale > 1 表示放大（列数减少），scale < 1 表示缩小（列数增加）
    const scaleFactor = this.pinchStartScale / scale;

    // 根据缩放比例计算目标列数
    const targetColumns = Math.round(this.pinchStartColumns * scaleFactor);

    // 限制列数范围
    const minColumns = DEFAULT_COLUMN[DEFAULT_COLUMN.length - 1]; // 最小列数（3）
    const maxColumns = DEFAULT_COLUMN[0]; // 最大列数（4）

    return Math.max(minColumns, Math.min(maxColumns, targetColumns));
  }

  /**
   * 计算捏合方向
   */
  private calculatePinchDirection(scale: number): PinchDirection {
    if (scale > this.pinchStartScale * 1.05) {
      return PinchDirection.ZOOM_OUT; // 放大（列数减少）
    } else if (scale < this.pinchStartScale * 0.95) {
      return PinchDirection.ZOOM_IN; // 缩小（列数增加）
    }
    return PinchDirection.NONE;
  }

  /**
   * 获取当前形态
   */
  public getCurrentForm(): FormIndex {
    return this.formFsm.getCurrentForm();
  }

  /**
   * 是否处于跟手态
   */
  public isInFollowHandState(): boolean {
    return FormStateTypeUtils.isInFollowHandState(this.formFsm.currentState);
  }

  /**
   * 获取捏合开始信息
   */
  public getSwitchStartInfo(): SwitchStartInfo | undefined {
    return this.pinchStateManager.switchStartInfo;
  }
}
