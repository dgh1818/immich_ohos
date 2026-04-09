import { StateObserverManager, StateChangeCallback } from './StateObserverManager';
import { ObjectPool, Recyclable } from './ObjectPool';

const FSM_EVENT_POOL_SIZE: number = 10;
const PRE_CALLBACK_TIME_LIMIT: number = 10;
const CALLBACK_TIME_LIMIT: number = 30;
const POST_CALLBACK_TIME_LIMIT: number = 10;

type Constructor<ST, S = {}> = new (stateType: ST) => S;

/**
 * 定义事件
 */
export abstract class AbstractEvent<ET> implements Recyclable {
  private _eventType: ET;

  constructor(eventType: ET) {
    this._eventType = eventType;
  }

  public get eventType(): ET {
    return this._eventType;
  }

  public set eventType(eventType: ET) {
    this._eventType = eventType;
  }

  public recycle(): void {
  }

  /**
   * 转化为字符串形式
   */
  public abstract toString(): string;
}

/**
 * 定义状态
 */
export abstract class AbstractState<ST, ET> {
  /**
   * 状态码
   */
  private readonly _stateType: ST;

  constructor(stateType: ST) {
    this._stateType = stateType;
  }

  public get stateType(): ST {
    return this._stateType;
  }

  /**
   * 转化为字符串形式
   */
  public abstract toString(): string;

  /**
   * 处理事件
   */
  public abstract handleEvent(eventType: ET): ST;
}

/**
 * 定义状态工厂
 */
export abstract class AbstractStateFactory<ST, ET> {
  /**
   * 状态表
   */
  private readonly _states: Map<ST, AbstractState<ST, ET>> = new Map();

  /**
   * 状态构造器表
   */
  private readonly _constructors: Map<ST, Constructor<ST, AbstractState<ST, ET>>> = new Map();

  protected constructor() {
  }

  /**
   * 获取状态
   */
  public getState(stateType: ST): AbstractState<ST, ET> {
    if (this._states.has(stateType)) {
      return this._states.get(stateType)!;
    }

    let newState: AbstractState<ST, ET>;
    if (this._constructors.has(stateType)) {
      const constructor: Constructor<ST, AbstractState<ST, ET>> = this._constructors.get(stateType)!;
      newState = new constructor(stateType);
    } else {
      throw new Error(`Create state ${stateType} failed, please check state factory.`);
    }
    this._states.set(stateType, newState);
    return newState;
  }

  /**
   * 增加状态构造方法（按需加载）
   */
  public addStateConstructor(stateType: ST, constructor: Constructor<ST, AbstractState<ST, ET>>): void {
    this._constructors.set(stateType, constructor);
  }
}

/**
 * 定义状态机
 */
export abstract class AbstractFsm<ST, E extends AbstractEvent<ET>, ET> extends StateObserverManager<ST, ET> {
  /**
   * 回调前回调
   */
  protected _preCallback?: StateChangeCallback<ST, ET>;

  /**
   * 回调后回调
   */
  protected _postCallback?: StateChangeCallback<ST, ET>;

  /**
   * 事件对象池
   */
  protected readonly _eventPool: ObjectPool<E>;

  /**
   * 当前正在处理的事件类型
   */
  protected _currentEventType?: ET;

  /**
   * 状态相同时是否回调
   */
  protected readonly _isSameStateCallback: boolean = false;

  private readonly _pendingEvents: Array<E> = new Array();
  private readonly _stateFactory: AbstractStateFactory<ST, ET>;
  private _currentState: AbstractState<ST, ET>;
  private _isRunning: boolean = false;

  constructor(persistentId: number, stateFactory: AbstractStateFactory<ST, ET>, initStateType: ST,
    eventBuilder: () => E, tag?: string) {
    super(persistentId, initStateType, tag);
    this._stateFactory = stateFactory;
    this._eventPool = new ObjectPool(FSM_EVENT_POOL_SIZE, eventBuilder);
    this._currentState = stateFactory.getState(initStateType);
  }

  public override get currentState(): ST {
    return this._currentState.stateType;
  }

  /**
   * 获取状态机事件
   */
  public obtainEvent(): E | null {
    return this._eventPool.acquire();
  }

  /**
   * 提交状态机事件
   */
  public submitEvent(event: E | ET): void {
    try {
      if (!event) {
        return;
      }
      if (event instanceof AbstractEvent) {
        this._pendingEvents.push(event as E);
      } else {
        const obtainEvent: E | null = this._eventPool.acquire();
        if (!obtainEvent) {
          console.warn(`[${this.tag}] submitEvent failed: ${event}`);
          return;
        }
        obtainEvent.eventType = event as ET;
        this._pendingEvents.push(obtainEvent);
      }
      this.handleEvent();
    } catch (e) {
      console.error(`[${this.tag}] submitEvent failed: ${e}`);
    }
  }

  private handleEvent(): void {
    if (this._isRunning) {
      console.info(`[${this.tag}] isRunning, will handle event later.`);
      return;
    }
    console.debug(`[${this.tag}] handle event begin. handler count: ${this.observerSize}`);
    this._isRunning = true;
    while (this._pendingEvents.length > 0) {
      const oldState: AbstractState<ST, ET> = this._currentState;
      const event: E = this._pendingEvents.pop()!;
      this._currentEventType = event.eventType;
      this._currentState = this.getNextState(this._currentState.handleEvent(event.eventType));
      this._currentEventType = undefined;
      if (oldState.stateType !== this._currentState.stateType || this._isSameStateCallback) {
        console.info(`[${this.tag}] ${this.getTransitionLog(oldState, this._currentState, event)}`);
        this.doCallback(oldState.stateType, this._currentState.stateType, event.eventType);
      } else {
        console.debug(`[${this.tag}] ${this.getTransitionLog(oldState, this._currentState, event)}`);
      }
      this._eventPool.release(event);
    }
    this._isRunning = false;
    console.debug(`[${this.tag}] handle event end.`);
  }

  /**
   * 获取下一跳状态（重写此方法，可做定制修改）
   */
  protected getNextState(rawNewState: ST): AbstractState<ST, ET> {
    return this._stateFactory.getState(rawNewState);
  }

  protected override doRelease(): void {
    super.doRelease();
    this._eventPool.destroy();
  }

  private getTransitionLog(oldState: AbstractState<ST, ET>, newState: AbstractState<ST, ET>, event: E): string {
    return `transition: ${event.toString()} [${oldState.toString()} --> ${newState.toString()}]`;
  }

  private doCallback(oldState: ST, newState: ST, event: ET): void {
    if (this._preCallback) {
      this.logProcessTime((): void => {
        this._preCallback?.(oldState, newState, event);
      }, PRE_CALLBACK_TIME_LIMIT, 'pre callback');
    }
    if (this.hasObserver()) {
      this.logProcessTime((): void => {
        this.callbackObservers(observer => observer.onStateChange(oldState, newState, event));
      }, CALLBACK_TIME_LIMIT, 'callback');
    }
    if (this._postCallback) {
      this.logProcessTime((): void => {
        this._postCallback?.(oldState, newState, event);
      }, POST_CALLBACK_TIME_LIMIT, 'post callback');
    }
  }

  private logProcessTime(processFunc: Function, warningTimeLimit: number, processName: string): void {
    const curTime: number = Date.now();
    processFunc();
    const useTime: number = Date.now() - curTime;
    if (useTime > warningTimeLimit) {
      console.warn(`[${this.tag}] ${processName} use ${useTime}ms over limit ${warningTimeLimit}`);
    }
  }
}
