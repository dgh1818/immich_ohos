import { HybridFlutterBridge } from '../../../bridge/HybridFlutterBridge';
import * as Shared from '../HybridPhotoGridShared';
import { HybridPhotoGridDataAdapter } from './HybridPhotoGridDataAdapter';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridPhotoSection = Shared.HybridPhotoSection;

export class HybridPhotoGridActionAdapter {
  private readonly dataAdapter: HybridPhotoGridDataAdapter = new HybridPhotoGridDataAdapter();

  public async openAssetViewer(
    sections: Array<HybridPhotoSection>,
    asset: HybridPhotoAsset,
  ): Promise<void> {
    const index = this.dataAdapter.resolveAssetIndex(sections, asset);
    if (index < 0) {
      console.error(`[HybridPhotoGridActionAdapter] asset index not found for ${asset.id}`);
      return;
    }

    try {
      await HybridFlutterBridge.openTimelineAssetViewer(index);
    } catch (error) {
      console.error(`[HybridPhotoGridActionAdapter] open asset viewer failed: ${error}`);
    }
  }
}
