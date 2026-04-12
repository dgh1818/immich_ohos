import { HybridFlutterBridge } from '../../../bridge/HybridFlutterBridge';
import * as Shared from '../PhotoGridShared';
import { PhotoGridDataAdapter } from './PhotoGridDataAdapter';

type PhotoAsset = Shared.PhotoAsset;
type PhotoSection = Shared.PhotoSection;

export class PhotoGridActionAdapter {
  private readonly dataAdapter: PhotoGridDataAdapter = new PhotoGridDataAdapter();

  public async openAssetViewer(
    sections: Array<PhotoSection>,
    asset: PhotoAsset,
  ): Promise<void> {
    const index = this.dataAdapter.resolveAssetIndex(sections, asset);
    if (index < 0) {
      console.error(`[PhotoGridActionAdapter] asset index not found for ${asset.id}`);
      return;
    }

    try {
      await HybridFlutterBridge.openTimelineAssetViewerAt(index);
    } catch (error) {
      console.error(`[PhotoGridActionAdapter] open asset viewer failed: ${error}`);
    }
  }
}
