import { AbstractObserverProxy } from '../common/model/AbstractObserverProxy';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { DisplayObserverProxy } from './DisplayStateManager';
import { FormEventType, FormStateType } from './GridFormFsm';
import { GridObserverProxy } from './GridStateManager';
import { GridStateProxy } from './GridStateProxy';
import { ScrollerObserverProxy } from './ScrollerStateManager';
import { SwitchObserverProxy } from './SwitchStateManager';
import { FormIndex } from './constants/GridDefine';

export class GridStateObserverProxy extends AbstractObserverProxy<GridStateProxy> {
  public readonly gridObserverProxy: GridObserverProxy = new GridObserverProxy(
    (persistentId: number): GridStateProxy['gridStateManager'] => GridStateProxy.getInstance(persistentId).gridStateManager,
  );
  public readonly displayObserverProxy: DisplayObserverProxy = new DisplayObserverProxy(
    (persistentId: number): GridStateProxy['displayStateManager'] => GridStateProxy.getInstance(persistentId).displayStateManager,
  );
  public readonly switchObserverProxy: SwitchObserverProxy = new SwitchObserverProxy(
    (persistentId: number): GridStateProxy['switchStateManager'] => GridStateProxy.getInstance(persistentId).switchStateManager,
  );
  public readonly scrollerObserverProxy: ScrollerObserverProxy = new ScrollerObserverProxy(
    (persistentId: number): GridStateProxy['scrollerStateManager'] => GridStateProxy.getInstance(persistentId).scrollerStateManager,
  );

  public constructor(tag?: string) {
    super((persistentId: number): GridStateProxy => GridStateProxy.getInstance(persistentId), tag ?? 'GridStateObserverProxy');
  }

  public getFormState(callback?: StateChangeCallback<FormStateType, FormEventType>): FormStateType {
    return this.getState<FormStateType>(
      this.proxy.formFsm as never,
      callback as unknown as StateChangeCallback<FormStateType>,
    );
  }

  public getCurrentForm(): FormIndex {
    return this.proxy.formFsm.getCurrentForm();
  }

  protected override doInit(param?: number): void {
    super.doInit(param);
    this.gridObserverProxy.init(this.persistentId);
    this.displayObserverProxy.init(this.persistentId);
    this.switchObserverProxy.init(this.persistentId);
    this.scrollerObserverProxy.init(this.persistentId);
  }

  protected override doRelease(): void {
    this.scrollerObserverProxy.release();
    this.switchObserverProxy.release();
    this.displayObserverProxy.release();
    this.gridObserverProxy.release();
    super.doRelease();
  }
}
