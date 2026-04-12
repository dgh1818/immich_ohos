export abstract class AbstractVc {
  protected readonly tag: string;

  public constructor(tag: string) {
    this.tag = tag;
  }

  public abstract init(): void;

  public abstract destroy(): void;
}
