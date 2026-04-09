# Pinch 位置对应优化说明

## 问题分析

原始实现的位置对应不准确，主要问题：

1. **锚点计算过于简单** - 没有考虑项的精确位置和进度
2. **滚动偏移计算错误** - 简单的比例缩放无法保证锚点位置
3. **缺少补位计算** - 没有处理列数变化时的补位问题

## 官方实现分析

### 核心概念

官方使用 `SwitchStartInfo` 和 `SwitchCalcUtils` 来精确计算切换时的位置：

1. **SwitchStartInfo** - 记录切换开始时的信息
   - `anchorItemIndex` - 锚点项索引
   - `anchorCenterX/Y` - 锚点中心坐标
   - `cachedAnchorCenterXs` - 缓存不同形态的锚点 X 坐标

2. **SwitchCalcUtils** - 计算切换信息
   - `calcFillPosition` - 计算补位
   - `calcScrollOffset` - 计算滚动偏移
   - `calcAnchorCenterX` - 计算锚点中心 X

### 关键算法

#### 1. 锚点列计算

```typescript
// 官方：SwitchCommonUtils.getAnchorColumn
const itemWidth = (gridWidth - gap * (columns - 1)) / columns;
const stepX = itemWidth + gap;
const column = Math.floor(startX / stepX);
```

#### 2. 补位计算

```typescript
// 官方：SwitchCalcUtils.calcFillPosition
const targetColumn = getAnchorColumn(startInfo.startX, gridOp, gridForm);
const gridColumn = gridOp.getGridColumn(gridForm);
const originalColumn = startInfo.anchorItemIndex % gridColumn;
let fillPosition = targetColumn - originalColumn;
if (fillPosition < 0) {
  fillPosition += gridColumn;
}
```

#### 3. 滚动偏移计算

```typescript
// 官方：SwitchCalcUtils.calcDefaultScrollOffset
const irregularHeight = gridOp.getIrregularHeight(gridForm);
const aboveImageRows = Math.floor((anchorItemIndex + fillPosition) / gridColumn);
const imageHeightWithGutter = getImageHeight(gridOp, gridForm);
const hideGridHeight = aboveImageRows * imageHeightWithGutter;
const imageAlignHeight = gridOp.getGridImageHeight(gridForm) / 2; // 中间对齐
let scrollOffset = irregularHeight + hideGridHeight + imageAlignHeight - anchorCenterY;
```

#### 4. 锚点中心 X 计算

```typescript
// 官方：SwitchCalcUtils.calcAnchorCenterX
const originalWidth = getImageWidth(gridOp, startForm);
const originalColumn = getAnchorColumn(startInfo.startX, gridOp, startForm);
const originalStartX = originalColumn * originalWidth;

const targetWidth = getImageWidth(gridOp, targetForm);
const targetColumn = getAnchorColumn(startInfo.startX, gridOp, targetForm);
const targetStartX = targetColumn * targetWidth;

let anchorCenterX = originalStartX;
if (originalWidth !== targetWidth) {
  anchorCenterX += (originalStartX - targetStartX) * originalWidth / (targetWidth - originalWidth);
}
```

## 优化实现

### 1. HybridSwitchCalc

创建专门的切换计算工具类，参考官方实现：

```typescript
export class HybridSwitchCalc {
  // 计算锚点信息
  public static calculateAnchor(
    pinchX: number,
    pinchY: number,
    scrollOffset: number,
    columns: number,
    gridWidth: number,
    gridHeight: number,
    topInset: number,
    gap: number,
  ): AnchorInfo {
    // 计算项尺寸
    const itemWidth = (gridWidth - gap * (columns - 1)) / columns;
    const itemHeight = itemWidth;
    const stepX = itemWidth + gap;
    const stepY = itemHeight + gap;

    // 计算列和行
    const column = Math.floor(pinchX / stepX);
    const row = Math.floor((scrollOffset + pinchY - topInset) / stepY);

    // 计算进度
    const xProgress = (pinchX - column * stepX) / itemWidth;
    const yProgress = ((scrollOffset + pinchY - topInset) - row * stepY) / itemHeight;

    // 计算锚点中心
    const anchorCenterX = column * stepX + itemWidth * xProgress;
    const anchorCenterY = topInset + row * stepY + itemHeight * yProgress;

    return { itemIndex, column, row, xProgress, yProgress, anchorCenterX, anchorCenterY };
  }

  // 计算切换信息
  public static calcSwitch(params: SwitchCalcParams): SwitchCalcResult {
    // 计算补位
    const fillPosition = calcFillPosition(...);

    // 计算滚动偏移
    const scrollOffset = calcScrollOffset(...);

    // 计算锚点中心 X
    const anchorCenterX = calcAnchorCenterX(...);

    return { scrollOffset, anchorCenterX, fillPosition };
  }
}
```

