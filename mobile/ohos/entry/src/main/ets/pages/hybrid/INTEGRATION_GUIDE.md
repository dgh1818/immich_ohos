# Hybrid 时间线 Pinch 缩放架构集成指南

## 架构概览

本架构与官方 photo 应用保持一致，采用完整的状态机驱动架构：

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Hybrid Pinch 缩放架构                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Common 基础层                                │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │   │
│  │  │ AbstractFsm     │  │ StateTransfer   │  │ AttributeState      │  │   │
│  │  │ (状态机基类)    │  │ Processor       │  │ Manager             │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         StateManager 层                              │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐  │   │
│  │  │ GridFormFsm     │  │ PinchStateManager│  │ SwitchStartInfo    │  │   │
│  │  │ (形态状态机)    │  │ (缩放管理)      │  │ (锚点信息)         │  │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                          ViewModel 层                                │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │ GridPinchVm (处理 Pinch 手势，计算目标形态)                  │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        ViewController 层                             │   │
│  │  ┌─────────────────┐  ┌─────────────────────────────────────────┐   │   │
│  │  │ AbstractGridVc  │  │ GridAttributeUpdater                    │   │   │
│  │  │ (宫格控制器)    │  │ (属性更新: scale/opacity/zIndex)       │   │   │
│  │  └─────────────────┘  └─────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 文件结构

```
hybrid/
├── common/                          # 公共基础层
│   ├── model/
│   │   ├── AbstractFsm.ts           # 状态机基类
│   │   ├── AttributeStateManager.ts # 属性状态管理器
│   │   ├── ObjectPool.ets           # 对象池
│   │   ├── StateObserverManager.ts  # 状态观察者管理器
│   │   └── StateTransferProcessor.ets # 状态转移处理器
│   └── utils/
│       ├── AbstractInitialAble.ts   # 可初始化基类
│       └── ObserverManager.ts       # 观察者管理器
├── statemanager/                    # 状态管理层
│   ├── constants/
│   │   ├── GridDefine.ts            # 形态索引、列数定义（4种形态）
│   │   └── PinchDefine.ts           # Pinch 动作、方向定义
│   ├── common/
│   │   └── SwitchStartInfo.ets      # 切换开始信息（锚点坐标）
│   ├── GridFormFsm.ets              # 形态状态机（完整版）
│   └── PinchStateManager.ets        # 缩放状态管理器
├── viewmodel/                       # 视图模型层
│   └── GridPinchVm.ets              # Pinch 视图模型
├── viewcontroller/                  # 视图控制器层
│   ├── animation/
│   │   └── AnimationDefine.ets      # 动画参数定义
│   ├── AbstractVc.ets               # 控制器基类、属性更新器
│   └── AbstractGridVc.ets           # 宫格控制器（使用 StateTransferProcessor）
└── HybridPhotoGrid.ets              # 主组件（需改造）
```

## 与官方实现的一致性

| 特性 | 官方实现 | Hybrid 实现 | 状态 |
|------|---------|-------------|------|
| 形态数量 | 4 种 (YEAR/MONTH/DAY/GROUP_DAY) | 4 种 | ✅ 一致 |
| 状态机基类 | AbstractFsm | AbstractFsm | ✅ 一致 |
| 状态转移处理器 | StateTransferProcessor | StateTransferProcessor | ✅ 一致 |
| 属性状态管理 | AttributeStateManager | AttributeStateManager | ✅ 一致 |
| 观察者模式 | ObserverManager | ObserverManager | ✅ 一致 |
| 动作系统 | 8 种状态转换动作 | 8 种状态转换动作 | ✅ 一致 |

## 形态定义

### 4 种形态

| 形态 | FormIndex | 列数 | 说明 |
|------|-----------|------|------|
| YEAR | 0 | 16 | 年视图 |
| MONTH | 1 | 8 | 月视图 |
| DAY | 2 | 4 | 日视图 |
| GROUP_DAY | 3 | 3 | 日分组视图 |

### 状态类型

