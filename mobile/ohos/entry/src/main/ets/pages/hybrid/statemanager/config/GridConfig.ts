import { AbstractConfig } from '../../common/model/AbstractConfig';
import { DEFAULT_CACHE_COUNT, DEFAULT_COLUMN, DEFAULT_GUTTER, FORM_SIZE } from '../constants/GridDefine';

export interface IGridVariableConfig {
  gridColumns?: number[];
  imageHeights?: number[];
  imageGutters?: number[];
  imageColumnGutters?: number[];
  cachedCounts?: number[];
  isSupportFillPosition?: boolean[];
}

export interface IGridConfig extends IGridVariableConfig {}

function normalizeNumberArray(values: number[] | undefined, fallback: number): number[] {
  const normalized: number[] = [];
  for (let index = 0; index < FORM_SIZE; index += 1) {
    normalized.push(values?.[index] ?? fallback);
  }
  return normalized;
}

function normalizeBooleanArray(values: boolean[] | undefined, fallback: boolean): boolean[] {
  const normalized: boolean[] = [];
  for (let index = 0; index < FORM_SIZE; index += 1) {
    normalized.push(values?.[index] ?? fallback);
  }
  return normalized;
}

export class GridConfig extends AbstractConfig<IGridConfig> implements IGridConfig {
  private gridColumnsValue: number[] = DEFAULT_COLUMN.slice();
  private imageHeightsValue: number[] = normalizeNumberArray(undefined, 0);
  private imageGuttersValue: number[] = DEFAULT_GUTTER.slice();
  private imageColumnGuttersValue: number[] = DEFAULT_GUTTER.slice();
  private cachedCountsValue: number[] = DEFAULT_CACHE_COUNT.slice();
  private supportFillPositionValue: boolean[] = normalizeBooleanArray(undefined, true);

  public get gridColumns(): number[] {
    return this.gridColumnsValue.slice();
  }

  public get imageHeights(): number[] {
    return this.imageHeightsValue.slice();
  }

  public get imageGutters(): number[] {
    return this.imageGuttersValue.slice();
  }

  public get imageColumnGutters(): number[] {
    return this.imageColumnGuttersValue.slice();
  }

  public get cachedCounts(): number[] {
    return this.cachedCountsValue.slice();
  }

  public get isSupportFillPosition(): boolean[] {
    return this.supportFillPositionValue.slice();
  }

  protected override doInit(config?: IGridConfig): void {
    this.gridColumnsValue = DEFAULT_COLUMN.map(
      (_value: number, index: number): number => config?.gridColumns?.[index] ?? DEFAULT_COLUMN[index],
    );
    this.imageHeightsValue = normalizeNumberArray(config?.imageHeights, 0);
    this.imageGuttersValue = DEFAULT_GUTTER.map(
      (_value: number, index: number): number => config?.imageGutters?.[index] ?? DEFAULT_GUTTER[index],
    );
    this.imageColumnGuttersValue = DEFAULT_GUTTER.map(
      (_value: number, index: number): number => config?.imageColumnGutters?.[index] ?? DEFAULT_GUTTER[index],
    );
    this.cachedCountsValue = DEFAULT_CACHE_COUNT.map(
      (_value: number, index: number): number => config?.cachedCounts?.[index] ?? DEFAULT_CACHE_COUNT[index],
    );
    this.supportFillPositionValue = normalizeBooleanArray(config?.isSupportFillPosition, true);
  }
}
