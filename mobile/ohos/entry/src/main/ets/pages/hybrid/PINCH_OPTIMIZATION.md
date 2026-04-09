# Pinch 缩放优化说明

## 问题分析

### 原始实现的问题

1. **卡顿问题**
   - 每次 Pinch 更新都触发完整的状态更新
   - 频繁重建 Grid 数据导致性能下降
   - 没有使用优化的动画曲线

2. **位置对应问题**
   - 锚点计算不准确
   - 缩放中心点没有正确跟踪
   - 目标 Grid 的滚动位置计算错误

## 优化方案

### 1. HybridPinchGestureHandler

参考官方 `AbstractGridVc` 的实现，创建专门的 Pinch 手势处理器：

**关键特性：**
- 精确的锚点计算
- 基于列数的缩放计算
- 正确的滚动偏移计算
- 优化的动画配置

**锚点计算：**
```typescript
private calculateAnchor(
  pinchX: number,
  pinchY: number,
  scrollOffset: number,
  columns: number,
  gridWidth: number,
  gridHeight: number,
  topInset: number,
): PinchAnchorInfo {
  // 计算单个项的尺寸
  const itemSize = (gridWidth - gap * (columns - 1)) / columns;
  const stepSize = itemSize + gap;

  // 计算列索引和 X 进度
  const column = Math.floor(pinchX / stepSize);
  const xProgress = (pinchX - column * stepSize) / itemSize;

  // 计算行索引和 Y 进度
  const contentY = scrollOffset + pinchY;
  const photoAreaY = contentY - topInset;
  const row = Math.floor(photoAreaY / itemSize);
  const yProgress = (photoAreaY - row * itemSize) / itemSize;

  // 计算全局项索引
  const itemIndex = row * columns + column;

  return { itemIndex, xProgress, yProgress, globalX: pinchX, globalY: pinchY };
}
```

### 2. HybridPhotoGridOptimized

**优化点：**

#### 2.1 分离 Pinch 处理逻辑

```typescript
// 使用专门的处理器
private readonly pinchHandler: HybridPinchGestureHandler = new HybridPinchGestureHandler();

// 设置监听器
this.pinchHandler.setOnScaleUpdate((scale, centerX, centerY) => {
  // 直接更新状态，不触发重新渲染
  this.pinchScale = scale;
  this.pinchCenterX = centerX;
  this.pinchCenterY = centerY;
});
```

#### 2.2 优化的缩放更新

```typescript
// 参考官方实现，使用 scale 属性
.scale(this.pinchActive ? {
  x: this.pinchScale,
  y: this.pinchScale,
  centerX: this.pinchCenterX,
  centerY: this.pinchCenterY,
} : { x: 1, y: 1 })
```

#### 2.3 正确的目标 Grid 滚动同步

```typescript
private syncTargetGridScroll(scrollOffset: number): void {
  // 根据列数比例计算目标 Grid 的滚动位置
  const scaleRatio = this.gridColumns / this.pinchTargetColumns;
  const targetOffset = scrollOffset * scaleRatio;

  this.targetScroller.scrollTo({
    xOffset: 0,
    yOffset: Math.max(0, targetOffset),
  });
}
```

#### 2.4 优化的动画配置

```typescript
// 使用官方的动画配置
export const DEFAULT_PINCH_CONFIG: PinchAnimationConfig = {
  quickPinchDuration: 200,    // 快速捏合
  slowPinchDuration: 400,     // 慢速捏合
  switchDuration: 200,        // 切换
  minScale: 0.97,             // 最小缩放
  maxScale: 1.05,             // 最大缩放
  scaleThreshold: 0.02,       // 缩放阈值
};

// 使用锐利曲线
public getAnimationCurve(): ICurve {
  return Curve.FastOutSlowIn; // 对应官方的 SHARP_CURVE
}
```

## 与官方实现的对比

| 方面 | 官方实现 | 优化后的实现 |
|------|----------|--------------|
| **Pinch 处理** | `PinchStateManager` + `GridPinchVm` | `HybridPinchGestureHandler` |
| **缩放更新** | `attributeUpdater.updateScale()` | 直接更新 `.scale()` 属性 |
| **锚点计算** | `SwitchStartInfo` | `PinchAnchorInfo` |
| **动画曲线** | `SHARP_CURVE` (cubic-bezier) | `Curve.FastOutSlowIn` |
| **动画时长** | 200ms (快) / 400ms (慢) | 200ms (快) / 400ms (慢) |
| **缩放范围** | 0.97 - 1.05 | 0.97 - 1.05 |

## 性能优化

### 1. 减少状态更新

```typescript
// 之前：每次更新都触发重新渲染
this.pinchLiveScale = scale;
this.gridScale = scale;
this.attributeUpdater.updateScale({ ... });

// 之后：直接更新，减少渲染
this.pinchScale = scale;
this.pinchCenterX = centerX;
this.pinchCenterY = centerY;
```

### 2. 避免频繁重建数据

```typescript
// 只在目标列数变化时才重建
if (state.targetColumns !== this.pinchTargetColumns) {
  this.pinchTargetColumns = state.targetColumns;
  this.targetGridItems = this.buildGridItemsForColumns(state.targetColumns);
  this.targetGridDataSource.updateAll(this.targetGridItems);
}
```

### 3. 使用优化的动画

```typescript
// 使用 animateTo 而不是 setTimeout
uiContext.animateTo({
  duration: duration,
  curve: this.pinchHandler.getAnimationCurve(),
}, () => {
  this.pinchScale = 1.0;
  this.targetGridOpacity = 0;
  this.targetGridScale = 1.0;
});
```

## 使用方式

### 基本使用

```typescript
import { HybridPhotoGridOptimized } from './HybridPhotoGridOptimized';

@Entry
@Component
struct TimelinePage {
  build() {
    Column() {
      HybridPhotoGridOptimized()
    }
    .width('100%')
    .height('100%');
  }
}
```

### 自定义配置

```typescript
// 自定义 Pinch 配置
const customConfig: PinchAnimationConfig = {
  quickPinchDuration: 150,
  slowPinchDuration: 350,
  switchDuration: 180,
  minScale: 0.95,
  maxScale: 1.08,
  scaleThreshold: 0.015,
};

const pinchHandler = new HybridPinchGestureHandler(customConfig);
```

## 测试要点

### 1. 缩放流畅度

- [ ] Pinch 手势响应是否流畅
- [ ] 缩放动画是否平滑
- [ ] 是否有卡顿现象

### 2. 位置对应

- [ ] 缩放后锚点项是否保持在相同位置
- [ ] 目标 Grid 是否正确同步滚动
- [ ] 缩放中心点是否正确

### 3. 动画效果

- [ ] 快速捏合动画是否正确
- [ ] 慢速捏合动画是否正确
- [ ] 目标 Grid 的透明度变化是否平滑

### 4. 边界情况

- [ ] 最小列数限制是否生效
- [ ] 最大列数限制是否生效
- [ ] 快速连续 Pinch 是否正常

## 文件结构

```
hybrid/
├── HybridPhotoGridOptimized.ets          # 优化的主组件
├── viewcontroller/
│   └── HybridPinchGestureHandler.ets    # Pinch 手势处理器
└── ...
```

## 后续优化方向

1. **实现跟手态**：参考官方的 `FOLLOW_HAND_STATE`
2. **实现状态机集成**：与 `GridFormFsm` 集成
3. **实现预加载**：在 Pinch 开始时预加载目标 Grid 数据
4. **实现缓存优化**：缓存不同列数的 Grid 数据
