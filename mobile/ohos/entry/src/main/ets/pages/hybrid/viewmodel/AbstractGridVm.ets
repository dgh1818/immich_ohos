import { FormStateTypeUtils } from '../statemanager/GridFormFsm';
import { FormIndex } from '../statemanager/constants/GridDefine';
import { AbstractFormVm } from './AbstractFormVm';

export class AbstractGridVm extends AbstractFormVm {
  public constructor(gridForm: FormIndex, tag?: string) {
    super(gridForm, tag ?? 'AbstractGridVm');
  }

  protected isInCurrentForm(): boolean {
    return FormStateTypeUtils.isInFormState(this.getFormState(), this.gridForm);
  }
}
