import { AttributeStateManager } from '../common/model/AttributeStateManager';
import { ConfigObserverProxy } from '../common/model/ConfigObserverProxy';
import { ConfigStateManager } from '../common/model/ConfigStateManager';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { GridFormFsm } from './GridFormFsm';
import { GridRestoreFpFsm, RestoreFpEventType, RestoreFpStateType } from './GridRestoreFpFsm';
import { GridShowFsm, ShowEventType, ShowStateType } from './GridShowFsm';
import { FormIndex, FORM_SIZE } from './constants/GridDefine';
import { GridConfig, IGridConfig, IGridVariableConfig } from './config/GridConfig';
import { DisplayStateManager } from './DisplayStateManager';

export class GridObserverProxy extends ConfigObserverProxy<GridStateManager, GridConfig> {
  public constructor(getProxyFunc: (persistentId: number) => GridStateManager) {
    super(getProxyFunc, 'GridObserverProxy');
  }

  public getGridColumn(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getColumnManager(formIndex), callback);
  }

  public getGridImageHeight(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getImageHeightManager(formIndex), callback);
  }

  public getGridImageGutter(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getImageGutterManager(formIndex), callback);
  }

  public getGridImageColumnGutter(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getImageColumnGutterManager(formIndex), callback);
  }

  public getCachedCount(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getCachedCountManager(formIndex), callback);
  }

  public getFillPostion(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getFillPositionManager(formIndex), callback);
  }

  public getScrollOffset(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getScrollOffsetManager(formIndex), callback);
  }

  public getFirstIndex(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getFirstIndexManager(formIndex), callback);
  }

  public getIrregularHeight(formIndex?: FormIndex, callback?: StateChangeCallback<number>): number {
    return this.getState<number>(this.proxy.getIrregularHeightManager(formIndex), callback);
  }

  public getGridShowState(formIndex?: FormIndex, callback?: StateChangeCallback<ShowStateType>): ShowStateType {
    return this.getState<ShowStateType>(this.proxy.getGridShowStateManager(formIndex), callback);
  }

  public getRestoreFpState(
    formIndex?: FormIndex,
    callback?: StateChangeCallback<RestoreFpStateType>,
  ): RestoreFpStateType {
    return this.getState<RestoreFpStateType>(this.proxy.getRestoreFpStateManager(formIndex), callback);
  }

  public getIsSupportFp(formIndex?: FormIndex, callback?: StateChangeCallback<boolean>): boolean {
    return this.getState<boolean>(this.proxy.getIsSupportFpManager(formIndex), callback);
  }

  public getCurrentForm(): FormIndex {
    return this.proxy.getCurrentForm();
  }
}

export class GridStateManager extends ConfigStateManager<GridConfig, IGridConfig, IGridVariableConfig> {
  public override readonly config: GridConfig = new GridConfig();

  private readonly formFsm: GridFormFsm;
  private readonly _displayStateManager: DisplayStateManager;
  private readonly columnManagers: Array<AttributeStateManager<number>> = [];
  private readonly imageHeightManagers: Array<AttributeStateManager<number>> = [];
  private readonly imageGutterManagers: Array<AttributeStateManager<number>> = [];
  private readonly imageColumnGutterManagers: Array<AttributeStateManager<number>> = [];
  private readonly cachedCountManagers: Array<AttributeStateManager<number>> = [];
  private readonly fillPositionManagers: Array<AttributeStateManager<number>> = [];
  private readonly scrollOffsetManagers: Array<AttributeStateManager<number>> = [];
  private readonly firstIndexManagers: Array<AttributeStateManager<number>> = [];
  private readonly irregularHeightManagers: Array<AttributeStateManager<number>> = [];
  private readonly supportFpManagers: Array<AttributeStateManager<boolean>> = [];
  private readonly showStateManagers: Array<AttributeStateManager<ShowStateType>> = [];
  private readonly restoreStateManagers: Array<AttributeStateManager<RestoreFpStateType>> = [];
  private readonly showFsms: Array<GridShowFsm> = [];
  private readonly restoreFsms: Array<GridRestoreFpFsm> = [];

