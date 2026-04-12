/**
 * HybridSwitchCalc - 切换计算工具类
 * 参考官方 SwitchCalcUtils 实现
 * 用于计算 Pinch 缩放时的锚点位置和滚动偏移
 */

import * as Shared from '../HybridPhotoGridShared';

/**
 * 锚点信息
 */
export class AnchorInfo {
  // 锚点项的全局索引
  public itemIndex: number = 0;
  // 锚点所在列
  public column: number = 0;
  // 锚点所在行
  public row: number = 0;
  // 锚点在项内的 X 进度 (0-1)
  public xProgress: number = 0;
  // 锚点在项内的 Y 进度 (0-1)
  public yProgress: number = 0;
  // 锚点的全局 X 坐标
  public globalX: number = 0;
  // 锚点的全局 Y 坐标
  public globalY: number = 0;
  // 锚点中心 X（用于缩放中心）
  public anchorCenterX: number = 0;
  // 锚点中心 Y（用于缩放中心）
  public anchorCenterY: number = 0;
}

/**
 * 切换计算参数
 */
export class SwitchCalcParams {
  // 起始列数
  public startColumns: number = 0;
  // 目标列数
  public targetColumns: number = 0;
  // 起始滚动偏移
  public startScrollOffset: number = 0;
  // 锚点信息
  public anchor: AnchorInfo = new AnchorInfo();
  // Grid 宽度
  public gridWidth: number = 0;
  // Grid 高度
  public gridHeight: number = 0;
  // 顶部插入高度
  public topInset: number = 0;
  // 间距
  public gap: number = Shared.HYBRID_GRID_GAP;
}

/**
 * 切换计算结果
 */
export class SwitchCalcResult {
  // 目标滚动偏移
  public scrollOffset: number = 0;
  // 锚点中心 X
  public anchorCenterX: number = 0;
  // 锚点中心 Y
  public anchorCenterY: number = 0;
  // 补位数量
  public fillPosition: number = 0;
  public firstIndex: number = 0;
}

export class ScrollToIndexParams {
  public itemIndex: number = 0;
  public extraOffset: number = 0;
}

/**
 * 切换计算工具类
 */
export class HybridSwitchCalc {
  private readonly tag: string = 'HybridSwitchCalc';

  /**
   * 计算锚点信息
   * 参考官方 SwitchStartInfo 和 SwitchCalcUtils
   */
  public static calculateAnchor(
    pinchX: number,
    pinchY: number,
    scrollOffset: number,
    columns: number,
    gridWidth: number,
    gridHeight: number,
    topInset: number,
    gap: number = Shared.HYBRID_GRID_GAP,
  ): AnchorInfo {
    const anchor = new AnchorInfo();

    // 计算单个项的尺寸
    const itemWidth = (gridWidth - gap * (columns - 1)) / columns;
    const itemHeight = itemWidth; // 正方形
    const stepX = itemWidth + gap;
    const stepY = itemHeight + gap;

    // 计算列索引和 X 进度
    const column = Math.floor(pinchX / stepX);
    const clampedColumn = Math.max(0, Math.min(columns - 1, column));
    const columnStartX = clampedColumn * stepX;
    const xProgress = Math.max(0, Math.min(1, (pinchX - columnStartX) / Math.max(1, itemWidth)));

    // 计算内容区域的 Y 坐标
    const contentY = scrollOffset + pinchY;
    const photoAreaY = Math.max(0, contentY - topInset);

    // 计算行索引和 Y 进度
    const row = Math.max(0, Math.floor(photoAreaY / stepY));
    const rowStartY = row * stepY;
    const yProgress = Math.max(0, Math.min(1, (photoAreaY - rowStartY) / Math.max(1, itemHeight)));

    // 计算全局项索引
    const itemIndex = row * columns + clampedColumn;

    // 计算锚点中心坐标
    const anchorCenterX = columnStartX + itemWidth * xProgress;
    const anchorCenterY = topInset + rowStartY + itemHeight * yProgress;

    anchor.itemIndex = itemIndex;
    anchor.column = clampedColumn;
    anchor.row = row;
    anchor.xProgress = xProgress;
    anchor.yProgress = yProgress;
    anchor.globalX = pinchX;
    anchor.globalY = pinchY;
    anchor.anchorCenterX = anchorCenterX;
    anchor.anchorCenterY = anchorCenterY;

    return anchor;
  }

