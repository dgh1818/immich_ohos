import * as Shared from '../HybridPhotoGridShared';
import {
  AnchorInfo,
  HybridSwitchCalc,
  SwitchCalcParams,
} from '../viewmodel/HybridSwitchCalc';
import {
  FormIndex,
  getColumnsByFormIndex,
  getFormIndexByColumns,
} from '../statemanager/constants/GridDefine';

export enum HybridPinchTargetDirection {
  NONE = 0,
  SHRINK = 1,
  EXPAND = 2,
}

const PINCH_DIRECTION_EPSILON: number = 0.002;

export class HybridPinchStateInfo {
  anchor: AnchorInfo = new AnchorInfo();
  currentForm: FormIndex = FormIndex.DAY;
  targetForm: FormIndex = FormIndex.DAY;
  startColumns: number = getColumnsByFormIndex(FormIndex.DAY);
  targetColumns: number = getColumnsByFormIndex(FormIndex.DAY);
  startScrollOffset: number = 0;
  progress: number = 0;
  liveScale: number = 1;
  pinchCenterX: number = 0;
  pinchCenterY: number = 0;
  gridWidth: number = 0;
  gridHeight: number = 0;
  topInset: number = 0;
  totalPhotoCount: number = 0;
  desiredFocusX: number = 0;
  desiredFocusY: number = 0;
  resolvedFocusX: number = 0;
  resolvedFocusY: number = 0;
  sharedCenterX: number = 0;
  sharedCenterY: number = 0;
  targetBaseScale: number = 1;
  targetVisualScale: number = 1;
  targetAnchorX: number = 0;
  targetAnchorY: number = 0;
  targetScrollOffset: number = 0;
  targetFirstPhotoIndex: number = 0;
  targetAnchorPhotoIndex: number = 0;
  targetFirstRowIndex: number = 0;
  targetAnchorRowIndex: number = 0;
  targetVisibleAnchorOffsetY: number = 0;
  fillPosition: number = 0;
  anchorItemIndex: number = 0;
  extraOffset: number = 0;
  targetDirection: HybridPinchTargetDirection = HybridPinchTargetDirection.NONE;
}

export class HybridPreviewTransformInfo {
  scale: number = 1;
  translateX: number = 0;
  translateY: number = 0;
  scrollOffset: number = 0;
}

export class HybridPhotoGridAnchorAdapter {
  public createPinchState(
    currentColumns: number,
    pinchCenterX: number,
    pinchCenterY: number,
    scrollOffset: number,
    gridWidth: number,
    gridHeight: number,
    topInset: number,
    totalPhotoCount: number,
  ): HybridPinchStateInfo {
    const state = new HybridPinchStateInfo();
    state.currentForm = getFormIndexByColumns(currentColumns);
    state.targetForm = state.currentForm;
    state.startColumns = currentColumns;
    state.targetColumns = currentColumns;
    state.startScrollOffset = scrollOffset;
    state.pinchCenterX = pinchCenterX;
    state.pinchCenterY = pinchCenterY;
    state.gridWidth = gridWidth;
    state.gridHeight = gridHeight;
    state.topInset = topInset;
    state.totalPhotoCount = Math.max(0, totalPhotoCount);
    state.desiredFocusX = pinchCenterX;
    state.desiredFocusY = pinchCenterY;
    state.resolvedFocusX = pinchCenterX;
    state.resolvedFocusY = pinchCenterY;
    state.sharedCenterX = pinchCenterX;
    state.sharedCenterY = pinchCenterY;
    state.anchor = HybridSwitchCalc.calculateAnchor(
      pinchCenterX,
      pinchCenterY,
      scrollOffset,
      currentColumns,
      gridWidth,
      gridHeight,
      topInset,
    );
    return state;
  }

