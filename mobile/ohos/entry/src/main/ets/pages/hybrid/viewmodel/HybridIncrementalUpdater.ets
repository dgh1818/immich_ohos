/**
 * HybridIncrementalUpdater - 增量更新管理器
 * 实现类似官方 AlbumDataSource 的增量更新机制
 * 支持数据添加、删除、更新，避免完全重新加载
 */

import * as Shared from '../HybridPhotoGridShared';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridTimelineItem = Shared.HybridTimelineItem;

/**
 * 增量更新类型
 */
export enum IncrementalUpdateType {
  NONE = 0,
  ADD = 1,
  DELETE = 2,
  UPDATE = 3,
  MOVE = 4,
}

/**
 * 增量更新操作
 */
export interface IncrementalUpdateOp {
  type: IncrementalUpdateType;
  startIndex: number;
  endIndex?: number; // 用于 DELETE 和 MOVE
  items?: Array<HybridTimelineItem>; // 用于 ADD 和 UPDATE
  targetIndex?: number; // 用于 MOVE
}

/**
 * 增量更新结果
 */
export interface IncrementalUpdateResult {
  success: boolean;
  ops: Array<IncrementalUpdateOp>;
  oldCount: number;
  newCount: number;
}

/**
 * 增量更新监听器
 */
export interface IncrementalUpdateListener {
  /**
   * 更新前回调
   */
  onBeforeUpdate?: (ops: Array<IncrementalUpdateOp>) => void;

  /**
   * 更新后回调
   */
  onAfterUpdate?: (result: IncrementalUpdateResult) => void;

  /**
   * 单个操作完成回调
   */
  onOpComplete?: (op: IncrementalUpdateOp) => void;
}

/**
 * 数据差异
 */
export interface DataDiff {
  addedIndices: Array<number>;
  deletedIndices: Array<number>;
  updatedIndices: Array<number>;
  movedItems: Array<IncrementalMovedItem>;
}

export class IncrementalMovedItem {
  public fromIndex: number = 0;
  public toIndex: number = 0;

  constructor(fromIndex: number, toIndex: number) {
    this.fromIndex = fromIndex;
    this.toIndex = toIndex;
  }
}

/**
 * 增量更新管理器
 */
export class HybridIncrementalUpdater {
  private readonly tag: string = 'HybridIncrementalUpdater';

  // ========== 当前数据 ==========
  private currentItems: Array<HybridTimelineItem> = [];
  private currentVersion: number = 0;

  // ========== 监听器 ==========
  private listeners: Array<IncrementalUpdateListener> = [];

  // ========== 批量更新 ==========
  private batchMode: boolean = false;
  private batchOps: Array<IncrementalUpdateOp> = [];

  // ========== 配置 ==========
  private readonly maxBatchSize: number = 100;
  private readonly enableDiffCheck: boolean = true;

  public constructor(maxBatchSize: number = 100, enableDiffCheck: boolean = true) {
    this.maxBatchSize = maxBatchSize;
    this.enableDiffCheck = enableDiffCheck;
  }

  // ========== 数据管理 ==========

  /**
   * 获取当前数据
   */
  getCurrentItems(): Array<HybridTimelineItem> {
    return this.currentItems.slice();
  }

  /**
   * 获取当前版本
   */
  getCurrentVersion(): number {
    return this.currentVersion;
  }

  /**
   * 获取当前数量
   */
  getCurrentCount(): number {
    return this.currentItems.length;
  }

  /**
   * 初始化数据
   */
  initialize(items: Array<HybridTimelineItem>): IncrementalUpdateResult {
    const oldCount = this.currentItems.length;
    this.currentItems = items.slice();
    this.currentVersion += 1;

    const op: IncrementalUpdateOp = {
      type: IncrementalUpdateType.ADD,
      startIndex: 0,
      items: items,
    };

    const result: IncrementalUpdateResult = {
      success: true,
      ops: [op],
      oldCount: oldCount,
      newCount: this.currentItems.length,
    };

    this.notifyAfterUpdate(result);
    return result;
  }

