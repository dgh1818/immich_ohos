/**
 * Hybrid 时间线捏合手势常量定义
 */

/**
 * 捏合速度阈值，超过此速度判定为快捏，否则是慢捏
 */
export const PINCH_SPEED_THRESHOLD: number = 98;

/**
 * 捏合动作
 */
export enum PinchAction {
  /**
   * 未开始
   */
  NONE,

  /**
   * 开始
   */
  START,

  /**
   * 更新
   */
  UPDATE,

  /**
   * 结束(包括取消)
   */
  END,
}

/**
 * 捏合方向
 */
export enum PinchDirection {
  /**
   * 无方向
   */
  NONE = 0,

  /**
   * 放大（捏合张开，列数减少）
   */
  ZOOM_OUT = 1,

  /**
   * 缩小（捏合收紧，列数增加）
   */
  ZOOM_IN = -1,
}
