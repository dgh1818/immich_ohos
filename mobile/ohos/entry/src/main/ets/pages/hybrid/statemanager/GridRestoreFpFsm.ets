/**
 * 恢复补位状态机
 *
 * 管理 fill position 从非零恢复到零的动画流水线：
 *   IDLE → FILL_POSITION → ANIMATION_PREPARE → ANIMATION_READY → IDLE
 *
 * 参考 applications_photos 的 GridRestoreFpFsm。
 */

export enum RestoreFpStateType {
  INIT_STATE = 0,
  IDLE_STATE,
  FILL_POSITION_STATE,
  ANIMATION_PREPARE_STATE,
  ANIMATION_READY_STATE,
}

export class RestoreFpStateTypeUtils {
  private constructor() {}

  public static isInAnimationState(stateType: RestoreFpStateType): boolean {
    return stateType === RestoreFpStateType.ANIMATION_PREPARE_STATE ||
      stateType === RestoreFpStateType.ANIMATION_READY_STATE;
  }

  public static isInFillPositionState(stateType: RestoreFpStateType): boolean {
    return stateType === RestoreFpStateType.FILL_POSITION_STATE;
  }
}

export enum RestoreFpEventType {
  NONE = 0,
  FILL_POSITION,
  CANCEL_FILL_POSITION,
  START_ANIMATION,
  CANCEL_ANIMATION,
  ANIMATION_PREPARE_COMPLETE,
  ANIMATION_COMPLETE,
}

export class GridRestoreFpFsm {
  private stateType: RestoreFpStateType;

  public constructor(initialState: RestoreFpStateType = RestoreFpStateType.INIT_STATE) {
    this.stateType = initialState;
  }

  public getCurrentState(): RestoreFpStateType {
    return this.stateType;
  }

  public reset(nextState: RestoreFpStateType = RestoreFpStateType.INIT_STATE): RestoreFpStateType {
    this.stateType = nextState;
    return this.stateType;
  }

  public dispatch(eventType: RestoreFpEventType): RestoreFpStateType {
    this.stateType = GridRestoreFpFsm.reduce(this.stateType, eventType);
    return this.stateType;
  }

  public static reduce(stateType: RestoreFpStateType, eventType: RestoreFpEventType): RestoreFpStateType {
    switch (stateType) {
      case RestoreFpStateType.INIT_STATE:
        return GridRestoreFpFsm.reduceInit(eventType);
      case RestoreFpStateType.IDLE_STATE:
        return GridRestoreFpFsm.reduceIdle(eventType);
      case RestoreFpStateType.FILL_POSITION_STATE:
        return GridRestoreFpFsm.reduceFillPosition(eventType);
      case RestoreFpStateType.ANIMATION_PREPARE_STATE:
        return GridRestoreFpFsm.reduceAnimationPrepare(eventType);
      case RestoreFpStateType.ANIMATION_READY_STATE:
        return GridRestoreFpFsm.reduceAnimationReady(eventType);
      default:
        return stateType;
    }
  }

  private static reduceInit(eventType: RestoreFpEventType): RestoreFpStateType {
    switch (eventType) {
      case RestoreFpEventType.CANCEL_FILL_POSITION:
        return RestoreFpStateType.IDLE_STATE;
      case RestoreFpEventType.FILL_POSITION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      default:
        return RestoreFpStateType.INIT_STATE;
    }
  }

  private static reduceIdle(eventType: RestoreFpEventType): RestoreFpStateType {
    switch (eventType) {
      case RestoreFpEventType.FILL_POSITION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      default:
        return RestoreFpStateType.IDLE_STATE;
    }
  }

  private static reduceFillPosition(eventType: RestoreFpEventType): RestoreFpStateType {
    switch (eventType) {
      case RestoreFpEventType.CANCEL_FILL_POSITION:
        return RestoreFpStateType.IDLE_STATE;
      case RestoreFpEventType.START_ANIMATION:
        return RestoreFpStateType.ANIMATION_PREPARE_STATE;
      case RestoreFpEventType.FILL_POSITION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      default:
        return RestoreFpStateType.FILL_POSITION_STATE;
    }
  }

  private static reduceAnimationPrepare(eventType: RestoreFpEventType): RestoreFpStateType {
    switch (eventType) {
      case RestoreFpEventType.CANCEL_ANIMATION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      case RestoreFpEventType.ANIMATION_COMPLETE:
        return RestoreFpStateType.IDLE_STATE;
      case RestoreFpEventType.ANIMATION_PREPARE_COMPLETE:
        return RestoreFpStateType.ANIMATION_READY_STATE;
      case RestoreFpEventType.FILL_POSITION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      default:
        return RestoreFpStateType.ANIMATION_PREPARE_STATE;
    }
  }

  private static reduceAnimationReady(eventType: RestoreFpEventType): RestoreFpStateType {
    switch (eventType) {
      case RestoreFpEventType.CANCEL_ANIMATION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      case RestoreFpEventType.ANIMATION_COMPLETE:
        return RestoreFpStateType.IDLE_STATE;
      case RestoreFpEventType.FILL_POSITION:
        return RestoreFpStateType.FILL_POSITION_STATE;
      default:
        return RestoreFpStateType.ANIMATION_READY_STATE;
    }
  }
}