  // ========== 增量操作 ==========

  /**
   * 开始批量更新
   */
  beginBatch(): void {
    this.batchMode = true;
    this.batchOps = [];
    console.log(`[${this.tag}] Begin batch update`);
  }

  /**
   * 结束批量更新
   */
  endBatch(): IncrementalUpdateResult {
    if (!this.batchMode) {
      return {
        success: false,
        ops: [],
        oldCount: this.currentItems.length,
        newCount: this.currentItems.length,
      };
    }

    this.batchMode = false;
    const ops = this.batchOps.slice();
    this.batchOps = [];

    // 执行批量操作
    this.executeOps(ops);

    const result: IncrementalUpdateResult = {
      success: true,
      ops: ops,
      oldCount: this.currentItems.length,
      newCount: this.currentItems.length,
    };

    console.log(`[${this.tag}] End batch update, ops: ${ops.length}`);
    this.notifyAfterUpdate(result);
    return result;
  }

  /**
   * 添加数据
   */
  addItems(startIndex: number, items: Array<HybridTimelineItem>): IncrementalUpdateResult {
    const op: IncrementalUpdateOp = {
      type: IncrementalUpdateType.ADD,
      startIndex: startIndex,
      items: items,
    };

    if (this.batchMode) {
      this.batchOps.push(op);
      return {
        success: true,
        ops: [op],
        oldCount: this.currentItems.length,
        newCount: this.currentItems.length + items.length,
      };
    }

    return this.executeOps([op]);
  }

  /**
   * 删除数据
   */
  deleteItems(startIndex: number, count: number): IncrementalUpdateResult {
    const op: IncrementalUpdateOp = {
      type: IncrementalUpdateType.DELETE,
      startIndex: startIndex,
      endIndex: startIndex + count - 1,
    };

    if (this.batchMode) {
      this.batchOps.push(op);
      return {
        success: true,
        ops: [op],
        oldCount: this.currentItems.length,
        newCount: this.currentItems.length - count,
      };
    }

    return this.executeOps([op]);
  }

  /**
   * 更新数据
   */
  updateItems(startIndex: number, items: Array<HybridTimelineItem>): IncrementalUpdateResult {
    const op: IncrementalUpdateOp = {
      type: IncrementalUpdateType.UPDATE,
      startIndex: startIndex,
      items: items,
    };

    if (this.batchMode) {
      this.batchOps.push(op);
      return {
        success: true,
        ops: [op],
        oldCount: this.currentItems.length,
        newCount: this.currentItems.length,
      };
    }

    return this.executeOps([op]);
  }

  /**
   * 移动数据
   */
  moveItem(fromIndex: number, toIndex: number): IncrementalUpdateResult {
    const op: IncrementalUpdateOp = {
      type: IncrementalUpdateType.MOVE,
      startIndex: fromIndex,
      targetIndex: toIndex,
    };

    if (this.batchMode) {
      this.batchOps.push(op);
      return {
        success: true,
        ops: [op],
        oldCount: this.currentItems.length,
        newCount: this.currentItems.length,
      };
    }

    return this.executeOps([op]);
  }

  /**
   * 追加数据到尾部
   */
  appendItems(items: Array<HybridTimelineItem>): IncrementalUpdateResult {
    return this.addItems(this.currentItems.length, items);
  }

  /**
   * 替换尾部数据
   */
  replaceTail(startIndex: number, items: Array<HybridTimelineItem>): IncrementalUpdateResult {
    this.beginBatch();
    this.deleteItems(startIndex, this.currentItems.length - startIndex);
    this.addItems(startIndex, items);
    return this.endBatch();
  }

  // ========== 操作执行 ==========

