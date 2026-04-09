/**
 * HybridSlidingWindowDataSource - 滑窗数据源
 * 实现类似官方 AlbumDataSource 的滑窗机制
 * 只保留可视区域附近的数据，减少内存占用
 */

import * as Shared from '../HybridPhotoGridShared';

type HybridTimelineItem = Shared.HybridTimelineItem;

/**
 * 滑窗配置
 */
export interface SlidingWindowConfig {
  /**
   * 向后保留的行数
   */
  behindRows: number;

  /**
   * 向前保留的行数
   */
  aheadRows: number;

  /**
   * 最小保留行数
   */
  minRows: number;

  /**
   * 滑窗移动阈值
   */
  shiftThreshold: number;

  /**
   * 紧急边距
   */
  emergencyMargin: number;
}

/**
 * 默认滑窗配置
 */
export const DEFAULT_SLIDING_WINDOW_CONFIG: SlidingWindowConfig = {
  behindRows: Shared.HYBRID_WINDOW_BEHIND_ROWS,
  aheadRows: Shared.HYBRID_WINDOW_AHEAD_ROWS,
  minRows: Shared.HYBRID_WINDOW_MIN_ROWS,
  shiftThreshold: Shared.HYBRID_WINDOW_SHIFT_THRESHOLD,
  emergencyMargin: Shared.HYBRID_WINDOW_EMERGENCY_MARGIN,
};

/**
 * 滑窗范围
 */
export interface SlidingWindowRange {
  startIndex: number;
  endIndex: number;
  totalCount: number;
}

/**
 * 滑窗变化监听器
 */
export interface SlidingWindowChangeListener {
  /**
   * 滑窗范围变化
   */
  onWindowRangeChange?: (oldRange: SlidingWindowRange, newRange: SlidingWindowRange) => void;

  /**
   * 数据重新加载
   */
  onDataReload?: (items: Array<HybridTimelineItem>) => void;

  /**
   * 数据添加
   */
  onDataAdd?: (index: number, items: Array<HybridTimelineItem>) => void;

  /**
   * 数据删除
   */
  onDataDelete?: (index: number, count: number) => void;

  /**
   * 数据变化
   */
  onDataChange?: (index: number, item: HybridTimelineItem) => void;
}

/**
 * 滑窗数据源
 * 实现 IDataSource 接口，支持滑窗机制
 */
export class HybridSlidingWindowDataSource implements IDataSource {
  private readonly tag: string = 'HybridSlidingWindowDataSource';

  // ========== 全量数据 ==========
  private allItems: Array<HybridTimelineItem> = [];

  // ========== 滑窗配置 ==========
  private readonly config: SlidingWindowConfig;

  // ========== 滑窗范围 ==========
  private windowStartIndex: number = 0;
  private windowEndIndex: number = -1;

  // ========== 滑窗内数据 ==========
  private windowItems: Array<HybridTimelineItem> = [];

  // ========== 监听器 ==========
  private dataListeners: Array<DataChangeListener> = [];
  private windowListeners: Array<SlidingWindowChangeListener> = [];

  // ========== 滑窗状态 ==========
  private lastAnchorIndex: number = -1;
  private pendingShiftStart: number = -1;
  private pendingShiftEnd: number = -1;

  public constructor(config: SlidingWindowConfig = DEFAULT_SLIDING_WINDOW_CONFIG) {
    this.config = config;
  }

  // ========== IDataSource 接口实现 ==========

  totalCount(): number {
    return this.windowItems.length;
  }

  getData(index: number): HybridTimelineItem {
    if (index < 0 || index >= this.windowItems.length) {
      return this.createEmptyItem();
    }
    return this.windowItems[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.dataListeners.indexOf(listener) >= 0) {
      return;
    }
    this.dataListeners.push(listener);
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.dataListeners = this.dataListeners.filter(l => l !== listener);
  }

  // ========== 全量数据管理 ==========

  /**
   * 获取全量数据总数
   */
  getAllItemCount(): number {
    return this.allItems.length;
  }

  /**
   * 获取全量数据
   */
  getAllItems(): Array<HybridTimelineItem> {
    return this.allItems;
  }

  /**
   * 替换所有数据
   */
  replaceAll(items: Array<HybridTimelineItem>): void {
    this.allItems = items.slice();
    this.windowStartIndex = 0;
    this.windowEndIndex = Math.max(-1, items.length - 1);
    this.updateWindowItems();

    // 通知监听器
    this.notifyDataReloaded();
    this.windowListeners.forEach(listener => listener.onDataReload?.(this.windowItems));
  }

