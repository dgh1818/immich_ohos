import { FormIndex } from '../statemanager/constants/GridDefine';
import { AbstractVc } from './AbstractVc';

export abstract class AbstractFormVc extends AbstractVc {
  protected readonly gridForm: FormIndex;

  public constructor(gridForm: FormIndex, tag: string) {
    super(tag);
    this.gridForm = gridForm;
  }
}