  /**
   * 执行操作列表
   */
  private executeOps(ops: Array<IncrementalUpdateOp>): IncrementalUpdateResult {
    const oldCount = this.currentItems.length;

    // 通知更新前
    this.notifyBeforeUpdate(ops);

    // 执行每个操作
    for (const op of ops) {
      this.executeOp(op);
      this.notifyOpComplete(op);
    }

    // 更新版本
    this.currentVersion += 1;

    const result: IncrementalUpdateResult = {
      success: true,
      ops: ops,
      oldCount: oldCount,
      newCount: this.currentItems.length,
    };

    // 通知更新后
    this.notifyAfterUpdate(result);

    return result;
  }

  /**
   * 执行单个操作
   */
  private executeOp(op: IncrementalUpdateOp): void {
    switch (op.type) {
      case IncrementalUpdateType.ADD:
        this.executeAdd(op);
        break;
      case IncrementalUpdateType.DELETE:
        this.executeDelete(op);
        break;
      case IncrementalUpdateType.UPDATE:
        this.executeUpdate(op);
        break;
      case IncrementalUpdateType.MOVE:
        this.executeMove(op);
        break;
    }
  }

  private executeAdd(op: IncrementalUpdateOp): void {
    if (!op.items || op.items.length === 0) {
      return;
    }
    const safeStart = Math.max(0, Math.min(op.startIndex, this.currentItems.length));
    this.currentItems.splice(safeStart, 0, ...op.items);
  }

  private executeDelete(op: IncrementalUpdateOp): void {
    const safeStart = Math.max(0, Math.min(op.startIndex, this.currentItems.length - 1));
    const count = op.endIndex !== undefined ? op.endIndex - op.startIndex + 1 : 1;
    const safeCount = Math.min(count, this.currentItems.length - safeStart);
    this.currentItems.splice(safeStart, safeCount);
  }

  private executeUpdate(op: IncrementalUpdateOp): void {
    if (!op.items || op.items.length === 0) {
      return;
    }
    for (let i = 0; i < op.items.length; i++) {
      const index = op.startIndex + i;
      if (index >= 0 && index < this.currentItems.length) {
        this.currentItems[index] = op.items[i];
      }
    }
  }

  private executeMove(op: IncrementalUpdateOp): void {
    if (op.targetIndex === undefined) {
      return;
    }
    const fromIndex = op.startIndex;
    const toIndex = op.targetIndex;
    if (fromIndex < 0 || fromIndex >= this.currentItems.length) {
      return;
    }
    const item = this.currentItems.splice(fromIndex, 1)[0];
    const safeToIndex = Math.max(0, Math.min(toIndex, this.currentItems.length));
    this.currentItems.splice(safeToIndex, 0, item);
  }

  // ========== 差异计算 ==========

  /**
   * 计算数据差异
   */
  calculateDiff(newItems: Array<HybridTimelineItem>): DataDiff {
    const diff: DataDiff = {
      addedIndices: [],
      deletedIndices: [],
      updatedIndices: [],
      movedItems: [],
    };

    if (!this.enableDiffCheck) {
      return diff;
    }

    const oldItems = this.currentItems;
    const oldKeyMap: Map<string, number> = new Map();
    const newKeyMap: Map<string, number> = new Map();

    // 构建旧数据 key 映射
    for (let i = 0; i < oldItems.length; i++) {
      const key = this.getItemKey(oldItems[i]);
      oldKeyMap.set(key, i);
    }

    // 构建新数据 key 映射
    for (let i = 0; i < newItems.length; i++) {
      const key = this.getItemKey(newItems[i]);
      newKeyMap.set(key, i);
    }

    // 找出删除的项
    for (let i = 0; i < oldItems.length; i++) {
      const key = this.getItemKey(oldItems[i]);
      if (!newKeyMap.has(key)) {
        diff.deletedIndices.push(i);
      }
    }

    // 找出添加的项
    for (let i = 0; i < newItems.length; i++) {
      const key = this.getItemKey(newItems[i]);
      if (!oldKeyMap.has(key)) {
        diff.addedIndices.push(i);
      } else {
        // 检查是否移动
        const oldIndex = oldKeyMap.get(key)!;
        if (oldIndex !== i) {
          diff.movedItems.push(new IncrementalMovedItem(oldIndex, i));
        }
        // 检查是否更新
        if (!this.isSameItem(oldItems[oldIndex], newItems[i])) {
          diff.updatedIndices.push(i);
        }
      }
    }

    return diff;
  }