  /**
   * 增量添加数据到尾部
   */
  appendTail(startIndex: number, items: Array<HybridTimelineItem>): void {
    const safeStart = Math.max(0, Math.min(startIndex, this.allItems.length));
    this.allItems.splice(safeStart, this.allItems.length - safeStart, ...items);
    this.windowEndIndex = Math.max(-1, this.allItems.length - 1);
    this.updateWindowItems();

    // 通知监听器
    this.notifyDataReloaded();
  }

  /**
   * 增量添加数据
   */
  addItems(startIndex: number, items: Array<HybridTimelineItem>): void {
    const safeStart = Math.max(0, Math.min(startIndex, this.allItems.length));
    this.allItems.splice(safeStart, 0, ...items);
    this.windowEndIndex = Math.max(-1, this.allItems.length - 1);
    this.updateWindowItems();

    // 通知监听器
    this.notifyDataAdd(safeStart);
    this.windowListeners.forEach(listener => listener.onDataAdd?.(safeStart, items));
  }

  /**
   * 增量删除数据
   */
  deleteItems(startIndex: number, count: number): void {
    const safeStart = Math.max(0, Math.min(startIndex, this.allItems.length - 1));
    const safeCount = Math.min(count, this.allItems.length - safeStart);
    this.allItems.splice(safeStart, safeCount);
    this.windowEndIndex = Math.max(-1, this.allItems.length - 1);
    this.updateWindowItems();

    // 通知监听器
    this.notifyDataDelete(safeStart);
    this.windowListeners.forEach(listener => listener.onDataDelete?.(safeStart, safeCount));
  }

  /**
   * 更新单个数据项
   */
  updateItem(index: number, item: HybridTimelineItem): void {
    if (index >= 0 && index < this.allItems.length) {
      this.allItems[index] = item;

      // 检查是否在滑窗内
      if (index >= this.windowStartIndex && index <= this.windowEndIndex) {
        const windowIndex = index - this.windowStartIndex;
        if (windowIndex >= 0 && windowIndex < this.windowItems.length) {
          this.windowItems[windowIndex] = item;
          this.notifyDataChange(windowIndex);
          this.windowListeners.forEach(listener => listener.onDataChange?.(windowIndex, item));
        }
      }
    }
  }

  // ========== 滑窗管理 ==========

  /**
   * 更新滑窗
   * @param anchorIndex 锚点索引（通常是可视区域的第一个索引）
   */
  updateSlidingWindow(anchorIndex: number): void {
    const totalCount = this.allItems.length;
    if (totalCount <= 0) {
      this.windowStartIndex = 0;
      this.windowEndIndex = -1;
      this.windowItems = [];
      return;
    }

    // 计算新的滑窗范围
    const safeAnchor = Math.max(0, Math.min(anchorIndex, totalCount - 1));
    const newStart = Math.max(0, safeAnchor - this.config.behindRows);
    const newEnd = Math.min(totalCount - 1, safeAnchor + this.config.aheadRows);

    // 检查是否需要更新
    const needUpdate = this.shouldUpdateWindow(newStart, newEnd, safeAnchor);
    if (!needUpdate) {
      return;
    }

    // 记录旧范围
    const oldRange: SlidingWindowRange = {
      startIndex: this.windowStartIndex,
      endIndex: this.windowEndIndex,
      totalCount: this.windowItems.length,
    };

    // 更新滑窗范围
    this.windowStartIndex = newStart;
    this.windowEndIndex = newEnd;
    this.lastAnchorIndex = safeAnchor;

    // 更新滑窗内数据
    this.updateWindowItems();

    // 记录新范围
    const newRange: SlidingWindowRange = {
      startIndex: this.windowStartIndex,
      endIndex: this.windowEndIndex,
      totalCount: this.windowItems.length,
    };

    // 通知监听器
    this.notifyDataReloaded();
    this.windowListeners.forEach(listener => listener.onWindowRangeChange?.(oldRange, newRange));

    console.log(`[${this.tag}] Sliding window updated: [${newStart}, ${newEnd}], anchor: ${safeAnchor}`);
  }

  /**
   * 判断是否需要更新滑窗
   */
  private shouldUpdateWindow(newStart: number, newEnd: number, anchorIndex: number): boolean {
    // 首次更新
    if (this.windowEndIndex < 0) {
      return true;
    }

    // 滑窗范围变化
    if (newStart !== this.windowStartIndex || newEnd !== this.windowEndIndex) {
      return true;
    }

    // 锚点移动超过阈值
    if (this.lastAnchorIndex >= 0) {
      const distance = Math.abs(anchorIndex - this.lastAnchorIndex);
      if (distance >= this.config.shiftThreshold) {
        return true;
      }
    }

    return false;
  }

