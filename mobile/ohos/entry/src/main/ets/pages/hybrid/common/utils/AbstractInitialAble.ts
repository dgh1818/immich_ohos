/**
 * 初始化接口
 */
export interface InitialAble<T = number> {
  /**
   * 初始化
   */
  init(param?: T): void;

  /**
   * 释放
   */
  release(): void;
}

/**
 * 抽象可初始化基类
 */
export abstract class AbstractInitialAble<T = number> implements InitialAble<T> {
  /**
   * 实例ID
   */
  protected _persistentId?: number;

  /**
   * 标签
   */
  private readonly _tag: string;

  /**
   * 是否初始化
   */
  private _hasInit: boolean = false;

  public constructor(tag?: string) {
    this._tag = tag ?? this.constructor.name;
  }

  /**
   * 初始化
   */
  public init(param?: T): void {
    if (this.isSupport === undefined || this.isSupport?.(param)) {
      this.doInit(param);
      this.initPersistentId(param);
      this._hasInit = true;
    }
  }

  /**
   * 释放
   */
  public release(): void {
    if (this._hasInit) {
      this.doRelease();
      this._hasInit = false;
    }
  }

  /**
   * 是否已经初始化
   */
  public hasInit(): boolean {
    return this._hasInit;
  }

  /**
   * 获取实例ID
   */
  public get persistentId(): number {
    return this._persistentId ?? 0;
  }

  /**
   * 设置持久化ID
   */
  public setPersistentId(persistentId?: number): void {
    if (this._persistentId === undefined) {
      this._persistentId = persistentId;
    }
  }

  /**
   * 获取标记
   */
  public get tag(): string {
    return this._tag + (this._persistentId ?? '');
  }

  /**
   * 是否支持初始化
   */
  protected isSupport?(param?: T): boolean;

  /**
   * 执行初始化
   */
  protected abstract doInit(param?: T): void;

  /**
   * 执行释放
   */
  protected abstract doRelease(): void;

  protected initPersistentId(param?: T): void {
    if (this.persistentId !== undefined) {
      return;
    }
    if (typeof param === 'number') {
      this._persistentId = param;
    }
  }
}
