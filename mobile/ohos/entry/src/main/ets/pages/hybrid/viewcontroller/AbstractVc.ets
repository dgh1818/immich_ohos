/**
 * 属性更新器基类
 * 
 * 用于动态更新组件属性，支持链式调用
 */
export abstract class BaseAttributeUpdater<T> {
  /**
   * 属性对象引用
   */
  protected attribute?: T;

  /**
   * 缩放选项
   */
  protected scaleOptions: ScaleOptions = { x: 1, y: 1 };

  /**
   * 透明度
   */
  protected opacityValue: number = 1.0;

  /**
   * 绑定属性对象
   */
  public bindAttribute(attribute: T): void {
    this.attribute = attribute;
  }

  /**
   * 解绑属性对象
   */
  public unbindAttribute(): void {
    this.attribute = undefined;
  }

  /**
   * 更新缩放
   */
  public updateScale(scaleOptions: ScaleOptions): void {
    this.scaleOptions = scaleOptions;
    // 子类需要重写此方法以实际应用缩放
  }

  /**
   * 更新透明度
   */
  public updateOpacity(opacity: number): void {
    this.opacityValue = opacity;
    // 子类需要重写此方法以实际应用透明度
  }

  /**
   * 获取当前缩放
   */
  public getScale(): ScaleOptions {
    return this.scaleOptions;
  }

  /**
   * 获取当前透明度
   */
  public getOpacity(): number {
    return this.opacityValue;
  }
}

/**
 * Grid 属性接口
 */
export interface GridAttribute {
  scale(value: ScaleOptions): GridAttribute;
  opacity(value: number): GridAttribute;
  zIndex(value: number): GridAttribute;
  hitTestBehavior(value: HitTestMode): GridAttribute;
}

/**
 * Grid 属性更新器
 */
export class GridAttributeUpdater extends BaseAttributeUpdater<GridAttribute> {
  /**
   * 低宫格层级
   */
  private readonly lowZIndex: number = -1;

  /**
   * 高宫格层级
   */
  private readonly highZIndex: number = 0;

  /**
   * 是否在低宫格层级
   */
  private isLowGrid: boolean = false;

  /**
   * 触摸测试模式
   */
  private hitTestMode: HitTestMode = HitTestMode.Default;

  /**
   * 是否显示背景
   */
  private showBackground: boolean = true;

  /**
   * 更新缩放
   */
  public override updateScale(scaleOptions: ScaleOptions): void {
    super.updateScale(scaleOptions);
    this.attribute?.scale(this.scaleOptions);
  }

  /**
   * 更新透明度
   */
  public override updateOpacity(opacity: number): void {
    super.updateOpacity(opacity);
    this.attribute?.opacity(this.opacityValue);
  }

  /**
   * 更新层级
   */
  public updateIsLowGrid(isLowGrid: boolean): void {
    if (this.isLowGrid !== isLowGrid) {
      this.isLowGrid = isLowGrid;
      this.attribute?.zIndex(this.getZIndex());
    }
  }

  /**
   * 更新触摸测试模式
   */
  public updateHitTestMode(hitTestMode: HitTestMode): void {
    if (this.hitTestMode !== hitTestMode) {
      this.hitTestMode = hitTestMode;
      this.attribute?.hitTestBehavior(this.hitTestMode);
    }
  }

  /**
   * 更新是否显示背景
   */
  public updateShowBackground(showBackground: boolean): void {
    this.showBackground = showBackground;
  }

  /**
   * 获取当前层级
   */
  public getZIndex(): number {
    return this.isLowGrid ? this.lowZIndex : this.highZIndex;
  }

  /**
   * 获取触摸测试模式
   */
  public getHitTestMode(): HitTestMode {
    return this.hitTestMode;
  }

  /**
   * 获取是否显示背景
   */
  public getShowBackground(): boolean {
    return this.showBackground;
  }

  /**
   * 恢复高层级
   */
  public restoreZIndex(): void {
    this.updateIsLowGrid(false);
  }

  /**
   * 设置为低层级
   */
  public setLowZIndex(): void {
    this.updateIsLowGrid(true);
  }
}

/**
 * 抽象视图控制器基类
 */
export abstract class AbstractVc {
  /**
   * 控制器标识
   */
  protected readonly tag: string;

  public constructor(tag: string) {
    this.tag = tag;
  }

  /**
   * 初始化
   */
  public abstract init(): void;

  /**
   * 销毁
   */
  public abstract destroy(): void;
}
