import { FormIndex } from '../statemanager/constants/GridDefine';
import { GridFormFsm } from '../statemanager/GridFormFsm';
import { PinchStateManager } from '../statemanager/PinchStateManager';
import { AbstractGridVc } from './AbstractGridVc';
import { GridAttributeUpdater } from './GridAttributeUpdater';

export interface FormGridVcCallbacks {
  onSwitchAnimationEnd?: (gridForm: FormIndex) => void;
}

export class FormGridVc extends AbstractGridVc {
  public constructor(
    gridForm: FormIndex,
    formFsm: GridFormFsm,
    pinchStateManager: PinchStateManager,
    attributeUpdater?: GridAttributeUpdater,
    callbacks?: FormGridVcCallbacks,
  ) {
    super(gridForm, formFsm, pinchStateManager, attributeUpdater);
    this.attributeUpdater.updateOriginalBackgroundColor('#E0E0E0');
    this.switchAnimationEndCallback = callbacks?.onSwitchAnimationEnd;
  }

  protected override getTargetScale(): number {
    return 1.0;
  }
}
