import {
  AbstractEvent,
  AbstractFsm,
  AbstractState,
  AbstractStateFactory
} from '../common/model/AbstractFsm';
import { FormIndex, FORM_SIZE } from './constants/GridDefine';

// 状态位偏移量
const FORM_OFFSET: number = 3 * 4;
const YEAR_FORM: number = 0x01 << FORM_OFFSET;       // 年视图形态
const MONTH_FORM: number = 0x02 << FORM_OFFSET;      // 月视图形态
const DAY_FORM: number = 0x04 << FORM_OFFSET;        // 日视图形态
const GROUP_DAY_FORM: number = 0x08 << FORM_OFFSET;  // 日分组视图形态
const FORM_FLAG: number = 0xFF << FORM_OFFSET;

const FOLLOW_HAND_STATE_OFFSET: number = 2 * 4;
const FOLLOW_HAND: number = 0x1 << FOLLOW_HAND_STATE_OFFSET; // 跟手态标志

/**
 * 宫格形态状态机-状态类型
 */
export enum FormStateType {
  /**
   * 初始态
   */
  INIT_STATE = 0,

  /**
   * 年视图态
   */
  YEAR_STATE = YEAR_FORM,

  /**
   * 年视图跟手态
   */
  YEAR_FOLLOW_HAND_STATE = YEAR_FORM | FOLLOW_HAND,

  /**
   * 月视图态
   */
  MONTH_STATE = MONTH_FORM,

  /**
   * 月视图跟手态
   */
  MONTH_FOLLOW_HAND_STATE = MONTH_FORM | FOLLOW_HAND,

  /**
   * 日视图态
   */
  DAY_STATE = DAY_FORM,

  /**
   * 日视图跟手态
   */
  DAY_FOLLOW_HAND_STATE = DAY_FORM | FOLLOW_HAND,

  /**
   * 日分组视图态
   */
  GROUP_DAY_STATE = GROUP_DAY_FORM,

  /**
   * 日分组跟手态
   */
  GROUP_DAY_FOLLOW_HAND_STATE = GROUP_DAY_FORM | FOLLOW_HAND,
}

/**
 * 宫格形态状态类型工具类
 */
export class FormStateTypeUtils {
  private constructor() {}

  /**
   * 是否处于有数据状态
   */
  public static isHasDataState(stateType: FormStateType): boolean {
    return stateType !== FormStateType.INIT_STATE;
  }

  /**
   * 是否处于给定形态的状态
   */
  public static isInFormState(stateType: FormStateType, formIndex: FormIndex): boolean {
    if (formIndex < 0) {
      return stateType === FormStateType.INIT_STATE;
    }
    return (stateType & FORM_FLAG) === (0x1 << (formIndex + FORM_OFFSET));
  }

  /**
   * 是否处于年视图态
   */
  public static isInYearState(stateType: FormStateType): boolean {
    return (stateType & YEAR_FORM) === YEAR_FORM;
  }

  /**
   * 是否处于月视图态
   */
  public static isInMonthState(stateType: FormStateType): boolean {
    return (stateType & MONTH_FORM) === MONTH_FORM;
  }

  /**
   * 是否处于日视图态
   */
  public static isInDayState(stateType: FormStateType): boolean {
    return (stateType & DAY_FORM) === DAY_FORM;
  }

  /**
   * 是否处于日分组视图态
   */
  public static isInGroupDayState(stateType: FormStateType): boolean {
    return (stateType & GROUP_DAY_FORM) === GROUP_DAY_FORM;
  }

  /**
   * 是否处于跟手态
   */
  public static isInFollowHandState(stateType: FormStateType): boolean {
    return (stateType & FOLLOW_HAND) === FOLLOW_HAND;
  }

  /**
   * 两位相比是否为更大的形态
   */
  public static isLargerFrom(first: FormStateType, second: FormStateType): boolean {
    return (first & FORM_FLAG) > (second & FORM_FLAG);
  }