  public updatePinchState(
    state: HybridPinchStateInfo,
    scale: number,
    pinchCenterX: number,
    pinchCenterY: number,
  ): void {
    const clampedScale = Math.max(0.5, Math.min(2.0, scale));
    state.pinchCenterX = pinchCenterX;
    state.pinchCenterY = pinchCenterY;
    state.liveScale = clampedScale;
    state.targetForm = this.resolveTargetForm(clampedScale, state.startColumns);
    state.targetColumns = Math.min(
      Shared.HYBRID_GRID_MAX_COLUMNS,
      getColumnsByFormIndex(state.targetForm),
    );

    // When at a clamped column count (e.g. 6, clamped from MONTH=8), expanding should
    // first return to the current form's natural column count (DAY=4) before jumping to
    // the next form (GROUP_DAY=3). Without this, 6→3 skips 4 entirely.
    const currentFormColumns = getColumnsByFormIndex(getFormIndexByColumns(state.startColumns));
    if (
      state.targetColumns < state.startColumns &&
      currentFormColumns < state.startColumns &&
      currentFormColumns > state.targetColumns
    ) {
      state.targetColumns = currentFormColumns;
      state.targetForm = getFormIndexByColumns(currentFormColumns);
    }

    state.targetDirection = this.resolveTargetDirection(state);
    state.desiredFocusX = pinchCenterX;
    state.desiredFocusY = pinchCenterY;
    state.resolvedFocusX = pinchCenterX;
    state.resolvedFocusY = pinchCenterY;
    state.sharedCenterX = pinchCenterX;
    state.sharedCenterY = pinchCenterY;

    const delta = Math.abs(clampedScale - 1);
    let progress = Math.max(0, Math.min(1, delta / 0.35));
    if (state.targetColumns !== state.startColumns) {
      progress = Math.max(progress, 0.12);
    }
    state.progress = progress;

    if (state.targetColumns === state.startColumns || state.gridWidth <= 0) {
      const scrollToIndexParams = HybridSwitchCalc.calcScrollToIndexParams(
        state.anchor,
        Math.max(1, state.targetColumns),
        state.startScrollOffset,
        state.gridWidth,
        state.topInset,
        Shared.HYBRID_GRID_GAP,
      );
      state.targetBaseScale = 1;
      state.targetVisualScale = 1;
      state.targetAnchorX = state.pinchCenterX;
      state.targetAnchorY = state.pinchCenterY;
      state.targetScrollOffset = Math.max(0, state.startScrollOffset);
      state.targetAnchorPhotoIndex = this.clamp(
        state.anchor.itemIndex,
        0,
        Math.max(0, state.totalPhotoCount - 1),
      );
      state.targetFirstPhotoIndex = state.targetAnchorPhotoIndex;
      state.targetAnchorRowIndex = Math.floor(state.targetAnchorPhotoIndex / Math.max(1, state.startColumns));
      state.targetFirstRowIndex = state.targetAnchorRowIndex;
      state.targetVisibleAnchorOffsetY = state.anchor.anchorCenterY - state.startScrollOffset;
      state.fillPosition = 0;
      state.anchorItemIndex = scrollToIndexParams.itemIndex;
      state.extraOffset = scrollToIndexParams.extraOffset;
      return;
    }

    const currentItemSize = HybridSwitchCalc.calcItemSize(state.startColumns, state.gridWidth);
    const targetItemSize = HybridSwitchCalc.calcItemSize(state.targetColumns, state.gridWidth);
    if (currentItemSize <= 0 || targetItemSize <= 0) {
      const scrollToIndexParams = HybridSwitchCalc.calcScrollToIndexParams(
        state.anchor,
        Math.max(1, state.targetColumns),
        state.startScrollOffset,
        state.gridWidth,
        state.topInset,
        Shared.HYBRID_GRID_GAP,
      );
      state.targetBaseScale = 1;
      state.targetVisualScale = 1;
      state.targetAnchorX = state.pinchCenterX;
      state.targetAnchorY = state.pinchCenterY;
      state.targetScrollOffset = Math.max(0, state.startScrollOffset);
      state.targetAnchorPhotoIndex = this.clamp(
        state.anchor.itemIndex,
        0,
        Math.max(0, state.totalPhotoCount - 1),
      );
      state.targetFirstPhotoIndex = state.targetAnchorPhotoIndex;
      state.targetAnchorRowIndex = Math.floor(state.targetAnchorPhotoIndex / Math.max(1, state.startColumns));
      state.targetFirstRowIndex = state.targetAnchorRowIndex;
      state.targetVisibleAnchorOffsetY = state.anchor.anchorCenterY - state.startScrollOffset;
      state.fillPosition = 0;
      state.anchorItemIndex = scrollToIndexParams.itemIndex;
      state.extraOffset = scrollToIndexParams.extraOffset;
      return;
    }

    const switchParams = new SwitchCalcParams();
    switchParams.startColumns = state.startColumns;
    switchParams.targetColumns = state.targetColumns;
    switchParams.startScrollOffset = state.startScrollOffset;
    switchParams.anchor = state.anchor;
    switchParams.gridWidth = state.gridWidth;
    switchParams.gridHeight = state.gridHeight;
    switchParams.topInset = state.topInset;
    switchParams.gap = Shared.HYBRID_GRID_GAP;
    const switchResult = HybridSwitchCalc.calcSwitch(switchParams);
    const safeTargetAnchorPhotoIndex = this.clamp(
      state.anchor.itemIndex,
      0,
      Math.max(0, state.totalPhotoCount - 1),
    );
    const scrollToIndexParams = HybridSwitchCalc.calcScrollToIndexParams(
      state.anchor,
      Math.max(1, state.targetColumns),
      state.startScrollOffset,
      state.gridWidth,
      state.topInset,
      Shared.HYBRID_GRID_GAP,
    );
    const targetStep = targetItemSize + Shared.HYBRID_GRID_GAP;
    const targetRow = Math.max(0, Math.floor(safeTargetAnchorPhotoIndex / Math.max(1, state.targetColumns)));
    const targetColumn = Math.max(0, safeTargetAnchorPhotoIndex % Math.max(1, state.targetColumns));
    const targetAnchorX = targetColumn * targetStep + state.anchor.xProgress * targetItemSize;
    const targetAnchorContentY = targetRow * targetStep + state.anchor.yProgress * targetItemSize;
    const targetAnchorY = state.topInset + targetAnchorContentY;
    const targetBaseScale = currentItemSize / targetItemSize;
    const desiredFocusX = switchResult?.anchorCenterX ?? pinchCenterX;
    const desiredFocusY = pinchCenterY;
    const resolvedFocusX = this.clamp(desiredFocusX, 0, state.gridWidth);
    const resolvedFocusY = this.clamp(desiredFocusY, state.topInset, Math.max(state.topInset, state.gridHeight));
    const contentRows = Math.max(1, Math.ceil(Math.max(0, state.totalPhotoCount) / Math.max(1, state.targetColumns)));
    const contentHeight =
      contentRows * targetItemSize +
      Math.max(0, contentRows - 1) * Shared.HYBRID_GRID_GAP;
    const maxScrollOffset = Math.max(0, contentHeight - state.gridHeight);
    const targetScrollOffset = this.clamp(
      Math.floor(scrollToIndexParams.itemIndex / Math.max(1, state.targetColumns)) * targetStep -
        scrollToIndexParams.extraOffset,
      0,
      maxScrollOffset,
    );
    const targetFirstPhotoIndex = this.clamp(
      state.targetColumns * Math.floor(targetScrollOffset / Math.max(1, targetStep)),
      0,
      Math.max(0, state.totalPhotoCount - 1),
    );

    state.targetBaseScale = targetBaseScale;
    state.targetVisualScale = targetBaseScale * clampedScale;
    state.targetAnchorX = targetAnchorX;
    state.targetAnchorY = targetAnchorY;
    state.fillPosition = 0;
    state.targetScrollOffset = targetScrollOffset;
    state.targetFirstPhotoIndex = targetFirstPhotoIndex;
    state.targetAnchorPhotoIndex = safeTargetAnchorPhotoIndex;
    state.targetFirstRowIndex = Math.floor(targetFirstPhotoIndex / Math.max(1, state.targetColumns));
    state.targetAnchorRowIndex = Math.floor(safeTargetAnchorPhotoIndex / Math.max(1, state.targetColumns));
    state.targetVisibleAnchorOffsetY = targetAnchorContentY - targetScrollOffset;
    state.anchorItemIndex = scrollToIndexParams.itemIndex;
    state.extraOffset = scrollToIndexParams.extraOffset;
    state.desiredFocusX = desiredFocusX;
    state.desiredFocusY = desiredFocusY;
    state.resolvedFocusX = resolvedFocusX;
    state.resolvedFocusY = resolvedFocusY;
    state.sharedCenterX = resolvedFocusX;
    state.sharedCenterY = resolvedFocusY;
  }