  /**
   * 更新滑窗内数据
   */
  private updateWindowItems(): void {
    if (this.windowEndIndex < 0 || this.windowStartIndex > this.windowEndIndex) {
      this.windowItems = [];
      return;
    }

    this.windowItems = this.allItems.slice(this.windowStartIndex, this.windowEndIndex + 1);
  }

  /**
   * 获取滑窗范围
   */
  getSlidingWindowRange(): SlidingWindowRange {
    return {
      startIndex: this.windowStartIndex,
      endIndex: this.windowEndIndex,
      totalCount: this.allItems.length,
    };
  }

  /**
   * 将滑窗索引转换为全局索引
   */
  windowIndexToGlobalIndex(windowIndex: number): number {
    return this.windowStartIndex + windowIndex;
  }

  /**
   * 将全局索引转换为滑窗索引
   */
  globalIndexToWindowIndex(globalIndex: number): number {
    return globalIndex - this.windowStartIndex;
  }

  /**
   * 检查全局索引是否在滑窗内
   */
  isIndexInWindow(globalIndex: number): boolean {
    return globalIndex >= this.windowStartIndex && globalIndex <= this.windowEndIndex;
  }

  // ========== 紧急滑窗扩展 ==========

  /**
   * 紧急扩展滑窗
   * 当用户快速滚动到边缘时调用
   */
  emergencyExpandWindow(direction: 'up' | 'down'): void {
    const totalCount = this.allItems.length;
    if (totalCount <= 0) {
      return;
    }

    if (direction === 'up') {
      this.windowStartIndex = Math.max(0, this.windowStartIndex - this.config.emergencyMargin);
    } else {
      this.windowEndIndex = Math.min(totalCount - 1, this.windowEndIndex + this.config.emergencyMargin);
    }

    this.updateWindowItems();
    this.notifyDataReloaded();
  }

  // ========== 数据协调（避免跳动） ==========

  /**
   * 协调数据更新
   * 使用差异更新而不是完全替换，避免视图跳动
   */
  reconcile(newItems: Array<HybridTimelineItem>): void {
    const oldItems = this.allItems;
    this.allItems = newItems.slice();

    // 计算差异
    const minLength = Math.min(oldItems.length, newItems.length);
    for (let i = 0; i < minLength; i++) {
      if (!this.isSameItem(oldItems[i], newItems[i])) {
        this.updateItem(i, newItems[i]);
      }
    }

    // 处理删除
    if (oldItems.length > newItems.length) {
      for (let i = oldItems.length - 1; i >= newItems.length; i--) {
        this.notifyDataDelete(i);
      }
      return;
    }

    // 处理添加
    for (let i = oldItems.length; i < newItems.length; i++) {
      this.notifyDataAdd(i);
    }
  }

  /**
   * 判断两个项是否相同
   */
  private isSameItem(left: HybridTimelineItem, right: HybridTimelineItem): boolean {
    return Shared.isSameTimelineItem(left, right);
  }

  // ========== 监听器通知 ==========

  private notifyDataReloaded(): void {
    this.dataListeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  private notifyDataAdd(index: number): void {
    this.dataListeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  private notifyDataDelete(index: number): void {
    this.dataListeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }

  private notifyDataChange(index: number): void {
    this.dataListeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  // ========== 监听器管理 ==========

  addWindowListener(listener: SlidingWindowChangeListener): void {
    this.windowListeners.push(listener);
  }

  removeWindowListener(listener: SlidingWindowChangeListener): void {
    this.windowListeners = this.windowListeners.filter(l => l !== listener);
  }

  // ========== 工具方法 ==========

  private createEmptyItem(): HybridTimelineItem {
    return {
      layoutId: -1,
      key: 'empty',
      kind: 'spacer',
      spacerHeight: 0,
      count: 0,
      sectionKey: '',
      sectionTitle: '',
      sectionCount: 0,
      assets: [],
      isFirstInSection: false,
    };
  }

  // ========== 调试方法 ==========

  /**
   * 获取滑窗统计信息
   */
  getStats(): string {
    return `SlidingWindow: [${this.windowStartIndex}, ${this.windowEndIndex}] / ${this.allItems.length}, windowItems: ${this.windowItems.length}`;
  }
}