  /**
   * 根据状态类型获取形态索引
   */
  public static getFormFromStateType(stateType: FormStateType, withoutGroup: boolean = false): FormIndex {
    switch (stateType & FORM_FLAG) {
      case YEAR_FORM:
        return FormIndex.YEAR;
      case MONTH_FORM:
        return FormIndex.MONTH;
      case DAY_FORM:
        return FormIndex.DAY;
      case GROUP_DAY_FORM:
        return withoutGroup ? FormIndex.DAY : FormIndex.GROUP_DAY;
      default:
        return FormIndex.INVALID;
    }
  }

  /**
   * 根据形态索引获取状态类型
   */
  public static getStateTypeFromForm(formIndex: FormIndex, isFollowHand: boolean = false): FormStateType {
    if (formIndex < 0) {
      return FormStateType.INIT_STATE;
    }
    return (0x1 << (formIndex + FORM_OFFSET)) | (isFollowHand ? FOLLOW_HAND : 0);
  }
}

// 事件类型偏移量
const EVENT_TYPE_OFFSET: number = 5 * 4;
const SWITCH_EVENT: number = 0x1 << EVENT_TYPE_OFFSET;
const PINCH_EVENT: number = 0x2 << EVENT_TYPE_OFFSET;

const EVENT_TARGET_OFFSET: number = 4 * 4;

const FOLLOW_HAND_EVENT_OFFSET: number = 3 * 4;
const TO_FOLLOW_HAND_EVENT: number = 0x1 << FOLLOW_HAND_EVENT_OFFSET;

const QUICK_OFFSET: number = 2 * 4;
const QUICK_PINCH_EVENT: number = 0x1 << QUICK_OFFSET;

/**
 * 宫格形态状态机-事件类型
 */
export enum FormEventType {
  /**
   * 无意义事件，用于创建默认事件，状态机可不处理
   */
  NONE = 0,

  /**
   * 数据加载（包括：1、从无数据状态迁移到有数据状态）
   */
  DATA_LOADED = 1,

  /**
   * 数据清空（包括：1、有数据状态进入无数据状态）
   */
  DATA_CLEAR = 2,

  /**
   * 双指捏合开始
   */
  PINCH_START = PINCH_EVENT | TO_FOLLOW_HAND_EVENT,

  /**
   * 捏合结束
   */
  PINCH_END = PINCH_EVENT,

  /**
   * 快速捏合结束
   */
  PINCH_END_QUICK = PINCH_EVENT | QUICK_PINCH_EVENT,
}

/**
 * 宫格形态事件类型工具类
 */
export class FormEventTypeUtils {
  private constructor() {}

  /**
   * 是否切换事件
   */
  public static isSwitchEvent(eventType: FormEventType): boolean {
    return (eventType & SWITCH_EVENT) === SWITCH_EVENT;
  }

  /**
   * 是否捏合事件
   */
  public static isPinchEvent(eventType: FormEventType): boolean {
    return (eventType & PINCH_EVENT) === PINCH_EVENT;
  }

  /**
   * 是否切换到跟手态事件
   */
  public static isToFollowHandEvent(eventType: FormEventType): boolean {
    return (eventType & TO_FOLLOW_HAND_EVENT) === TO_FOLLOW_HAND_EVENT;
  }

  /**
   * 是否快速捏合事件
   */
  public static isQuickPinchEvent(eventType: FormEventType): boolean {
    return (eventType & QUICK_PINCH_EVENT) === QUICK_PINCH_EVENT;
  }

  /**
   * 获取去掉捏合跟手位的事件类型
   */
  public static getPinchEventType(eventType: FormEventType, toFollowHand: boolean = false,
    isQuickPinch: boolean = false): FormEventType {
    if (!FormEventTypeUtils.isPinchEvent(eventType)) {
      return eventType;
    }
    let result = eventType;
    if (toFollowHand) {
      result |= TO_FOLLOW_HAND_EVENT;
    } else {
      result &= ~TO_FOLLOW_HAND_EVENT;
    }
    if (isQuickPinch) {
      result |= QUICK_PINCH_EVENT;
    } else {
      result &= ~QUICK_PINCH_EVENT;
    }
    return result;
  }

