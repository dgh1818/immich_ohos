import * as Shared from '../HybridPhotoGridShared';
import { HybridPhotoTimelineBuilder } from '../HybridPhotoTimeline';

type HybridGridItem = Shared.HybridGridItem;
type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridTimelineItem = Shared.HybridTimelineItem;

class HybridGridAssetEntry {
  asset: HybridPhotoAsset = {} as HybridPhotoAsset;
  sectionKey: string = '';
  sourceIndex: number = 0;
}

class HybridPhotoSectionRecord implements Shared.HybridPhotoSection {
  key: string = '';
  title: string = '';
  rows: Array<Array<HybridPhotoAsset>> = [];
}

class HybridGridItemRecord implements Shared.HybridGridItem {
  id: string = '';
  kind: 'photo' | 'header' | 'spacer' | 'tail' | 'placeholder' = 'photo';
  asset?: HybridPhotoAsset = undefined;
  headerText?: string = undefined;
  headerCount?: number = undefined;
  spacerHeight?: number = undefined;
  sectionKey: string = '';
  sourceIndex?: number = undefined;
}

export class HybridFloatingSectionInfo {
  title: string = '';
  count: number = 0;

  constructor(title: string, count: number) {
    this.title = title;
    this.count = count;
  }
}

export class HybridPhotoGridDataAdapter {
  private readonly timelineBuilder: HybridPhotoTimelineBuilder = new HybridPhotoTimelineBuilder();

  private buildStablePhotoItemId(asset: HybridPhotoAsset, sectionKey: string): string {
    return `photo_${asset.id}_${sectionKey}`;
  }

  public cloneSections(sections: Array<HybridPhotoSection>): Array<HybridPhotoSection> {
    return sections.map((section: HybridPhotoSection) => {
      const record = new HybridPhotoSectionRecord();
      record.key = section.key;
      record.title = section.title;
      record.rows = section.rows.map((row: Array<HybridPhotoAsset>) => row.slice());
      return record;
    });
  }

  public buildTimelineItemsForColumns(
    sections: Array<HybridPhotoSection>,
    columns: number,
  ): Array<HybridTimelineItem> {
    this.timelineBuilder.resetLayoutIds();
    const reflowedSections = this.timelineBuilder.reflowSections(sections, columns);
    return this.timelineBuilder.buildTimelineItems(reflowedSections, columns);
  }

  public buildGridItemsForColumns(
    sections: Array<HybridPhotoSection>,
    columns: number,
    topSpacerHeight: number,
    hasMore: boolean,
    fillPosition: number = 0,
    includeTail: boolean = false,
  ): Array<HybridGridItem> {
    void topSpacerHeight;
    const items: Array<HybridGridItem> = [];
    const safeFillPosition = Math.max(0, fillPosition);
    for (let index = 0; index < safeFillPosition; index += 1) {
      const placeholderItem = new HybridGridItemRecord();
      placeholderItem.id = `placeholder_${columns}_${safeFillPosition}_${index}`;
      placeholderItem.kind = 'placeholder';
      items.push(placeholderItem);
    }

    this.flattenSectionsToGridEntries(sections).forEach((entry: HybridGridAssetEntry) => {
      const photoItem = new HybridGridItemRecord();
      photoItem.id = this.buildStablePhotoItemId(entry.asset, entry.sectionKey);
      photoItem.kind = 'photo';
      photoItem.asset = entry.asset;
      photoItem.sectionKey = entry.sectionKey;
      photoItem.sourceIndex = entry.sourceIndex;
      items.push(photoItem);
    });

    if (includeTail && hasMore) {
      const tailCount = Math.max(1, columns);
      for (let index = 0; index < tailCount; index += 1) {
        const tailItem = new HybridGridItemRecord();
        tailItem.id = `tail_${columns}_${index}`;
        tailItem.kind = 'tail';
        items.push(tailItem);
      }
    }

    return items;
  }

  public flattenAssets(sections: Array<HybridPhotoSection>): Array<HybridPhotoAsset> {
    const assets: Array<HybridPhotoAsset> = [];
    this.flattenSectionsToGridEntries(sections).forEach((entry: HybridGridAssetEntry) => {
      assets.push(entry.asset);
    });
    return assets;
  }

  private flattenSectionsToGridEntries(sections: Array<HybridPhotoSection>): Array<HybridGridAssetEntry> {
    const entries: Array<HybridGridAssetEntry> = [];
    let sourceIndex = 0;
    sections.forEach((section: HybridPhotoSection) => {
      section.rows.forEach((row: Array<HybridPhotoAsset>) => {
        row.forEach((asset: HybridPhotoAsset) => {
          const entry = new HybridGridAssetEntry();
          entry.asset = asset;
          entry.sectionKey = section.key;
          entry.sourceIndex = sourceIndex;
          entries.push(entry);
          sourceIndex += 1;
        });
      });
    });
    return entries;
  }

  public buildFloatingSectionInfo(
    items: Array<HybridTimelineItem>,
    startIndex: number,
  ): HybridFloatingSectionInfo {
    if (items.length <= 0) {
      return new HybridFloatingSectionInfo('', 0);
    }

    const safeIndex = Math.max(0, Math.min(startIndex, items.length - 1));
    const item = items[safeIndex];
    return new HybridFloatingSectionInfo(item.sectionTitle, item.sectionCount);
  }

  public resolveAssetIndex(
    sections: Array<HybridPhotoSection>,
    targetAsset: HybridPhotoAsset,
  ): number {
    let index = 0;

    for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex += 1) {
      const section = sections[sectionIndex];
      for (let rowIndex = 0; rowIndex < section.rows.length; rowIndex += 1) {
        const row = section.rows[rowIndex];
        for (let assetIndex = 0; assetIndex < row.length; assetIndex += 1) {
          const asset = row[assetIndex];
          if (asset.id === targetAsset.id) {
            return index;
          }
          index += 1;
        }
      }
    }

    return -1;
  }
}
