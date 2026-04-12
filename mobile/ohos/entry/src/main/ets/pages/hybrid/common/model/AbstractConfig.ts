import { AbstractInitialAble } from '../utils/AbstractInitialAble';

export abstract class AbstractConfig<T> extends AbstractInitialAble<T> {
  protected getValue<V>(
    inputValue: V | undefined,
    defaultValue: V,
    predicate?: (inputValue: V | undefined) => boolean,
  ): V {
    if (predicate) {
      return predicate(inputValue) ? (inputValue as V) : defaultValue;
    }
    return inputValue ?? defaultValue;
  }

  protected override doRelease(): void {}
}