  /**
   * 从去往索引获取捏合事件类型
   */
  public static getPinchEventTypeFromForm(formIndex: FormIndex, toFollowHand: boolean = false,
    isQuickPinch: boolean = false): FormEventType {
    if (formIndex < 0) {
      return FormEventType.NONE;
    }
    return PINCH_EVENT | (0x1 << (formIndex + EVENT_TARGET_OFFSET)) | (toFollowHand ? TO_FOLLOW_HAND_EVENT : 0) |
      (isQuickPinch ? QUICK_PINCH_EVENT : 0);
  }

  /**
   * 从去往索引获取切换事件类型
   */
  public static getSwitchEventTypeFromForm(formIndex: FormIndex): FormEventType {
    if (formIndex < 0) {
      return FormEventType.NONE;
    }
    return SWITCH_EVENT | (0x1 << (formIndex + EVENT_TARGET_OFFSET));
  }
}

/**
 * 宫格形态状态机事件
 */
export class FormEvent extends AbstractEvent<FormEventType> {
  public override toString(): string {
    return FormEventType[this.eventType] ?? `Unknown_FormEvent(${this.eventType})`;
  }
}

/**
 * 抽象宫格形态状态
 */
abstract class AbstractFormState extends AbstractState<FormStateType, FormEventType> {
  public override toString(): string {
    return FormStateType[this.stateType] ?? 'Unknown_FormState';
  }
}

/**
 * 初始态
 */
class InitState extends AbstractFormState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.DATA_LOADED:
        return FormStateType.DAY_STATE;
    }
    return this.stateType;
  }
}

/**
 * 抽象有数据形态
 */
abstract class AbstractHasDataFormState extends AbstractFormState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.DATA_CLEAR:
        return FormStateType.INIT_STATE;
    }
    return this.stateType;
  }
}

/**
 * 抽象非跟手形态
 */
abstract class AbstractNotFollowHandState extends AbstractHasDataFormState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    return super.handleEvent(eventType);
  }
}

/**
 * 抽象跟手形态
 */
abstract class AbstractFollowHandState extends AbstractHasDataFormState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    return super.handleEvent(eventType);
  }
}

/**
 * 年视图态
 */
class YearState extends AbstractNotFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_START:
        return FormStateType.YEAR_FOLLOW_HAND_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 年跟手态
 */
class YearFollowHandState extends AbstractFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_END:
      case FormEventType.PINCH_END_QUICK:
        return FormStateType.YEAR_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 月视图态
 */
class MonthState extends AbstractNotFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_START:
        return FormStateType.MONTH_FOLLOW_HAND_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 月跟手态
 */
class MonthFollowHandState extends AbstractFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_END:
      case FormEventType.PINCH_END_QUICK:
        return FormStateType.MONTH_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 日视图态
 */
class DayState extends AbstractNotFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_START:
        return FormStateType.DAY_FOLLOW_HAND_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 日跟手态
 */
class DayFollowHandState extends AbstractFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_END:
      case FormEventType.PINCH_END_QUICK:
        return FormStateType.DAY_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 日分组视图态
 */
class GroupDayState extends AbstractNotFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_START:
        return FormStateType.GROUP_DAY_FOLLOW_HAND_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 日分组跟手态
 */
class GroupDayFollowHandState extends AbstractFollowHandState {
  public override handleEvent(eventType: FormEventType): FormStateType {
    switch (eventType) {
      case FormEventType.PINCH_END:
      case FormEventType.PINCH_END_QUICK:
        return FormStateType.GROUP_DAY_STATE;
    }
    return super.handleEvent(eventType);
  }
}

/**
 * 宫格状态工厂
 */