  /**
   * 应用差异
   */
  applyDiff(newItems: Array<HybridTimelineItem>, diff: DataDiff): IncrementalUpdateResult {
    this.beginBatch();

    // 先删除
    if (diff.deletedIndices.length > 0) {
      // 从后往前删除，避免索引变化
      const sortedDeleted = diff.deletedIndices.slice().sort((a, b) => b - a);
      for (const index of sortedDeleted) {
        this.deleteItems(index, 1);
      }
    }

    // 再添加
    if (diff.addedIndices.length > 0) {
      // 从前往后添加
      const sortedAdded = diff.addedIndices.slice().sort((a, b) => a - b);
      for (const index of sortedAdded) {
        if (index < newItems.length) {
          this.addItems(index, [newItems[index]]);
        }
      }
    }

    // 更新
    if (diff.updatedIndices.length > 0) {
      for (const index of diff.updatedIndices) {
        if (index < newItems.length) {
          this.updateItems(index, [newItems[index]]);
        }
      }
    }

    return this.endBatch();
  }

  /**
   * 智能更新
   * 自动计算差异并应用
   */
  smartUpdate(newItems: Array<HybridTimelineItem>): IncrementalUpdateResult {
    const diff = this.calculateDiff(newItems);

    // 如果差异太大，直接替换
    const totalChanges = diff.addedIndices.length + diff.deletedIndices.length + diff.updatedIndices.length;
    if (totalChanges > this.maxBatchSize || totalChanges > this.currentItems.length * 0.5) {
      console.log(`[${this.tag}] Too many changes (${totalChanges}), using full replace`);
      return this.initialize(newItems);
    }

    // 否则应用差异
    console.log(`[${this.tag}] Applying diff: added=${diff.addedIndices.length}, deleted=${diff.deletedIndices.length}, updated=${diff.updatedIndices.length}`);
    return this.applyDiff(newItems, diff);
  }

  // ========== 工具方法 ==========

  private getItemKey(item: HybridTimelineItem): string {
    return item.key || `${item.layoutId}_${item.kind}`;
  }

  private isSameItem(left: HybridTimelineItem, right: HybridTimelineItem): boolean {
    return Shared.isSameTimelineItem(left, right);
  }

  // ========== 监听器管理 ==========

  addListener(listener: IncrementalUpdateListener): void {
    this.listeners.push(listener);
  }

  removeListener(listener: IncrementalUpdateListener): void {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  private notifyBeforeUpdate(ops: Array<IncrementalUpdateOp>): void {
    this.listeners.forEach(listener => listener.onBeforeUpdate?.(ops));
  }

  private notifyAfterUpdate(result: IncrementalUpdateResult): void {
    this.listeners.forEach(listener => listener.onAfterUpdate?.(result));
  }

  private notifyOpComplete(op: IncrementalUpdateOp): void {
    this.listeners.forEach(listener => listener.onOpComplete?.(op));
  }

  // ========== 调试方法 ==========

  /**
   * 获取统计信息
   */
  getStats(): string {
    return `IncrementalUpdater: version=${this.currentVersion}, count=${this.currentItems.length}, batchMode=${this.batchMode}`;
  }

  /**
   * 验证数据一致性
   */
  validateConsistency(): boolean {
    // 检查数据完整性
    for (let i = 0; i < this.currentItems.length; i++) {
      const item = this.currentItems[i];
      if (!item || !item.key) {
        console.error(`[${this.tag}] Invalid item at index ${i}`);
        return false;
      }
    }
    return true;
  }
}
