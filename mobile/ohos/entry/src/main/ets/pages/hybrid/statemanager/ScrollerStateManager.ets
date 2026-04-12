import { AttributeStateManager } from '../common/model/AttributeStateManager';
import { ConfigObserverProxy } from '../common/model/ConfigObserverProxy';
import { ConfigStateManager } from '../common/model/ConfigStateManager';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { FormIndex, FORM_SIZE } from './constants/GridDefine';
import { IScrollerConfig, IScrollerVariableConfig, ScrollerConfig } from './config/ScrollerConfig';

export class ScrollerObserverProxy extends ConfigObserverProxy<ScrollerStateManager, ScrollerConfig> {
  public constructor(getProxyFunc: (persistentId: number) => ScrollerStateManager) {
    super(getProxyFunc, 'ScrollerObserverProxy');
  }

  public getIsScrollerTouched(formIndex?: FormIndex, callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.getTouchManager(formIndex), callback);
  }

  public getIsScrolling(formIndex?: FormIndex, callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.getScrollingManager(formIndex), callback);
  }

  public getFirstIndexInGrid(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getFirstIndexManager(formIndex), callback);
  }

  public getLastIndexInGrid(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getLastIndexManager(formIndex), callback);
  }
}

export class ScrollerStateManager
  extends ConfigStateManager<ScrollerConfig, IScrollerConfig, IScrollerVariableConfig> {
  public override readonly config: ScrollerConfig = new ScrollerConfig();

  private readonly scrollingManagers: Array<AttributeStateManager<boolean>> = [];
  private readonly touchManagers: Array<AttributeStateManager<boolean>> = [];
  private readonly firstIndexManagers: Array<AttributeStateManager<number>> = [];
  private readonly lastIndexManagers: Array<AttributeStateManager<number>> = [];

  public constructor(persistentId: number) {
    super(persistentId, 'ScrollerStateManager');
    for (let formIndex = 0; formIndex < FORM_SIZE; formIndex += 1) {
      const label = FormIndex[formIndex];
      this.scrollingManagers.push(
        new AttributeStateManager<boolean>(persistentId, false, `${label}Scrolling`),
      );
      this.touchManagers.push(
        new AttributeStateManager<boolean>(persistentId, false, `${label}Touching`),
      );
      this.firstIndexManagers.push(
        new AttributeStateManager<number>(persistentId, 0, `${label}FirstIndex`),
      );
      this.lastIndexManagers.push(
        new AttributeStateManager<number>(persistentId, 0, `${label}LastIndex`),
      );
    }
  }

  public getScrollingManager(formIndex?: FormIndex): AttributeStateManager<boolean> {
    return this.scrollingManagers[formIndex ?? FormIndex.DAY] ?? this.scrollingManagers[FormIndex.DAY];
  }

  public getTouchManager(formIndex?: FormIndex): AttributeStateManager<boolean> {
    return this.touchManagers[formIndex ?? FormIndex.DAY] ?? this.touchManagers[FormIndex.DAY];
  }

  public getFirstIndexManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.firstIndexManagers[formIndex ?? FormIndex.DAY] ?? this.firstIndexManagers[FormIndex.DAY];
  }

  public getLastIndexManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.lastIndexManagers[formIndex ?? FormIndex.DAY] ?? this.lastIndexManagers[FormIndex.DAY];
  }

  public updateRuntimeState(
    formIndex: FormIndex,
    isScrolling: boolean,
    isTouching: boolean,
    firstIndex: number,
    lastIndex: number,
    reason?: string,
  ): void {
    this.getScrollingManager(formIndex).updateState(isScrolling, reason);
    this.getTouchManager(formIndex).updateState(isTouching, reason);
    this.getFirstIndexManager(formIndex).updateState(Math.max(0, firstIndex), reason);
    this.getLastIndexManager(formIndex).updateState(Math.max(0, lastIndex), reason);
  }

  public override updateStateFromVariableConfig(_config?: IScrollerVariableConfig, _reason?: string): void {}

  protected override updateStateFromInitConfig(config: ScrollerConfig, reason?: string): void {
    this.updateStateFromVariableConfig(config, reason);
  }
}
