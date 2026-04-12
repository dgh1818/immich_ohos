import Curves from '@ohos.curves';
import curves from '@ohos.curves';

/**
 * 动效曲线
 */
export class AnimationCurve {
  /**
   * 锐利曲线，对应UX动效设计的(06- Sharp curve)
   */
  public static readonly SHARP_CURVE: ICurve = Curves.cubicBezierCurve(0.33, 0, 0.67, 1);
  
  /**
   * 离手弹簧
   */
  public static readonly LEAVE_HAND_CURVE = curves.springMotion(0.397, 1.01);
}

/**
 * 动效时长，单位ms
 */
export class AnimationDuration {
  /**
   * 默认
   */
  public static readonly DEFAULT: number = 350;
  
  /**
   * 快捏
   */
  public static readonly QUICK_PINCH: number = 200;
  
  /**
   * 慢捏
   */
  public static readonly SLOW_PINCH: number = 400;
  
  /**
   * 切换
   */
  public static readonly SWITCH: number = 200;
  
  /**
   * 恢复补位
   */
  public static readonly RESTORE_FILL_POSITION: number = 350;
}

/**
 * 动效透明度
 */
export class AnimationOpacity {
  /**
   * 默认不透明
   */
  public static readonly DEFAULT: number = 1.0;
  
  /**
   * 透明
   */
  public static readonly TRANSPARENT: number = 0.0;
}

/**
 * 动效缩放系数
 */
export class AnimationScale {
  /**
   * 默认系数
   */
  public static readonly DEFAULT: number = 1.0;
  
  /**
   * 最小缩放比例（<1.0 允许越过最大列数的视觉弹性）
   */
  public static readonly MIN_SCALE: number = 0.88;
  
  /**
   * 最大缩放比例（>1.0 允许越过最小列数的视觉弹性）
   */
  public static readonly MAX_SCALE: number = 1.12;
}
