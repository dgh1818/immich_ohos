# Pinch 透明度优化说明

## 问题分析

原始实现在 Pinch 缩放时一直显示目标 Grid 并改变透明度，这与官方实现不符：

1. **透明度渐变** - 在跟手缩放时改变透明度
2. **目标 Grid 一直显示** - 从 Pinch 开始就显示目标 Grid
3. **视觉效果不自然** - 两个 Grid 同时可见，影响体验

## 官方实现分析

### 透明度变化时机

官方的透明度变化只在以下情况：

1. **切换到达** - 目标 Grid 从透明变为不透明
2. **切换离开** - 当前 Grid 从不透明变为透明
3. **跟手缩放** - **不改变透明度**，只改变缩放系数

### 缩放系数范围

官方使用固定的缩放系数范围：

```typescript
export class AnimationScale {
  public static readonly DEFAULT: number = 1.0;
  public static readonly MIN_SCALE: number = 0.97;  // 最小缩放
  public static readonly MAX_SCALE: number = 1.05;  // 最大缩放
}
```

### 目标 Grid 显示时机

官方只在**即将到达目标形态时**才显示目标 Grid：

```typescript
// 官方：AbstractGridVc.registerFollowHandArriveAction
this.formStp.registerObserver({
  actionName: 'FollowHandArrive',
  isStateTransferMatched: (oldState, newState) => {
    return !FormStateTypeUtils.isInFormState(oldState, this.gridForm) &&
           FormStateTypeUtils.isInFormState(newState, this.gridForm) &&
           FormStateTypeUtils.isInFollowHandState(newState);
  },
  targetAction: () => {
    this.updateGridOpacity(true);  // 只在这里改变透明度
  }
});
```

## 优化实现

### 1. 移除跟手时的透明度变化

**之前：**
```typescript
private updateTargetGridProperties(scale: number): void {
  // 计算目标 Grid 的透明度
  const delta = Math.abs(scale - 1);
  const progress = Math.max(0, Math.min(1, delta / 0.35));
  this.targetGridOpacity = Math.max(0.12, Math.min(1, 0.12 + progress * 0.88));
}
```

**现在：**
```typescript
private updateTargetGridProperties(scale: number): void {
  // 参考官方实现：只在即将到达目标形态时才显示目标 Grid
  // 不在跟手缩放时改变透明度，只在切换时才改变

  // 计算目标 Grid 的缩放（用于预览效果）
  const minScale = 0.97;
  const maxScale = 1.05;

  if (scale > 1) {
    this.targetGridScale = Math.max(minScale, scale - 0.03);
  } else {
    this.targetGridScale = Math.min(maxScale, scale + 0.03);
  }
}
```

### 2. Pinch 开始时不显示目标 Grid

**之前：**
```typescript
private handlePinchStart(...): void {
  // 构建目标 Grid 数据
  this.targetGridItems = this.buildGridItemsForColumns(state.targetColumns);
  this.targetGridDataSource.updateAll(this.targetGridItems);
  this.showTargetGrid = true;           // ❌ 立即显示
  this.targetGridOpacity = 0.12;        // ❌ 设置透明度
  this.targetGridScale = 0.96;          // ❌ 设置缩放
}
```

**现在：**
```typescript
private handlePinchStart(...): void {
  // 参考官方：不立即显示目标 Grid
  // 目标 Grid 只在即将到达目标形态时才显示
  this.showTargetGrid = false;          // ✅ 不显示
  this.targetGridOpacity = 0;           // ✅ 完全透明
  this.targetGridScale = 1.0;           // ✅ 正常大小
}
```

### 3. 即将到达目标形态时才显示

**现在：**
```typescript
private handlePinchUpdate(...): void {
  // 更新目标列数
  if (state.targetColumns !== this.pinchTargetColumns) {
    this.pinchTargetColumns = state.targetColumns;

    // 参考官方：在即将到达目标形态时才显示目标 Grid
    this.targetGridItems = this.buildGridItemsForColumns(state.targetColumns);
    this.targetGridDataSource.updateAll(this.targetGridItems);

    // 显示目标 Grid（即将到达）
    this.showTargetGrid = true;         // ✅ 显示
    this.targetGridOpacity = 1.0;       // ✅ 完全不透明
    this.targetGridScale = 1.0;         // ✅ 正常大小

    // 同步滚动位置
    this.syncTargetGridScroll(scrollOffset);
  }
}
```