| 状态 | 说明 |
|------|------|
| INIT_STATE | 初始态（无数据） |
| YEAR_STATE | 年视图态 |
| YEAR_FOLLOW_HAND_STATE | 年视图跟手态 |
| MONTH_STATE | 月视图态 |
| MONTH_FOLLOW_HAND_STATE | 月视图跟手态 |
| DAY_STATE | 日视图态 |
| DAY_FOLLOW_HAND_STATE | 日视图跟手态 |
| GROUP_DAY_STATE | 日分组视图态 |
| GROUP_DAY_FOLLOW_HAND_STATE | 日分组跟手态 |

### 状态转换动作

| 动作名称 | 触发条件 | 作用 |
|---------|---------|------|
| FollowHandArrive | 进入当前形态的跟手态 | 恢复 zIndex，显示背景，设置 opacity=1 |
| FollowHandLeave | 从当前大宫格切换到小宫格的跟手态 | 禁用交互，隐藏背景，设置 opacity=0 |
| LeaveHand | 退出跟手态 | 缩放到目标形态大小 |
| SwitchArriveScale | 切换到达当前形态 | 缩放到目标大小 |
| SwitchArriveOpacity | 切换到达当前形态 | 恢复 zIndex，显示背景，设置 opacity=1 |
| SwitchLeaveScale | 切换离开当前形态 | 缩放到目标大小 |
| SwitchLeaveOpacity | 切换离开当前形态 | 禁用交互，隐藏背景，设置 opacity=0 |
| SwitchOver | 跨层切换 | 设置为低层级，缩放到目标大小 |

## 集成步骤

### 1. 在 HybridPhotoGrid 中引入新架构

```typescript
// 导入新架构组件
import { GridFormFsm, FormEventType, FormStateTypeUtils, FormStateType } from './statemanager/GridFormFsm';
import { PinchStateManager, PinchObserverProxy } from './statemanager/PinchStateManager';
import { GridPinchVm } from './viewmodel/GridPinchVm';
import { AbstractGridVc } from './viewcontroller/AbstractGridVc';
import { FormIndex, getColumnsByFormIndex, DEFAULT_COLUMN } from './statemanager/constants/GridDefine';
import { PinchAction } from './statemanager/constants/PinchDefine';
```

### 2. 声明状态管理器

```typescript
@Entry
@Component
struct HybridPhotoGrid {
  // ... 现有状态变量 ...

  // 新架构：状态管理器
  private formFsm: GridFormFsm = new GridFormFsm(0); // persistentId = 0
  private pinchStateManager: PinchStateManager = new PinchStateManager(0, this.formFsm);
  private pinchObserverProxy: PinchObserverProxy = new PinchObserverProxy(this.pinchStateManager);
  private pinchVm: GridPinchVm = new GridPinchVm(this.formFsm, this.pinchStateManager);
  
  // 四层 Grid 控制器
  private yearGridVc?: AbstractGridVc;
  private monthGridVc?: AbstractGridVc;
  private dayGridVc?: AbstractGridVc;
  private groupDayGridVc?: AbstractGridVc;

  aboutToAppear(): void {
    // 初始化状态机
    this.formFsm.initIsLastFormIsDayGroup(false);
    
    // 初始化 PinchVm
    this.pinchVm.setCurrentColumns(DEFAULT_COLUMN[FormIndex.DAY]);
    
    // 提交数据加载事件
    this.formFsm.submitEvent(FormEventType.DATA_LOADED);
  }
}
```

### 3. 改造 Pinch 手势处理

```typescript
// 替换原有的 handlePinchStart/Update/End 方法
private handlePinchStart(event: GestureEvent): void {
  const centerX = event.pinchCenterX;
  const centerY = event.pinchCenterY;
  
  // 计算锚点项索引
  const anchorItemIndex = this.calculateAnchorItemIndex(centerX, centerY);
  
  // 使用新架构处理
  this.pinchVm.handlePinchStart(
    event.scale,
    centerX,
    centerY,
    this.scrollOffsetY,
    anchorItemIndex
  );
}

private handlePinchUpdate(event: GestureEvent): void {
  this.pinchVm.handlePinchUpdate(
    event.scale,
    event.pinchCenterX,
    event.pinchCenterY
  );
}

private handlePinchEnd(event: GestureEvent): void {
  const targetColumns = this.pinchVm.handlePinchEnd(event.scale, event.velocity);
  
  // 应用目标列数
  if (targetColumns !== this.gridColumns) {
    this.applyGridColumns(targetColumns);
  }
}
```

