import { FormIndex } from '../statemanager/constants/GridDefine';
import { AbstractGridVc } from './AbstractGridVc';
import { GridAttributeUpdater } from './GridAttributeUpdater';
import { GridFormFsm } from '../statemanager/GridFormFsm';
import { PinchStateManager } from '../statemanager/PinchStateManager';

export abstract class AbstractDayGridVc extends AbstractGridVc {
  public constructor(
    gridForm: FormIndex,
    formFsm: GridFormFsm,
    pinchStateManager: PinchStateManager,
    attributeUpdater?: GridAttributeUpdater,
  ) {
    super(gridForm, formFsm, pinchStateManager, attributeUpdater);
  }

  public updateLayoutOptions(): void {}
}
