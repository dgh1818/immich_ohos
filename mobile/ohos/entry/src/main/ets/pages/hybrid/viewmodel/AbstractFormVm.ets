import { FormIndex } from '../statemanager/constants/GridDefine';
import { AbstractVm } from './AbstractVm';

export class AbstractFormVm extends AbstractVm {
  protected gridForm: FormIndex;

  public constructor(gridForm: FormIndex, tag?: string) {
    super(tag ?? 'AbstractFormVm');
    this.gridForm = gridForm;
  }

  public updateGridForm(gridForm: FormIndex): void {
    this.gridForm = gridForm;
  }
}