  public constructor(persistentId: number, formFsm: GridFormFsm, displayStateManager: DisplayStateManager) {
    super(persistentId, 'GridStateManager');
    this.formFsm = formFsm;
    this._displayStateManager = displayStateManager;
    for (let formIndex = 0; formIndex < FORM_SIZE; formIndex += 1) {
      const label = FormIndex[formIndex];
      this.columnManagers.push(new AttributeStateManager<number>(persistentId, 0, `${label}Columns`));
      this.imageHeightManagers.push(new AttributeStateManager<number>(persistentId, 0, `${label}ImageHeight`));
      this.imageGutterManagers.push(new AttributeStateManager<number>(persistentId, 0, `${label}ImageGutter`));
      this.imageColumnGutterManagers.push(
        new AttributeStateManager<number>(persistentId, 0, `${label}ImageColumnGutter`),
      );
      this.cachedCountManagers.push(new AttributeStateManager<number>(persistentId, 1, `${label}CachedCount`));
      this.fillPositionManagers.push(new AttributeStateManager<number>(persistentId, 0, `${label}FillPosition`));
      this.scrollOffsetManagers.push(new AttributeStateManager<number>(persistentId, 0, `${label}ScrollOffset`));
      this.firstIndexManagers.push(new AttributeStateManager<number>(persistentId, 0, `${label}FirstIndex`));
      this.irregularHeightManagers.push(
        new AttributeStateManager<number>(persistentId, 0, `${label}IrregularHeight`),
      );
      this.supportFpManagers.push(new AttributeStateManager<boolean>(persistentId, true, `${label}SupportFp`));
      this.showStateManagers.push(
        new AttributeStateManager<ShowStateType>(persistentId, ShowStateType.INIT_STATE, `${label}ShowState`),
      );
      this.restoreStateManagers.push(
        new AttributeStateManager<RestoreFpStateType>(
          persistentId,
          RestoreFpStateType.INIT_STATE,
          `${label}RestoreState`,
        ),
      );
      this.showFsms.push(new GridShowFsm());
      this.restoreFsms.push(new GridRestoreFpFsm());
    }
  }

  public get displayStateManager(): DisplayStateManager {
    return this._displayStateManager;
  }

  public getCurrentForm(): FormIndex {
    return this.formFsm.getCurrentForm();
  }

