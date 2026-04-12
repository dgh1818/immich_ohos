export enum PreloadStateType {
  INIT_STATE = 0,
  PRELOAD_STATE,
  PRELOAD_TIMEOUT_STATE,
  LOADED_STATE,
  HIDDEN_STATE,
}

export class PreloadStateTypeUtils {
  private constructor() {}

  public static isInPreloadState(stateType: PreloadStateType): boolean {
    return stateType !== PreloadStateType.HIDDEN_STATE;
  }

  public static isInitOrPreloadState(stateType: PreloadStateType): boolean {
    return stateType === PreloadStateType.INIT_STATE || stateType === PreloadStateType.PRELOAD_STATE;
  }

  public static isInPreloadOrTimeoutState(stateType: PreloadStateType): boolean {
    return stateType === PreloadStateType.PRELOAD_STATE || stateType === PreloadStateType.PRELOAD_TIMEOUT_STATE;
  }

  public static isInLoadedOrTimeoutState(stateType: PreloadStateType): boolean {
    return stateType === PreloadStateType.PRELOAD_TIMEOUT_STATE ||
      stateType === PreloadStateType.LOADED_STATE ||
      stateType === PreloadStateType.HIDDEN_STATE;
  }

  public static isInLoadedState(stateType: PreloadStateType): boolean {
    return stateType === PreloadStateType.LOADED_STATE || stateType === PreloadStateType.HIDDEN_STATE;
  }
}

export enum PreloadEventType {
  NONE = 0,
  ENTER_PRELOAD,
  PRELOAD_TIMEOUT,
  LOAD_FINISH,
  HIDE,
}

export class GridPreloadFsm {
  private stateType: PreloadStateType;

  public constructor(initialState: PreloadStateType = PreloadStateType.INIT_STATE) {
    this.stateType = initialState;
  }

  public getCurrentState(): PreloadStateType {
    return this.stateType;
  }

  public reset(nextState: PreloadStateType = PreloadStateType.INIT_STATE): PreloadStateType {
    this.stateType = nextState;
    return this.stateType;
  }

  public dispatch(eventType: PreloadEventType): PreloadStateType {
    this.stateType = GridPreloadFsm.reduce(this.stateType, eventType);
    return this.stateType;
  }

  public static reduce(stateType: PreloadStateType, eventType: PreloadEventType): PreloadStateType {
    switch (eventType) {
      case PreloadEventType.ENTER_PRELOAD:
        return PreloadStateType.PRELOAD_STATE;
      case PreloadEventType.PRELOAD_TIMEOUT:
        return stateType === PreloadStateType.PRELOAD_STATE
          ? PreloadStateType.PRELOAD_TIMEOUT_STATE
          : stateType;
      case PreloadEventType.LOAD_FINISH:
        return PreloadStateTypeUtils.isInPreloadOrTimeoutState(stateType)
          ? PreloadStateType.LOADED_STATE
          : stateType;
      case PreloadEventType.HIDE:
        return PreloadStateType.HIDDEN_STATE;
      case PreloadEventType.NONE:
      default:
        return stateType;
    }
  }
}