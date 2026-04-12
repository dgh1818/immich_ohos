import { GridAreaSize } from '../statemanager/config/DisplayConfig';
import { FormIndex } from '../statemanager/constants/GridDefine';
import { RestoreFpEventType, RestoreFpStateType } from '../statemanager/GridRestoreFpFsm';
import { AbstractVm } from './AbstractVm';

export class GridSnapshotVm extends AbstractVm {
  public constructor() {
    super('GridSnapshotVm');
  }

  public getActiveForm(): FormIndex {
    return this.getCurrentForm();
  }

  public getGridAreaSize(): GridAreaSize {
    return this.displayObserverProxy.getGridAreaSize();
  }

  public getRestoreState(formIndex?: FormIndex): RestoreFpStateType {
    return this.gridObserverProxy.getRestoreFpState(formIndex ?? this.getCurrentForm());
  }

  public getSnapshotOffset(formIndex?: FormIndex): number {
    const activeForm = formIndex ?? this.getCurrentForm();
    return this.gridObserverProxy.getIrregularHeight(activeForm) -
      this.gridObserverProxy.getScrollOffset(activeForm);
  }

  public notifyFillPositionChanged(hasFillPosition: boolean, formIndex?: FormIndex): RestoreFpStateType {
    const activeForm = formIndex ?? this.getCurrentForm();
    return this.gridStateManager.dispatchRestoreFpEvent(
      activeForm,
      hasFillPosition ? RestoreFpEventType.FILL_POSITION : RestoreFpEventType.CANCEL_FILL_POSITION,
      'GridSnapshotVm.fillPosition',
    );
  }

  public prepareRestoreAnimation(formIndex?: FormIndex): RestoreFpStateType {
    const activeForm = formIndex ?? this.getCurrentForm();
    if (!this.gridObserverProxy.getIsSupportFp(activeForm)) {
      return this.getRestoreState(activeForm);
    }
    if (!this.canStartRestoreAnimation(activeForm)) {
      return this.gridStateManager.dispatchRestoreFpEvent(
        activeForm,
        RestoreFpEventType.CANCEL_FILL_POSITION,
        'GridSnapshotVm.cancelRestore',
      );
    }
    return this.gridStateManager.dispatchRestoreFpEvent(
      activeForm,
      RestoreFpEventType.START_ANIMATION,
      'GridSnapshotVm.startRestore',
    );
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

  private canStartRestoreAnimation(formIndex: FormIndex): boolean {
    return this.gridObserverProxy.getFillPostion(formIndex) > 0 &&
      this.getCurrentForm() === formIndex &&
      !this.switchObserverProxy.getIsSwitching();
  }
}
