import { FormIndex } from '../statemanager/constants/GridDefine';
import { AbstractGridVm } from './AbstractGridVm';

export class AbstractDayGridVm extends AbstractGridVm {
  public constructor(gridForm: FormIndex, tag?: string) {
    super(gridForm, tag ?? 'AbstractDayGridVm');
  }
}