### 4. 四层 Grid 实现

```typescript
build() {
  Stack() {
    // 第1层：Year Grid（16列）
    if (this.isYearGridInit) {
      Grid() {
        // ... Grid 内容 ...
      }
      .attributeModifier(this.yearAttributeUpdater)
    }

    // 第2层：Month Grid（8列）
    if (this.isMonthGridInit) {
      Grid() {
        // ... Grid 内容 ...
      }
      .attributeModifier(this.monthAttributeUpdater)
    }

    // 第3层：Day Grid（4列）
    if (this.isDayGridInit) {
      Grid() {
        // ... Grid 内容 ...
      }
      .attributeModifier(this.dayAttributeUpdater)
    }

    // 第4层：GroupDay Grid（3列）
    if (this.isGroupDayGridInit) {
      Grid() {
        // ... Grid 内容 ...
      }
      .attributeModifier(this.groupDayAttributeUpdater)
    }
  }
  .gesture(this.buildPinchGesture())
}

// 属性更新器
private yearAttributeUpdater: GridAttributeUpdater = new GridAttributeUpdater();
private monthAttributeUpdater: GridAttributeUpdater = new GridAttributeUpdater();
private dayAttributeUpdater: GridAttributeUpdater = new GridAttributeUpdater();
private groupDayAttributeUpdater: GridAttributeUpdater = new GridAttributeUpdater();
```

### 5. 监听状态变化

```typescript
aboutToAppear(): void {
  // 监听状态机状态变化
  this.formFsm.registerObserver({
    onStateChange: (oldState, newState, event) => {
      console.log(`[FSM] ${FormStateType[oldState]} -> ${FormStateType[newState]} by ${FormEventType[event]}`);
      
      // 根据新状态更新 Grid 初始化标记
      if (FormStateTypeUtils.isInYearState(newState)) {
        this.isYearGridInit = true;
      } else if (FormStateTypeUtils.isInMonthState(newState)) {
        this.isMonthGridInit = true;
      } else if (FormStateTypeUtils.isInDayState(newState)) {
        this.isDayGridInit = true;
      } else if (FormStateTypeUtils.isInGroupDayState(newState)) {
        this.isGroupDayGridInit = true;
      }
    }
  }, true);
}
```

## 状态转换流程

```
用户捏合手势
     │
     ▼
GridPinchVm.handlePinchStart()
     │
     ├── 构建 SwitchStartInfo（锚点坐标）
     │
     └── PinchStateManager.updatePinchState(START)
              │
              ▼
         GridFormFsm.submitEvent(PINCH_START)
              │
              ▼
         状态转换: DAY_STATE -> DAY_FOLLOW_HAND_STATE
              │
              ▼
         StateTransferProcessor.onStateChange()
              │
              ├── 匹配 FollowHandArrive 动作
              │
              └── 执行: prepareAction() + animateTo(targetAction())
```

## 调试技巧

1. **打印状态转换日志**:
```typescript
this.formFsm.registerObserver({
  onStateChange: (oldState, newState, event) => {
    console.log(`[FSM] ${FormStateType[oldState]} -> ${FormStateType[newState]} by ${FormEventType[event]}`);
  }
}, true);
```

2. **打印缩放系数**:
```typescript
this.pinchObserverProxy.getGridPinchScale(FormIndex.DAY, (oldScale, newScale) => {
  console.log(`[Scale] DAY: ${oldScale.toFixed(3)} -> ${newScale.toFixed(3)}`);
});
```

3. **打印锚点信息**:
```typescript
const info = this.pinchObserverProxy.switchStartInfo;
if (info) {
  console.log(`[Anchor] (${info.anchorCenterX}, ${info.anchorCenterY})`);
}
```

## 关键差异说明

本实现与官方 photo 应用完全一致，包括：

1. **完整的状态机架构** - 使用 AbstractFsm 基类
2. **StateTransferProcessor** - 统一管理状态转换动作
3. **4 种形态** - YEAR/MONTH/DAY/GROUP_DAY
4. **8 种状态转换动作** - 与官方完全一致
5. **观察者模式** - 使用 ObserverManager 管理监听者
6. **对象池** - 使用 ObjectPool 管理事件对象

唯一差异：日志系统使用 console 替代 LogUtils（可根据需要引入）
