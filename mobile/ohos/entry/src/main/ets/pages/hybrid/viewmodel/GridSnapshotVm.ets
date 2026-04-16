import { GridAreaSize } from '../statemanager/config/DisplayConfig';
import { FormIndex } from '../statemanager/constants/GridDefine';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { RestoreFpEventType, RestoreFpStateType, RestoreFpStateTypeUtils } from '../statemanager/GridRestoreFpFsm';
import { GridStateProxy } from '../statemanager/GridStateProxy';
import { AbstractVm } from './AbstractVm';

const SNAPSHOT_FORMS: Array<FormIndex> = [
  FormIndex.YEAR,
  FormIndex.MONTH,
  FormIndex.DAY,
  FormIndex.GROUP_DAY,
];

export class GridSnapshotVm extends AbstractVm {
  public constructor() {
    super('GridSnapshotVm');
  }

  public override bindStateProxy(stateProxy: GridStateProxy): void {
    const shouldRegisterObservers = this.persistentId !== stateProxy.persistentId;
    super.bindStateProxy(stateProxy);
    if (shouldRegisterObservers) {
      this.registerObservers();
    }
  }

  public getActiveForm(): FormIndex {
    return this.getCurrentForm();
  }

  public getGridAreaSize(): GridAreaSize {
    return this.displayObserverProxy.getGridAreaSize();
  }

  public getRestoreState(
    formIndex?: FormIndex,
    callback?: StateChangeCallback<RestoreFpStateType, string | number>,
  ): RestoreFpStateType {
    return this.gridObserverProxy.getRestoreFpState(formIndex ?? this.getCurrentForm(), callback);
  }

  public getScrollOffset(
    formIndex?: FormIndex,
    callback?: StateChangeCallback<number, string | number>,
  ): number {
    return this.gridObserverProxy.getScrollOffset(formIndex ?? this.getCurrentForm(), callback);
  }

  public getIrregularHeight(
    formIndex?: FormIndex,
    callback?: StateChangeCallback<number, string | number>,
  ): number {
    return this.gridObserverProxy.getIrregularHeight(formIndex ?? this.getCurrentForm(), callback);
  }

  public releaseGridCallback<S>(callback: StateChangeCallback<S, string | number>): void {
    this.gridObserverProxy.releaseCallback(callback);
  }

  public getSnapshotOffset(formIndex?: FormIndex): number {
    const activeForm = formIndex ?? this.getCurrentForm();
    return this.gridObserverProxy.getIrregularHeight(activeForm) -
      this.gridObserverProxy.getScrollOffset(activeForm);
  }

  public notifyAnimationPrepareComplete(formIndex?: FormIndex): RestoreFpStateType {
    const activeForm = formIndex ?? this.getCurrentForm();
    return this.gridStateManager.dispatchRestoreFpEvent(
      activeForm,
      RestoreFpEventType.ANIMATION_PREPARE_COMPLETE,
      'GridSnapshotVm.animationPrepared',
    );
  }

  public notifyAnimationComplete(formIndex?: FormIndex): RestoreFpStateType {
    const activeForm = formIndex ?? this.getCurrentForm();
    return this.gridStateManager.dispatchRestoreFpEvent(
      activeForm,
      RestoreFpEventType.ANIMATION_COMPLETE,
      'GridSnapshotVm.animationComplete',
    );
  }

  public cancelRestoreAnimation(formIndex?: FormIndex): RestoreFpStateType {
    const activeForm = formIndex ?? this.getCurrentForm();
    return this.gridStateManager.dispatchRestoreFpEvent(
      activeForm,
      RestoreFpEventType.CANCEL_ANIMATION,
      'GridSnapshotVm.cancelAnimation',
    );
  }

  public resetRestoreState(formIndex?: FormIndex): void {
    const activeForm = formIndex ?? this.getCurrentForm();
    this.gridStateManager.resetRestoreFpState(activeForm, RestoreFpStateType.INIT_STATE, 'GridSnapshotVm.reset');
  }

  private registerObservers(): void {
    SNAPSHOT_FORMS.forEach((form: FormIndex) => {
      if (!this.gridObserverProxy.getIsSupportFp(form)) {
        return;
      }
      this.gridObserverProxy.getFillPostion(form, (_oldState: number, fillPosition: number): void => {
        this.handleFillPositionChange(form, fillPosition);
      });
    });

    this.getFormState((): void => {
      this.checkCancelRestoreAnimation();
    });
    this.switchObserverProxy.getIsSwitching((): void => {
      this.checkCancelRestoreAnimation();
    });
  }

  private handleFillPositionChange(formIndex: FormIndex, fillPosition: number): RestoreFpStateType {
    if (fillPosition > 0) {
      return this.gridStateManager.dispatchRestoreFpEvent(
        formIndex,
        RestoreFpEventType.FILL_POSITION,
        'GridSnapshotVm.fillPosition',
      );
    }

    if (this.getRestoreState(formIndex) === RestoreFpStateType.INIT_STATE) {
      return this.gridStateManager.dispatchRestoreFpEvent(
        formIndex,
        RestoreFpEventType.CANCEL_FILL_POSITION,
        'GridSnapshotVm.cancelFillPosition',
      );
    }

    if (this.canStartRestoreAnimation(formIndex)) {
      return this.gridStateManager.dispatchRestoreFpEvent(
        formIndex,
        RestoreFpEventType.START_ANIMATION,
        'GridSnapshotVm.startRestore',
      );
    }

    return this.gridStateManager.dispatchRestoreFpEvent(
      formIndex,
      RestoreFpEventType.CANCEL_FILL_POSITION,
      'GridSnapshotVm.cancelRestore',
    );
  }

  private checkCancelRestoreAnimation(): void {
    SNAPSHOT_FORMS.forEach((form: FormIndex) => {
      const restoreState = this.getRestoreState(form);
      if (!RestoreFpStateTypeUtils.isInAnimationState(restoreState)) {
        return;
      }
      if (this.canStartRestoreAnimation(form)) {
        return;
      }
      this.gridStateManager.dispatchRestoreFpEvent(
        form,
        RestoreFpEventType.CANCEL_ANIMATION,
        'GridSnapshotVm.cancelAnimationByState',
      );
    });
  }

  private canStartRestoreAnimation(formIndex: FormIndex): boolean {
    return this.getCurrentForm() === formIndex &&
      !this.switchObserverProxy.getIsSwitching();
  }
}