  public getColumnManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.columnManagers[formIndex ?? this.getCurrentForm()] ?? this.columnManagers[FormIndex.DAY];
  }

  public getImageHeightManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.imageHeightManagers[formIndex ?? this.getCurrentForm()] ?? this.imageHeightManagers[FormIndex.DAY];
  }

  public getImageGutterManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.imageGutterManagers[formIndex ?? this.getCurrentForm()] ?? this.imageGutterManagers[FormIndex.DAY];
  }

  public getImageColumnGutterManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.imageColumnGutterManagers[formIndex ?? this.getCurrentForm()] ??
      this.imageColumnGutterManagers[FormIndex.DAY];
  }

  public getCachedCountManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.cachedCountManagers[formIndex ?? this.getCurrentForm()] ?? this.cachedCountManagers[FormIndex.DAY];
  }

  public getFillPositionManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.fillPositionManagers[formIndex ?? this.getCurrentForm()] ?? this.fillPositionManagers[FormIndex.DAY];
  }

  public getScrollOffsetManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.scrollOffsetManagers[formIndex ?? this.getCurrentForm()] ?? this.scrollOffsetManagers[FormIndex.DAY];
  }

  public getFirstIndexManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.firstIndexManagers[formIndex ?? this.getCurrentForm()] ?? this.firstIndexManagers[FormIndex.DAY];
  }

  public getIrregularHeightManager(formIndex?: FormIndex): AttributeStateManager<number> {
    return this.irregularHeightManagers[formIndex ?? this.getCurrentForm()] ??
      this.irregularHeightManagers[FormIndex.DAY];
  }

  public getIsSupportFpManager(formIndex?: FormIndex): AttributeStateManager<boolean> {
    return this.supportFpManagers[formIndex ?? this.getCurrentForm()] ?? this.supportFpManagers[FormIndex.DAY];
  }

  public getGridShowStateManager(formIndex?: FormIndex): AttributeStateManager<ShowStateType> {
    return this.showStateManagers[formIndex ?? this.getCurrentForm()] ?? this.showStateManagers[FormIndex.DAY];
  }

  public getRestoreFpStateManager(formIndex?: FormIndex): AttributeStateManager<RestoreFpStateType> {
    return this.restoreStateManagers[formIndex ?? this.getCurrentForm()] ?? this.restoreStateManagers[FormIndex.DAY];
  }

  public updateColumn(formIndex: FormIndex, value: number, reason?: string): void {
    this.getColumnManager(formIndex).updateState(value, reason);
  }

  public updateImageHeight(formIndex: FormIndex, value: number, reason?: string): void {
    this.getImageHeightManager(formIndex).updateState(value, reason);
  }

  public updateImageGutter(formIndex: FormIndex, value: number, reason?: string): void {
    this.getImageGutterManager(formIndex).updateState(value, reason);
  }

  public updateImageColumnGutter(formIndex: FormIndex, value: number, reason?: string): void {
    this.getImageColumnGutterManager(formIndex).updateState(value, reason);
  }

  public updateCachedCount(formIndex: FormIndex, value: number, reason?: string): void {
    this.getCachedCountManager(formIndex).updateState(value, reason);
  }

  public updateFillPosition(formIndex: FormIndex, value: number, reason?: string): void {
    this.getFillPositionManager(formIndex).updateState(value, reason);
  }

  public updateScrollOffset(formIndex: FormIndex, value: number, reason?: string): void {
    this.getScrollOffsetManager(formIndex).updateState(value, reason);
  }

  public updateFirstIndex(formIndex: FormIndex, value: number, reason?: string): void {
    this.getFirstIndexManager(formIndex).updateState(value, reason);
  }

  public updateIrregularHeight(formIndex: FormIndex, value: number, reason?: string): void {
    this.getIrregularHeightManager(formIndex).updateState(value, reason);
  }

  public updateSupportFillPosition(formIndex: FormIndex, value: boolean, reason?: string): void {
    this.getIsSupportFpManager(formIndex).updateState(value, reason);
  }

  public resetShowState(formIndex: FormIndex, nextState: ShowStateType = ShowStateType.INIT_STATE, reason?: string): void {
    this.showFsms[formIndex].reset(nextState);
    this.getGridShowStateManager(formIndex).updateState(nextState, reason);
  }

  public dispatchShowEvent(formIndex: FormIndex, eventType: ShowEventType, reason?: string): ShowStateType {
    const nextState = this.showFsms[formIndex].dispatch(eventType);
    this.getGridShowStateManager(formIndex).updateState(nextState, reason);
    return nextState;
  }

  public resetRestoreFpState(
    formIndex: FormIndex,
    nextState: RestoreFpStateType = RestoreFpStateType.INIT_STATE,
    reason?: string,
  ): void {
    this.restoreFsms[formIndex].reset(nextState);
    this.getRestoreFpStateManager(formIndex).updateState(nextState, reason);
  }

  public dispatchRestoreFpEvent(
    formIndex: FormIndex,
    eventType: RestoreFpEventType,
    reason?: string,
  ): RestoreFpStateType {
    const nextState = this.restoreFsms[formIndex].dispatch(eventType);
    this.getRestoreFpStateManager(formIndex).updateState(nextState, reason);
    return nextState;
  }

  public override updateStateFromVariableConfig(config?: IGridVariableConfig, reason?: string): void {
    if (!config) {
      return;
    }
    for (let formIndex = 0; formIndex < FORM_SIZE; formIndex += 1) {
      const currentForm = formIndex as FormIndex;
      if (config.gridColumns?.[formIndex] !== undefined) {
        this.updateColumn(currentForm, config.gridColumns[formIndex], reason);
      }
      if (config.imageHeights?.[formIndex] !== undefined) {
        this.updateImageHeight(currentForm, config.imageHeights[formIndex], reason);
      }
      if (config.imageGutters?.[formIndex] !== undefined) {
        this.updateImageGutter(currentForm, config.imageGutters[formIndex], reason);
      }
      if (config.imageColumnGutters?.[formIndex] !== undefined) {
        this.updateImageColumnGutter(currentForm, config.imageColumnGutters[formIndex], reason);
      }
      if (config.cachedCounts?.[formIndex] !== undefined) {
        this.updateCachedCount(currentForm, config.cachedCounts[formIndex], reason);
      }
      if (config.isSupportFillPosition?.[formIndex] !== undefined) {
        this.updateSupportFillPosition(currentForm, config.isSupportFillPosition[formIndex], reason);
      }
    }
  }

  protected override updateStateFromInitConfig(config: GridConfig, reason?: string): void {
    this.updateStateFromVariableConfig(config, reason);
  }
}