## 关键改进

### 1. 透明度变化时机

| 时机 | 之前 | 现在 |
|------|------|------|
| **Pinch 开始** | 显示目标 Grid (opacity=0.12) | 不显示目标 Grid |
| **跟手缩放** | 渐变透明度 (0.12→1.0) | 不改变透明度 |
| **即将到达** | - | 显示目标 Grid (opacity=1.0) |
| **切换完成** | 隐藏目标 Grid | 隐藏目标 Grid |

### 2. 缩放系数范围

| 方面 | 之前 | 现在 |
|------|------|------|
| **最小缩放** | 0.96 | 0.97 (官方) |
| **最大缩放** | 1.04 | 1.05 (官方) |
| **计算方式** | 线性渐变 | 固定范围 |

### 3. 目标 Grid 显示

| 情况 | 之前 | 现在 |
|------|------|------|
| **Pinch 开始** | ✅ 显示 | ❌ 不显示 |
| **跟手缩放** | ✅ 显示 | ❌ 不显示 |
| **即将到达目标** | ✅ 显示 | ✅ 显示 |
| **切换完成** | ❌ 隐藏 | ❌ 隐藏 |

## 视觉效果对比

### 之前的效果

```
Pinch 开始
├─ 主 Grid: scale=1.0, opacity=1.0
└─ 目标 Grid: scale=0.96, opacity=0.12  ← 立即显示

跟手缩放
├─ 主 Grid: scale=0.97~1.05, opacity=1.0
└─ 目标 Grid: scale=渐变, opacity=0.12~1.0  ← 渐变透明度

切换完成
├─ 主 Grid: scale=1.0, opacity=1.0
└─ 目标 Grid: scale=1.0, opacity=0  ← 隐藏
```

### 现在的效果

```
Pinch 开始
├─ 主 Grid: scale=1.0, opacity=1.0
└─ 目标 Grid: 不显示  ← 不显示

跟手缩放
├─ 主 Grid: scale=0.97~1.05, opacity=1.0
└─ 目标 Grid: 不显示  ← 不显示

即将到达目标
├─ 主 Grid: scale=0.97~1.05, opacity=1.0
└─ 目标 Grid: scale=1.0, opacity=1.0  ← 显示

切换完成
├─ 主 Grid: scale=1.0, opacity=1.0
└─ 目标 Grid: 不显示  ← 隐藏
```

## 与官方实现的对比

| 方面 | 官方实现 | 优化后的实现 |
|------|----------|--------------|
| **透明度变化** | 只在切换时 | 只在切换时 |
| **缩放范围** | 0.97~1.05 | 0.97~1.05 |
| **目标 Grid 显示** | 即将到达时 | 即将到达时 |
| **跟手效果** | 只缩放 | 只缩放 |

## 测试要点

### 1. 透明度变化

- [ ] Pinch 开始时不显示目标 Grid
- [ ] 跟手缩放时不改变透明度
- [ ] 即将到达目标时显示目标 Grid
- [ ] 切换完成后隐藏目标 Grid

### 2. 缩放效果

- [ ] 缩放系数在 0.97~1.05 范围内
- [ ] 缩放中心点正确
- [ ] 缩放流畅自然

### 3. 视觉效果

- [ ] 只有一个 Grid 可见（大部分时间）
- [ ] 切换时平滑过渡
- [ ] 没有闪烁或跳变

## 后续优化方向

1. **实现跟手态动画** - 参考官方的 FOLLOW_HAND_STATE
2. **实现离手动画** - 参考官方的 LEAVE_HAND_CURVE
3. **实现状态机集成** - 与 GridFormFsm 集成
4. **实现预加载** - 在即将到达时预加载目标 Grid 数据
