const INITIALIZED: number = 0x1 << 8;
const SHOW: number = 0x1 << 4;
const SURE: number = 0x1;
const PREVIEW: number = 0x1 << 5;

export enum ShowStateType {
  INIT_STATE = 0,
  HIDDEN_STATE = INITIALIZED,
  WILL_SHOW_STATE = INITIALIZED | SHOW,
  SHOW_STATE = INITIALIZED | SHOW | SURE,
  PREVIEW_STATE = INITIALIZED | PREVIEW,
}

export class ShowStateTypeUtils {
  private constructor() {}

  public static isShowState(stateType: ShowStateType): boolean {
    return (stateType & SHOW) === SHOW;
  }

  public static isVisibleState(stateType: ShowStateType): boolean {
    return ShowStateTypeUtils.isShowState(stateType) || stateType === ShowStateType.PREVIEW_STATE;
  }

  public static isInteractiveState(stateType: ShowStateType): boolean {
    return stateType === ShowStateType.SHOW_STATE;
  }

  public static isPreviewState(stateType: ShowStateType): boolean {
    return stateType === ShowStateType.PREVIEW_STATE;
  }
}

export enum ShowEventType {
  NONE = 0,
  SHOW,
  SHOW_PREVIEW,
  HIDE,
  WILL_SHOW,
  OTHER_END_ANIMATION,
  OTHER_KEEP_SHOW_END_ANIMATION,
  CANCEL_KEEP_SHOW,
}

export class GridShowFsm {
  private stateType: ShowStateType;

  public constructor(initialState: ShowStateType = ShowStateType.INIT_STATE) {
    this.stateType = initialState;
  }

  public getCurrentState(): ShowStateType {
    return this.stateType;
  }

  public reset(nextState: ShowStateType = ShowStateType.INIT_STATE): ShowStateType {
    this.stateType = nextState;
    return this.stateType;
  }

  public dispatch(eventType: ShowEventType): ShowStateType {
    this.stateType = GridShowFsm.reduce(this.stateType, eventType);
    return this.stateType;
  }

  public static reduce(stateType: ShowStateType, eventType: ShowEventType): ShowStateType {
    switch (eventType) {
      case ShowEventType.SHOW:
        return ShowStateType.SHOW_STATE;
      case ShowEventType.SHOW_PREVIEW:
        return ShowStateType.PREVIEW_STATE;
      case ShowEventType.HIDE:
        return ShowStateType.HIDDEN_STATE;
      case ShowEventType.WILL_SHOW:
        return stateType === ShowStateType.HIDDEN_STATE
          ? ShowStateType.WILL_SHOW_STATE
          : stateType;
      case ShowEventType.OTHER_END_ANIMATION:
        if (stateType === ShowStateType.WILL_SHOW_STATE || stateType === ShowStateType.SHOW_STATE) {
          return ShowStateType.HIDDEN_STATE;
        }
        return stateType;
      case ShowEventType.OTHER_KEEP_SHOW_END_ANIMATION:
        return stateType === ShowStateType.SHOW_STATE
          ? ShowStateType.WILL_SHOW_STATE
          : stateType;
      case ShowEventType.CANCEL_KEEP_SHOW:
        return stateType === ShowStateType.WILL_SHOW_STATE
          ? ShowStateType.HIDDEN_STATE
          : stateType;
      case ShowEventType.NONE:
      default:
        return stateType;
    }
  }
}