class FormStateFactory extends AbstractStateFactory<FormStateType, FormEventType> {
  public constructor() {
    super();
    this.addStateConstructor(FormStateType.INIT_STATE, InitState);
    this.addStateConstructor(FormStateType.YEAR_STATE, YearState);
    this.addStateConstructor(FormStateType.YEAR_FOLLOW_HAND_STATE, YearFollowHandState);
    this.addStateConstructor(FormStateType.MONTH_STATE, MonthState);
    this.addStateConstructor(FormStateType.MONTH_FOLLOW_HAND_STATE, MonthFollowHandState);
    this.addStateConstructor(FormStateType.DAY_STATE, DayState);
    this.addStateConstructor(FormStateType.DAY_FOLLOW_HAND_STATE, DayFollowHandState);
    this.addStateConstructor(FormStateType.GROUP_DAY_STATE, GroupDayState);
    this.addStateConstructor(FormStateType.GROUP_DAY_FOLLOW_HAND_STATE, GroupDayFollowHandState);
  }
}

/**
 * 宫格显示形态状态机
 */
export class GridFormFsm extends AbstractFsm<FormStateType, FormEvent, FormEventType> {
  protected _postCallback = (_oldState: FormStateType, newState: FormStateType): void => {
    if (FormStateTypeUtils.isInDayState(newState)) {
      this._isLastFormIsDayGroup = false;
    } else if (FormStateTypeUtils.isInGroupDayState(newState)) {
      this._isLastFormIsDayGroup = true;
    }
    if (this.getCurrentForm() >= 0) {
      this._lastValidForm = this.getCurrentForm();
    }
  };

  /**
   * 标记日视图最后形态是否为分组形态
   */
  private _isLastFormIsDayGroup?: boolean;

  /**
   * 记录最后的有效宫格形态
   */
  private _lastValidForm?: FormIndex;

  public constructor(persistentId: number) {
    super(persistentId, new FormStateFactory(), FormStateType.INIT_STATE, () => new FormEvent(FormEventType.NONE));
  }

  /**
   * 初始化最后的日视图是否为日分组形态
   */
  public initIsLastFormIsDayGroup(isLastFormIsDayGroup: boolean): void {
    if (this._isLastFormIsDayGroup === undefined) {
      console.info(`[${this.tag}] initIsLastFormIsDayGroup: ${isLastFormIsDayGroup}`);
      this._isLastFormIsDayGroup = isLastFormIsDayGroup;
    }
  }

  /**
   * 调整最后的日视图是否为日分组形态
   */
  public changeIsLastFormIsDayGroup(isLastFormIsDayGroup: boolean): void {
    console.info(`[${this.tag}] changeIsLastFormIsDayGroup: ${isLastFormIsDayGroup}`);
    this._isLastFormIsDayGroup = isLastFormIsDayGroup;
  }

  /**
   * 获取当前形态索引
   */
  public getCurrentForm(): FormIndex {
    return FormStateTypeUtils.getFormFromStateType(this.currentState);
  }

  /**
   * 最后的日形态是否日分组
   */
  public isLastDayFormIsDayGroup(): boolean {
    return this._isLastFormIsDayGroup ?? false;
  }

  /**
   * 获取最后的有效宫格形态
   */
  public getLastValidForm(): FormIndex | undefined {
    return this._lastValidForm;
  }

  protected override getNextState(rawNewState: FormStateType): AbstractState<FormStateType, FormEventType> {
    if (this._isLastFormIsDayGroup && this.isSwitchToDay(rawNewState)) {
      return this.getNextState(FormStateType.GROUP_DAY_STATE);
    }
    return super.getNextState(rawNewState);
  }

  private isSwitchToDay(rawNewState: FormStateType): boolean {
    if (rawNewState !== FormStateType.DAY_STATE) {
      return false;
    } else {
      return (this._currentEventType === FormEventType.DATA_LOADED && this.currentState === FormStateType.INIT_STATE);
    }
  }
}
