import { AbstractConfig } from '../../common/model/AbstractConfig';

export interface IScrollerVariableConfig {}

export interface IScrollerConfig extends IScrollerVariableConfig {}

export class ScrollerConfig extends AbstractConfig<IScrollerConfig> implements IScrollerConfig {
  protected override doInit(_config?: IScrollerConfig): void {}
}
