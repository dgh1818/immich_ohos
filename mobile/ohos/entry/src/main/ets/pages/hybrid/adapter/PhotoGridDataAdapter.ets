import * as Shared from '../PhotoGridShared';
import { TimelineLayoutBuilder } from '../TimelineLayoutBuilder';

type GridItem = Shared.GridItem;
type GroupInfo = Shared.GroupInfo;
type PhotoAsset = Shared.PhotoAsset;
type PhotoSection = Shared.PhotoSection;
type TimelineItem = Shared.TimelineItem;

class GridAssetEntry {
  asset: PhotoAsset = {} as PhotoAsset;
  sectionKey: string = '';
  sourceIndex: number = 0;
}

class PhotoSectionRecord implements Shared.PhotoSection {
  key: string = '';
  title: string = '';
  rows: Array<Array<PhotoAsset>> = [];
}

class GridItemRecord implements Shared.GridItem {
  id: string = '';
  kind: 'photo' | 'header' | 'spacer' | 'tail' | 'placeholder' | 'groupHeader' = 'photo';
  asset?: PhotoAsset = undefined;
  headerText?: string = undefined;
  headerCount?: number = undefined;
  spacerHeight?: number = undefined;
  sectionKey: string = '';
  sourceIndex?: number = undefined;
}

export class FloatingSectionInfo {
  title: string = '';
  count: number = 0;

  constructor(title: string, count: number) {
    this.title = title;
    this.count = count;
  }
}

export class PhotoGridDataAdapter {
  private readonly timelineBuilder: TimelineLayoutBuilder = new TimelineLayoutBuilder();

  public cloneSections(sections: Array<PhotoSection>): Array<PhotoSection> {
    return sections.map((section: PhotoSection) => {
      const record = new PhotoSectionRecord();
      record.key = section.key;
      record.title = section.title;
      record.rows = section.rows.map((row: Array<PhotoAsset>) => row.slice());
      return record;
    });
  }

  public buildTimelineItemsForColumns(
    sections: Array<PhotoSection>,
    columns: number,
  ): Array<TimelineItem> {
    this.timelineBuilder.resetLayoutIds();
    const reflowedSections = this.timelineBuilder.reflowSections(sections, columns);
    return this.timelineBuilder.buildTimelineItems(reflowedSections, columns);
  }

  public buildTimelineItemsForSections(
    sections: Array<PhotoSection>,
    columns: number,
  ): Array<TimelineItem> {
    this.timelineBuilder.resetLayoutIds();
    return this.timelineBuilder.buildTimelineItems(sections, columns);
  }

  public buildGridItemsForColumns(
    sections: Array<PhotoSection>,
    columns: number,
    _topSpacerHeight: number,
    hasMore: boolean,
    fillPosition: number = 0,
    includeTail: boolean = false,
  ): Array<GridItem> {
    const reflowedSections = this.timelineBuilder.reflowSections(sections, columns);
    return this.buildGridItemsFromSections(
      reflowedSections,
      columns,
      hasMore,
      fillPosition,
      includeTail,
    );
  }

  public buildGridItemsFromSections(
    sections: Array<PhotoSection>,
    columns: number,
    hasMore: boolean,
    fillPosition: number = 0,
    includeTail: boolean = false,
  ): Array<GridItem> {
    const items: Array<GridItem> = [];
    const safeFillPosition = Math.max(0, fillPosition);
    for (let index = 0; index < safeFillPosition; index += 1) {
      const placeholderItem = new GridItemRecord();
      placeholderItem.id = `placeholder_${columns}_${safeFillPosition}_${index}`;
      placeholderItem.kind = 'placeholder';
      items.push(placeholderItem);
    }

    this.flattenSectionsToGridEntries(sections).forEach((entry: GridAssetEntry) => {
      const photoItem = new GridItemRecord();
      photoItem.id = `photo_${entry.sourceIndex}_${entry.asset.id}`;
      photoItem.kind = 'photo';
      photoItem.asset = entry.asset;
      photoItem.sectionKey = entry.sectionKey;
      photoItem.sourceIndex = entry.sourceIndex;
      items.push(photoItem);
    });

    if (includeTail && hasMore) {
      const tailCount = Math.max(1, columns);
      for (let index = 0; index < tailCount; index += 1) {
        const tailItem = new GridItemRecord();
        tailItem.id = `tail_${columns}_${index}`;
        tailItem.kind = 'tail';
        items.push(tailItem);
      }
    }

    return items;
  }

