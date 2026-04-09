/**
 * 可回收对象接口
 */
export interface Recyclable {
  /**
   * 回收
   */
  recycle(): void;
}

/**
 * 对象池
 */
export class ObjectPool<T extends Recyclable> {
  /**
   * 池大小
   */
  private readonly _poolSize: number;

  /**
   * 对象构建器
   */
  private readonly _builder: () => T;

  /**
   * 可用对象列表
   */
  private readonly _available: T[] = [];

  /**
   * 是否已销毁
   */
  private _isDestroyed: boolean = false;

  public constructor(poolSize: number, builder: () => T) {
    this._poolSize = poolSize;
    this._builder = builder;
  }

  /**
   * 获取对象
   */
  public acquire(): T | null {
    if (this._isDestroyed) {
      return null;
    }
    if (this._available.length > 0) {
      return this._available.pop()!;
    }
    return this._builder();
  }

  /**
   * 释放对象
   */
  public release(obj: T): void {
    if (this._isDestroyed) {
      return;
    }
    if (this._available.length < this._poolSize) {
      obj.recycle();
      this._available.push(obj);
    }
  }

  /**
   * 销毁池
   */
  public destroy(): void {
    this._isDestroyed = true;
    this._available.length = 0;
  }
}