  /**
   * 计算切换信息
   * 参考官方 SwitchCalcUtils.calcSwitch
   */
  public static calcSwitch(params: SwitchCalcParams): SwitchCalcResult {
    const result = new SwitchCalcResult();

    const startColumns = params.startColumns;
    const targetColumns = params.targetColumns;
    const anchor = params.anchor;
    const gridWidth = params.gridWidth;
    const topInset = params.topInset;
    const gap = params.gap;

    // 计算起始和目标的项尺寸
    const startItemWidth = (gridWidth - gap * (startColumns - 1)) / startColumns;
    const targetItemWidth = (gridWidth - gap * (targetColumns - 1)) / targetColumns;

    // 计算锚点在目标 Grid 中的列位置
    const targetColumn = HybridSwitchCalc.calcAnchorColumn(
      anchor.globalX,
      targetColumns,
      gridWidth,
      gap,
    );

    // 计算补位
    const originalColumn = anchor.column;
    let fillPosition = targetColumn - originalColumn;
    if (fillPosition < 0) {
      fillPosition += targetColumns;
    }

    // 计算目标滚动偏移
    let scrollOffset = HybridSwitchCalc.calcScrollOffset(
      anchor,
      targetColumns,
      params.startScrollOffset,
      gridWidth,
      topInset,
      gap,
      fillPosition,
    );

    // 计算锚点中心 X
    const anchorCenterX = HybridSwitchCalc.calcAnchorCenterX(
      anchor,
      startColumns,
      targetColumns,
      gridWidth,
      gap,
    );
    let firstIndex = HybridSwitchCalc.calcFirstIndex(targetColumns, scrollOffset, topInset, gridWidth, gap);
    if (firstIndex === 0 && fillPosition > 0) {
      fillPosition = 0;
      scrollOffset = HybridSwitchCalc.calcScrollOffset(
        anchor,
        targetColumns,
        params.startScrollOffset,
        gridWidth,
        topInset,
        gap,
        fillPosition,
      );
      firstIndex = HybridSwitchCalc.calcFirstIndex(targetColumns, scrollOffset, topInset, gridWidth, gap);
    }

    result.scrollOffset = scrollOffset;
    result.anchorCenterX = anchorCenterX;
    result.anchorCenterY = anchor.anchorCenterY;
    result.fillPosition = fillPosition;
    result.firstIndex = firstIndex;

    return result;
  }

  public static calcScrollToIndexParams(
    anchor: AnchorInfo,
    targetColumns: number,
    startScrollOffset: number,
    gridWidth: number,
    topInset: number,
    gap: number = Shared.HYBRID_GRID_GAP,
  ): ScrollToIndexParams {
    const result = new ScrollToIndexParams();
    const safeTargetColumns = Math.max(1, targetColumns);
    const safePhotoIndex = Math.max(0, anchor.itemIndex);
    const targetRow = Math.floor(safePhotoIndex / safeTargetColumns);
    const itemHeight = HybridSwitchCalc.calcItemSize(safeTargetColumns, gridWidth, gap);
    const anchorViewportY = Math.max(topInset, anchor.anchorCenterY - startScrollOffset);

    result.itemIndex = Math.max(0, targetRow * safeTargetColumns);
    result.extraOffset = anchorViewportY - anchor.yProgress * itemHeight;

    return result;
  }

