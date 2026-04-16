import { componentSnapshot } from '@kit.ArkUI';
import { StateChangeCallback } from '../common/model/StateObserverManager';
import { GridStateProxy } from '../statemanager/GridStateProxy';
import { FormIndex } from '../statemanager/constants/GridDefine';
import { RestoreFpStateType } from '../statemanager/GridRestoreFpFsm';
import { AnimationCurve, AnimationDuration, AnimationOpacity } from './animation/AnimationDefine';
import { PhotoGridViewId } from './PhotoGridVc';
import { GridSnapshotVm } from '../viewmodel/GridSnapshotVm';

@Observed
export class GridSnapshotVc {
  @Track public snapshotImage?: PixelMap;
  @Track public isVisible: boolean = false;
  @Track public snapshotOpacity: number = AnimationOpacity.DEFAULT;
  @Track public snapshotOffsetY: number = 0;

  private readonly viewModel: GridSnapshotVm = new GridSnapshotVm();
  private readonly scrollOffsetListener: StateChangeCallback<number, string | number> = (): void => {
    this.updateSnapshotOffset();
  };
  private readonly irregularHeightListener: StateChangeCallback<number, string | number> = (): void => {
    this.updateSnapshotOffset();
  };
  private readonly restoreStateListener: StateChangeCallback<RestoreFpStateType, string | number> = (
    _oldState: RestoreFpStateType,
    restoreState: RestoreFpStateType,
  ): void => {
    this.handleRestoreStateChanged(restoreState);
  };

  public bindStateProxy(stateProxy: GridStateProxy): void {
    this.viewModel.bindStateProxy(stateProxy);
    this.registerRestoreStateObserver();
  }

  public get restoreFpState(): RestoreFpStateType {
    return this.viewModel.getRestoreState();
  }

  public showSnapshot(snapshotImage?: PixelMap): void {
    const nextSnapshot = snapshotImage ?? this.snapshotImage;
    if (this.snapshotImage && this.snapshotImage !== nextSnapshot) {
      this.releaseSnapshotImage(this.snapshotImage);
    }
    this.snapshotImage = nextSnapshot;
    this.snapshotOpacity = AnimationOpacity.DEFAULT;
    this.snapshotOffsetY = 0;
    this.isVisible = nextSnapshot !== undefined;
  }

  public hideSnapshot(): void {
    this.clearSnapshotOffsetObservers();
    const currentSnapshot = this.snapshotImage;
    this.snapshotImage = undefined;
    this.isVisible = false;
    this.snapshotOpacity = AnimationOpacity.DEFAULT;
    this.snapshotOffsetY = 0;
    if (currentSnapshot) {
      this.releaseSnapshotImage(currentSnapshot);
    }
  }

  public cancelRestoreAnimation(): void {
    this.viewModel.cancelRestoreAnimation();
    this.hideSnapshot();
  }

  public resetRestoreFpState(): void {
    this.viewModel.resetRestoreState();
    this.hideSnapshot();
  }

  private registerRestoreStateObserver(): void {
    this.viewModel.releaseGridCallback(this.restoreStateListener);
    this.viewModel.getRestoreState(undefined, this.restoreStateListener);
  }

  private handleRestoreStateChanged(restoreState: RestoreFpStateType): void {
    switch (restoreState) {
      case RestoreFpStateType.INIT_STATE:
      case RestoreFpStateType.IDLE_STATE:
      case RestoreFpStateType.FILL_POSITION_STATE:
        this.hideSnapshot();
        break;
      case RestoreFpStateType.ANIMATION_PREPARE_STATE:
        this.prepareRestoreAnimation();
        break;
      case RestoreFpStateType.ANIMATION_READY_STATE:
        this.doRestoreAnimation();
        break;
      default:
        break;
    }
  }

  private prepareRestoreAnimation(): void {
    this.clearSnapshotOffsetObservers();
    this.viewModel.getScrollOffset(undefined, this.scrollOffsetListener);
    this.viewModel.getIrregularHeight(undefined, this.irregularHeightListener);

    const snapshotOffset = this.viewModel.getSnapshotOffset();
    this.snapshotOffsetY = snapshotOffset;
    this.snapshotOpacity = AnimationOpacity.DEFAULT;

    if (!this.captureSnapshot(snapshotOffset)) {
      this.viewModel.notifyAnimationComplete();
      return;
    }

    this.isVisible = this.snapshotImage !== undefined;
    this.viewModel.notifyAnimationPrepareComplete();
  }

  private captureSnapshot(snapshotOffset: number): boolean {
    const gridAreaSize = this.viewModel.getGridAreaSize();
    if (gridAreaSize.width <= 0 || gridAreaSize.height <= 0) {
      return false;
    }

    if (snapshotOffset < 0 || snapshotOffset > gridAreaSize.height / 2) {
      return false;
    }

    try {
      const nextSnapshot = componentSnapshot.getSync(this.resolveGridViewId(), {
        waitUntilRenderFinished: true,
        region: {
          left: 0,
          right: vp2px(gridAreaSize.width),
          top: vp2px(snapshotOffset),
          bottom: vp2px(gridAreaSize.height),
        },
      });
      if (this.snapshotImage && this.snapshotImage !== nextSnapshot) {
        this.releaseSnapshotImage(this.snapshotImage);
      }
      this.snapshotImage = nextSnapshot as PixelMap;
      return this.snapshotImage !== undefined;
    } catch (_error) {
      return false;
    }
  }

  private resolveGridViewId(): string {
    const activeForm = this.viewModel.getActiveForm();
    if (activeForm === FormIndex.YEAR) {
      return PhotoGridViewId.YEAR_GRID;
    }
    if (activeForm === FormIndex.MONTH) {
      return PhotoGridViewId.MONTH_GRID;
    }
    if (activeForm === FormIndex.GROUP_DAY) {
      return PhotoGridViewId.GROUP_DAY_GRID;
    }
    return PhotoGridViewId.DAY_GRID;
  }

  private doRestoreAnimation(): void {
    this.snapshotOpacity = AnimationOpacity.DEFAULT;
    animateTo({
      duration: AnimationDuration.RESTORE_FILL_POSITION,
      curve: AnimationCurve.SHARP_CURVE,
      onFinish: (): void => {
        this.viewModel.notifyAnimationComplete();
      },
    }, (): void => {
      this.snapshotOpacity = AnimationOpacity.TRANSPARENT;
    });
  }

  private updateSnapshotOffset(): void {
    if (!this.snapshotImage) {
      return;
    }
    this.snapshotOffsetY = this.viewModel.getSnapshotOffset();
  }

  private clearSnapshotOffsetObservers(): void {
    this.viewModel.releaseGridCallback(this.scrollOffsetListener);
    this.viewModel.releaseGridCallback(this.irregularHeightListener);
  }

  private releaseSnapshotImage(snapshotImage: PixelMap): void {
    try {
      snapshotImage.release();
    } catch (_error) {}
  }
}
