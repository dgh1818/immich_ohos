import { FormIndex, FORM_SIZE } from '../constants/GridDefine';

// 无效中心点X轴值
const INVALID_CENTER_X: number = Number.MIN_SAFE_INTEGER;

/**
 * 切换类型
 */
export enum SwitchType {
  /**
   * 切换按钮
   */
  SWITCH_BUTTON,

  /**
   * 点击宫格
   */
  CLICK_GRID,

  /**
   * 捏合宫格
   */
  PINCH_GRID,
}

/**
 * 切换初始信息
 * 
 * 记录捏合/切换开始时的关键信息：
 * - 起始点坐标
 * - 起始形态
 * - 锚点项索引和中心坐标
 */
export class SwitchStartInfo {
  /**
   * 切换类型
   */
  public readonly switchType: SwitchType;

  /**
   * 起始点X轴
   */
  public readonly startX: number;

  /**
   * 起始点Y轴
   */
  public readonly startY: number;

  /**
   * 起始时宫格形态
   */
  public readonly startForm: FormIndex;

  /**
   * 锚点项索引
   */
  private _anchorItemIndex: number;

  /**
   * 锚点X轴坐标
   */
  private _anchorCenterX: number;

  /**
   * 锚点Y轴坐标
   */
  private _anchorCenterY: number;

  /**
   * 锚点缓存值（各形态缓存）
   */
  private _cachedAnchorCenterXs: number[] = new Array(FORM_SIZE).fill(INVALID_CENTER_X);

  public constructor(switchType: SwitchType, startForm: FormIndex, startX: number, startY: number,
    anchorItemIndex?: number) {
    this.switchType = switchType;
    this.startForm = startForm;
    this.startX = startX ?? 0;
    this.startY = startY ?? 0;
    this._anchorItemIndex = anchorItemIndex ?? -1; // 负数时表示不知道
    this._anchorCenterX = this.startX;
    this._anchorCenterY = this.startY;
  }

  public get anchorItemIndex(): number {
    return this._anchorItemIndex;
  }

  public set anchorItemIndex(anchorItemIndex: number) {
    this._anchorItemIndex = anchorItemIndex;
  }

  public get anchorCenterX(): number {
    return this._anchorCenterX;
  }

  public set anchorCenterX(anchorCenterX: number) {
    this._anchorCenterX = anchorCenterX;
  }

  public get anchorCenterY(): number {
    return this._anchorCenterY;
  }

  public set anchorCenterY(anchorCenterY: number) {
    this._anchorCenterY = anchorCenterY;
  }

  /**
   * 判断索引处锚点是否有效
   *
   * @param formIndex 索引处
   * @returns 是否有效
   */
  public isAnchorCenterXCached(formIndex: number): boolean {
    return this.isValidFormIndex(formIndex) && this._cachedAnchorCenterXs[formIndex] !== INVALID_CENTER_X;
  }

  /**
   * 设置索引处锚点缓存
   *
   * @param formIndex 索引处
   * @param anchorCenterX 锚点值
   */
  public setCachedAnchorCenterX(formIndex: number, anchorCenterX?: number): void {
    if (this.isValidFormIndex(formIndex)) {
      if (anchorCenterX !== undefined) {
        this._cachedAnchorCenterXs[formIndex] = anchorCenterX;
      }
      this._anchorCenterX = this._cachedAnchorCenterXs[formIndex];
    }
  }

  private isValidFormIndex(formIndex: number): boolean {
    return formIndex >= 0 && formIndex < FORM_SIZE;
  }

  /**
   * 输出打印信息
   *
   * @returns 打印信息
   */
  public toString(): string {
    return `<switchType: ${SwitchType[this.switchType]}, startForm: ${FormIndex[this.startForm]}, ` +
      `anchorItemIndex: ${this._anchorItemIndex}, anchorCenter: (${this._anchorCenterX}, ${this._anchorCenterY})>`;
  }
}
