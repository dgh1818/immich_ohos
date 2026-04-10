export enum HybridGridKind {
  A = 0,
  B = 1,
  C = 2,
}

export enum HybridPhotoGridViewId {
  CONTAINER = '__hybrid_photo_grid_container__',
  DAY_GRID_A = '__hybrid_day_grid_a__',
  DAY_GRID_B = '__hybrid_day_grid_b__',
  DAY_GRID_C = '__hybrid_day_grid_c__',
  DAY_GRID_SNAPSHOT = '__hybrid_day_grid_snapshot__',
  TITLE_BAR_MASK = '__hybrid_title_bar_mask__',
  NO_DATA = '__hybrid_no_data__',
  IRREGULAR = '__hybrid_irregular__',
  FIXED_IRREGULAR = '__hybrid_fixed_irregular__',
}

export enum HybridPhotoGridZIndex {
  DAY_GRID_A = 100,
  DAY_GRID_B = 90,
  DAY_GRID_C = 80,
  DAY_GRID_SNAPSHOT = 220,
  IRREGULAR = 300,
  FIXED_IRREGULAR = 310,
  TITLE_BAR_MASK = 400,
  NO_DATA = 500,
}

@Observed
export class HybridPhotoGridVc {
  @Track public isTitleBarMaskInit: boolean = false;
  @Track public isNoDataViewInit: boolean = true;
  @Track public isDayViewInit: boolean = true;
  @Track public isDayPreviewInit: boolean = true;
  @Track public isIrregularViewInit: boolean = true;
  @Track public isFixedIrregularViewInit: boolean = true;
  @Track public titleMaskHeight: number = 72;

  public updateTopInset(topInset: number): void {
    this.titleMaskHeight = Math.max(40, topInset + 40);
  }
}