### 2. HybridPinchGestureHandler 更新

使用新的计算方法：

```typescript
// 开始 Pinch
public start(...): PinchState {
  // 使用 HybridSwitchCalc.calculateAnchor
  const anchor = HybridSwitchCalc.calculateAnchor(
    pinchCenterX, pinchCenterY, scrollOffset,
    currentColumns, gridWidth, gridHeight, topInset,
  );

  this.state.centerX = anchor.anchorCenterX;
  this.state.centerY = anchor.anchorCenterY;
}

// 结束 Pinch
public end(): PinchEndResult {
  // 使用 HybridSwitchCalc.calcSwitch
  const calcParams = new SwitchCalcParams();
  calcParams.startColumns = this.state.startColumns;
  calcParams.targetColumns = this.state.targetColumns;
  calcParams.anchor = this.state.anchor;
  // ...

  const calcResult = HybridSwitchCalc.calcSwitch(calcParams);
  result.scrollOffset = calcResult.scrollOffset;
}
```

## 关键改进

### 1. 精确的锚点计算

**之前：**
```typescript
// 简单的索引计算
const itemIndex = row * columns + column;
```

**现在：**
```typescript
// 精确的位置和进度计算
const xProgress = (pinchX - columnStartX) / itemWidth;
const yProgress = (photoAreaY - rowStartY) / itemHeight;
const anchorCenterX = columnStartX + itemWidth * xProgress;
const anchorCenterY = topInset + rowStartY + itemHeight * yProgress;
```

### 2. 正确的滚动偏移

**之前：**
```typescript
// 简单的比例缩放
const scaleRatio = startColumns / targetColumns;
const newOffset = startScrollOffset * scaleRatio;
```

**现在：**
```typescript
// 基于锚点位置计算
const aboveImageRows = Math.floor((anchorItemIndex + fillPosition) / targetColumns);
const hideGridHeight = aboveImageRows * stepY;
const imageAlignHeight = itemHeight / 2; // 中间对齐
let scrollOffset = topInset + hideGridHeight + imageAlignHeight - anchorCenterY;
```

### 3. 补位处理

**之前：**
```typescript
// 没有补位计算
```

**现在：**
```typescript
// 计算补位
const targetColumn = calcAnchorColumn(anchor.globalX, targetColumns, gridWidth, gap);
const originalColumn = anchor.column;
let fillPosition = targetColumn - originalColumn;
if (fillPosition < 0) {
  fillPosition += targetColumns;
}
```

## 文件结构

```
hybrid/
├── viewmodel/
│   └── HybridSwitchCalc.ets          # 切换计算工具类
├── viewcontroller/
│   └── HybridPinchGestureHandler.ets # Pinch 手势处理器（已更新）
└── HybridPhotoGridOptimized.ets      # 主组件
```

## 测试要点

### 1. 锚点位置

- [ ] Pinch 缩放后，锚点项是否保持在相同位置
- [ ] 不同位置的锚点是否都能正确对应
- [ ] 边界位置的锚点是否正常

### 2. 滚动同步

- [ ] 目标 Grid 的滚动位置是否正确
- [ ] 缩放后滚动到正确位置
- [ ] 快速连续 Pinch 是否正常

### 3. 列数变化

- [ ] 放大（减少列数）位置正确
- [ ] 缩小（增加列数）位置正确
- [ ] 跨多级列数变化位置正确

## 与官方实现的对比

| 方面 | 官方实现 | 优化后的实现 |
|------|----------|--------------|
| **锚点计算** | `SwitchStartInfo` | `AnchorInfo` |
| **切换计算** | `SwitchCalcUtils` | `HybridSwitchCalc` |
| **补位计算** | `calcFillPosition` | `calcFillPosition` |
| **滚动计算** | `calcScrollOffset` | `calcScrollOffset` |
| **中心 X 计算** | `calcAnchorCenterX` | `calcAnchorCenterX` |

## 后续优化方向

1. **实现分组模式** - 支持 GROUP_DAY 模式的切换计算
2. **实现不规则区域** - 支持顶部不规则区域（消息头等）
3. **实现缓存优化** - 缓存不同形态的锚点坐标
4. **实现预计算** - 在 Pinch 开始时预计算所有形态的位置
