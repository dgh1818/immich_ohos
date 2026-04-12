export enum PhotoGridViewId {
  CONTAINER = '__photo_grid_container__',
  YEAR_GRID = '__photo_grid_year__',
  MONTH_GRID = '__photo_grid_month__',
  DAY_GRID = '__photo_grid_day__',
  GROUP_DAY_GRID = '__photo_grid_group_day__',
  GRID_SNAPSHOT = '__photo_grid_snapshot__',
  TITLE_BAR_MASK = '__photo_grid_title_bar_mask__',
  NO_DATA = '__photo_grid_no_data__',
  IRREGULAR = '__photo_grid_irregular__',
  FIXED_IRREGULAR = '__photo_grid_fixed_irregular__',
}

export enum PhotoGridZIndex {
  YEAR_GRID = 80,
  MONTH_GRID = 90,
  DAY_GRID = 100,
  GROUP_DAY_GRID = 110,
  GRID_SNAPSHOT = 220,
  IRREGULAR = 300,
  FIXED_IRREGULAR = 310,
  TITLE_BAR_MASK = 400,
  NO_DATA = 500,
}

@Observed
export class PhotoGridVc {
  @Track public isTitleBarMaskInit: boolean = false;
  @Track public isNoDataViewInit: boolean = true;
  @Track public isPhotoGridInit: boolean = true;
  @Track public isIrregularViewInit: boolean = true;
  @Track public isFixedIrregularViewInit: boolean = true;
  @Track public titleMaskHeight: number = 72;

  public updateTopInset(topInset: number): void {
    this.titleMaskHeight = Math.max(40, topInset + 40);
  }

  public syncInitState(hasIrregular: boolean, hasFixedIrregular: boolean): void {
    this.isIrregularViewInit = hasIrregular;
    this.isFixedIrregularViewInit = hasFixedIrregular;
  }
}
