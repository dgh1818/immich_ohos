import { componentSnapshot } from '@kit.ArkUI';
import { GridStateProxy } from '../statemanager/GridStateProxy';
import { FormIndex } from '../statemanager/constants/GridDefine';
import { RestoreFpStateType } from '../statemanager/GridRestoreFpFsm';
import { AnimationDuration, AnimationOpacity } from './animation/AnimationDefine';
import { PhotoGridViewId } from './PhotoGridVc';
import { GridSnapshotVm } from '../viewmodel/GridSnapshotVm';

@Observed
export class GridSnapshotVc {
  @Track public snapshotImage?: PixelMap;
  @Track public isVisible: boolean = false;
  @Track public snapshotOpacity: number = AnimationOpacity.DEFAULT;
  @Track public snapshotOffsetY: number = 0;

  private readonly viewModel: GridSnapshotVm = new GridSnapshotVm();
  private restoreAnimationTimeoutId?: number = undefined;

  public bindStateProxy(stateProxy: GridStateProxy): void {
    this.viewModel.bindStateProxy(stateProxy);
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
    this.clearRestoreAnimationTimeout();
    const currentSnapshot = this.snapshotImage;
    this.snapshotImage = undefined;
    this.isVisible = false;
    this.snapshotOpacity = AnimationOpacity.DEFAULT;
    this.snapshotOffsetY = 0;
    if (currentSnapshot) {
      this.releaseSnapshotImage(currentSnapshot);
    }
  }

  public notifyFillPositionChanged(hasFillPosition: boolean): void {
    this.viewModel.notifyFillPositionChanged(hasFillPosition);
  }

  public prepareRestoreAnimation(): void {
    const restoreState = this.viewModel.prepareRestoreAnimation();
    if (restoreState !== RestoreFpStateType.ANIMATION_PREPARE_STATE) {
      return;
    }

    const snapshotOffset = this.viewModel.getSnapshotOffset();
    this.snapshotOffsetY = snapshotOffset;
    this.snapshotOpacity = AnimationOpacity.DEFAULT;

    if (!this.captureSnapshot(snapshotOffset)) {
      this.onRestoreAnimationComplete();
      return;
    }

    this.isVisible = this.snapshotImage !== undefined;
    const nextState = this.viewModel.notifyAnimationPrepareComplete();
    if (nextState === RestoreFpStateType.ANIMATION_READY_STATE) {
      this.doRestoreAnimation();
    }
  }

  public cancelRestoreAnimation(): void {
    this.clearRestoreAnimationTimeout();
    this.viewModel.cancelRestoreAnimation();
    this.hideSnapshot();
  }

  public resetRestoreFpState(): void {
    this.clearRestoreAnimationTimeout();
    this.viewModel.resetRestoreState();
    this.hideSnapshot();
  }

  private captureSnapshot(snapshotOffset: number): boolean {
    const gridAreaSize = this.viewModel.getGridAreaSize();
    if (gridAreaSize.width <= 0 || gridAreaSize.height <= 0) {
      return false;
    }

    try {
      const nextSnapshot = componentSnapshot.getSync(this.resolveGridViewId(), {
        waitUntilRenderFinished: true,
        region: {
          left: 0,
          right: vp2px(gridAreaSize.width),
          top: vp2px(Math.max(0, snapshotOffset)),
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
    this.clearRestoreAnimationTimeout();
    this.snapshotOpacity = AnimationOpacity.DEFAULT;
    animateTo({
      duration: AnimationDuration.RESTORE_FILL_POSITION,
      curve: Curve.Linear,
    }, (): void => {
      this.snapshotOpacity = AnimationOpacity.TRANSPARENT;
    });
    this.restoreAnimationTimeoutId = setTimeout((): void => {
      this.onRestoreAnimationComplete();
    }, AnimationDuration.RESTORE_FILL_POSITION) as number;
  }

  private onRestoreAnimationComplete(): void {
    this.clearRestoreAnimationTimeout();
    this.viewModel.notifyAnimationComplete();
    this.hideSnapshot();
  }

  private clearRestoreAnimationTimeout(): void {
    if (this.restoreAnimationTimeoutId !== undefined) {
      clearTimeout(this.restoreAnimationTimeoutId);
      this.restoreAnimationTimeoutId = undefined;
    }
  }

  private releaseSnapshotImage(snapshotImage: PixelMap): void {
    try {
      snapshotImage.release();
    } catch (_error) {}
  }
}