  public buildGroupGridItems(
    sections: Array<PhotoSection>,
    groups: Array<GroupInfo>,
    columns: number,
    hasMore: boolean,
    fillPosition: number = 0,
    includeTail: boolean = false,
  ): Array<GridItem> {
    const items: Array<GridItem> = [];
    const safeFillPosition = Math.max(0, fillPosition);
    for (let index = 0; index < safeFillPosition; index += 1) {
      const placeholderItem = new GridItemRecord();
      placeholderItem.id = `placeholder_${columns}_${safeFillPosition}_${index}`;
      placeholderItem.kind = 'placeholder';
      items.push(placeholderItem);
    }

    let sourceIndex = 0;
    sections.forEach((section: PhotoSection, sectionIndex: number) => {
      const group = groups[sectionIndex];
      const sectionAssets = this.flattenAssets([section]);
      if (sectionAssets.length <= 0) {
        return;
      }

      const headerItem = new GridItemRecord();
      headerItem.id = `group_header_${section.key}_${sectionIndex}`;
      headerItem.kind = 'groupHeader';
      headerItem.headerText = section.title;
      headerItem.headerCount = group?.count ?? sectionAssets.length;
      headerItem.sectionKey = section.key;
      items.push(headerItem);

      sectionAssets.forEach((asset: PhotoAsset) => {
        const photoItem = new GridItemRecord();
        photoItem.id = `photo_${sourceIndex}_${asset.id}`;
        photoItem.kind = 'photo';
        photoItem.asset = asset;
        photoItem.sectionKey = section.key;
        photoItem.sourceIndex = group?.offset !== undefined
          ? group.offset + Math.max(0, sourceIndex - this.resolveSectionStartIndex(sections, sectionIndex))
          : sourceIndex;
        items.push(photoItem);
        sourceIndex += 1;
      });
    });

    if (includeTail && hasMore) {
      const tailCount = Math.max(1, columns);
      for (let index = 0; index < tailCount; index += 1) {
        const tailItem = new GridItemRecord();
        tailItem.id = `tail_${columns}_${index}`;
        tailItem.kind = 'tail';
        items.push(tailItem);
      }
    }

    return items;
  }

  public flattenAssets(sections: Array<PhotoSection>): Array<PhotoAsset> {
    const assets: Array<PhotoAsset> = [];
    this.flattenSectionsToGridEntries(sections).forEach((entry: GridAssetEntry) => {
      assets.push(entry.asset);
    });
    return assets;
  }

  public buildFloatingSectionInfo(
    items: Array<TimelineItem>,
    startIndex: number,
  ): FloatingSectionInfo {
    if (items.length <= 0) {
      return new FloatingSectionInfo('', 0);
    }

    const safeIndex = Math.max(0, Math.min(startIndex, items.length - 1));
    const item = items[safeIndex];
    return new FloatingSectionInfo(item.sectionTitle, item.sectionCount);
  }

  public resolveAssetIndex(
    sections: Array<PhotoSection>,
    targetAsset: PhotoAsset,
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

  private flattenSectionsToGridEntries(sections: Array<PhotoSection>): Array<GridAssetEntry> {
    const entries: Array<GridAssetEntry> = [];
    let sourceIndex = 0;
    sections.forEach((section: PhotoSection) => {
      section.rows.forEach((row: Array<PhotoAsset>) => {
        row.forEach((asset: PhotoAsset) => {
          const entry = new GridAssetEntry();
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

  private resolveSectionStartIndex(sections: Array<PhotoSection>, sectionIndex: number): number {
    let startIndex = 0;
    for (let index = 0; index < sectionIndex; index += 1) {
      startIndex += this.flattenAssets([sections[index]]).length;
    }
    return startIndex;
  }
}