  /**
   * 计算锚点所在列
   * 参考官方 SwitchCommonUtils.getAnchorColumn
   */
  private static calcAnchorColumn(
    startX: number,
    columns: number,
    gridWidth: number,
    gap: number,
  ): number {
    const itemWidth = (gridWidth - gap * (columns - 1)) / columns;
    const stepX = itemWidth + gap;
    const column = Math.floor(startX / stepX);
    return Math.max(0, Math.min(columns - 1, column));
  }

  /**
   * 计算滚动偏移
   * 参考官方 SwitchCalcUtils.calcDefaultScrollOffset
   */
  private static calcScrollOffset(
    anchor: AnchorInfo,
    targetColumns: number,
    startScrollOffset: number,
    gridWidth: number,
    topInset: number,
    gap: number,
    fillPosition: number,
  ): number {
    const itemWidth = (gridWidth - gap * (targetColumns - 1)) / targetColumns;
    const itemHeight = itemWidth;
    const stepY = itemHeight + gap;

    // 计算上方图片行数
    const aboveImageRows = Math.floor((anchor.itemIndex + fillPosition) / targetColumns);

    // 计算被挡住宫格总高度
    const hideGridHeight = aboveImageRows * stepY;

    // 计算图片对齐高度（中间对齐）
    const imageAlignHeight = itemHeight * Math.max(0, Math.min(1, anchor.yProgress));

    // 计算滚动偏移
    let scrollOffset = topInset + hideGridHeight + imageAlignHeight - anchor.anchorCenterY;

    // 确保滚动偏移在有效范围内
    scrollOffset = Math.max(0, scrollOffset);

    return scrollOffset;
  }

  private static calcFirstIndex(
    targetColumns: number,
    scrollOffset: number,
    topInset: number,
    gridWidth: number,
    gap: number,
  ): number {
    if (scrollOffset <= topInset) {
      return 0;
    }
    const itemWidth = (gridWidth - gap * (targetColumns - 1)) / targetColumns;
    const stepY = itemWidth + gap;
    return targetColumns * Math.floor((scrollOffset - topInset) / stepY);
  }

  /**
   * 计算锚点中心 X
   * 参考官方 SwitchCalcUtils.calcAnchorCenterX
   */
  private static calcAnchorCenterX(
    anchor: AnchorInfo,
    startColumns: number,
    targetColumns: number,
    gridWidth: number,
    gap: number,
  ): number {
    // 起始信息
    const startItemWidth = (gridWidth - gap * (startColumns - 1)) / startColumns;
    const startStepX = startItemWidth + gap;
    const originalColumn = Math.floor(anchor.globalX / startStepX);
    const originalStartX = originalColumn * startStepX;

    // 目标信息
    const targetItemWidth = (gridWidth - gap * (targetColumns - 1)) / targetColumns;
    const targetStepX = targetItemWidth + gap;
    const targetColumn = Math.floor(anchor.globalX / targetStepX);
    const targetStartX = targetColumn * targetStepX;

    // 计算中心点 X 轴坐标
    let anchorCenterX = originalStartX;
    if (Math.abs(startItemWidth - targetItemWidth) > 0.001) {
      anchorCenterX += (originalStartX - targetStartX) * startItemWidth / (targetItemWidth - startItemWidth);
    }

    return anchorCenterX;
  }

  /**
   * 计算图片尺寸
   */
  public static calcItemSize(
    columns: number,
    gridWidth: number,
    gap: number = Shared.HYBRID_GRID_GAP,
  ): number {
    return (gridWidth - gap * (columns - 1)) / columns;
  }

  /**
   * 计算步长（项尺寸 + 间距）
   */
  public static calcStep(
    columns: number,
    gridWidth: number,
    gap: number = Shared.HYBRID_GRID_GAP,
  ): number {
    const itemSize = HybridSwitchCalc.calcItemSize(columns, gridWidth, gap);
    return itemSize + gap;
  }
}