  public resolveTargetForm(scale: number, currentColumns: number): FormIndex {
    const currentForm = getFormIndexByColumns(currentColumns);
    if (scale < 1 - PINCH_DIRECTION_EPSILON) {
      return Math.max(0, currentForm - 1) as FormIndex;
    }
    if (scale > 1 + PINCH_DIRECTION_EPSILON) {
      return Math.min(FormIndex.GROUP_DAY, currentForm + 1) as FormIndex;
    }
    return currentForm;
  }

  public resolvePreviewTransform(state: HybridPinchStateInfo): HybridPreviewTransformInfo {
    return this.resolvePreviewTransformForVisualScale(state, state.targetVisualScale);
  }

  public resolveSettledPreviewTransform(state: HybridPinchStateInfo): HybridPreviewTransformInfo {
    const info = new HybridPreviewTransformInfo();
    if (state.targetColumns <= 0 || state.targetColumns === state.startColumns) {
      return info;
    }
    info.scale = 1;
    info.translateX = 0;
    info.translateY = 0;
    info.scrollOffset = Math.max(0, state.targetScrollOffset);
    return info;
  }

  public resolvePreviewTransformForVisualScale(
    state: HybridPinchStateInfo,
    visualScale: number,
  ): HybridPreviewTransformInfo {
    const info = new HybridPreviewTransformInfo();
    if (state.targetColumns <= 0 || state.targetColumns === state.startColumns || state.gridWidth <= 0) {
      return info;
    }

    info.scale = visualScale;
    info.translateX = 0;
    info.translateY = 0;
    info.scrollOffset = Math.max(0, state.targetScrollOffset);
    return info;
  }

  public resolveFinalScrollOffset(state: HybridPinchStateInfo): number {
    if (state.targetColumns <= 0) {
      return Math.max(0, state.startScrollOffset);
    }
    return Math.max(0, state.targetScrollOffset);
  }

  public resolveSharedScaleForVisualScale(state: HybridPinchStateInfo, visualScale: number): number {
    if (Math.abs(state.targetBaseScale) <= 0.0001) {
      return 1;
    }
    return visualScale / state.targetBaseScale;
  }

  private resolveTargetDirection(state: HybridPinchStateInfo): HybridPinchTargetDirection {
    if (state.targetColumns > state.startColumns) {
      return HybridPinchTargetDirection.SHRINK;
    }
    if (state.targetColumns < state.startColumns) {
      return HybridPinchTargetDirection.EXPAND;
    }
    return HybridPinchTargetDirection.NONE;
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }
}
