import * as Shared from '../PhotoGridShared';
import { TimelineLayoutBuilder } from '../TimelineLayoutBuilder';

type GridItem = Shared.GridItem;
type GroupInfo = Shared.GroupInfo;
type PhotoAsset = Shared.PhotoAsset;
type PhotoSection = Shared.PhotoSection;
type TimelineItem = Shared.TimelineItem;

class PhotoSectionRecord implements Shared.PhotoSection {
  key: string = '';
  title: string = '';
  rows: Array<Array<PhotoAsset>> = [];
  assetCount?: number = undefined;
  sourceStartOffset?: number = undefined;
  sourceEndOffsetExclusive?: number = undefined;
  sourceFlatStartIndex?: number = undefined;
  sourceFlatEndIndexExclusive?: number = undefined;
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

  private buildStablePhotoItemId(asset: PhotoAsset, sectionKey: string): string {
    return `photo_${asset.id}_${sectionKey}`;
  }

  private buildStableGroupHeaderId(section: PhotoSection, group: GroupInfo | undefined): string {
    const stableOffset = group?.offset ?? -1;
    return `group_header_${section.key}_${stableOffset}`;
  }

  public cloneSections(sections: Array<PhotoSection>): Array<PhotoSection> {
    return sections.map((section: PhotoSection) => {
      const record = new PhotoSectionRecord();
      record.key = section.key;
      record.title = section.title;
      record.rows = section.rows.map((row: Array<PhotoAsset>) => row.slice());
      record.assetCount = typeof section.assetCount === 'number'
        ? section.assetCount
        : this.countSectionAssets(section);
      record.sourceStartOffset = typeof section.sourceStartOffset === 'number'
        ? section.sourceStartOffset
        : undefined;
      record.sourceEndOffsetExclusive = typeof section.sourceEndOffsetExclusive === 'number'
        ? section.sourceEndOffsetExclusive
        : undefined;
      record.sourceFlatStartIndex = typeof section.sourceFlatStartIndex === 'number'
        ? section.sourceFlatStartIndex
        : undefined;
      record.sourceFlatEndIndexExclusive = typeof section.sourceFlatEndIndexExclusive === 'number'
        ? section.sourceFlatEndIndexExclusive
        : undefined;
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
    sourceStartOffset: number = 0,
    sourceFlatAssets?: Array<PhotoAsset>,
  ): Array<GridItem> {
    const reflowedSections = this.timelineBuilder.reflowSections(sections, columns);
    return this.buildGridItemsFromSections(reflowedSections, sourceStartOffset, sourceFlatAssets);
  }

  public buildGridItemsFromSections(
    sections: Array<PhotoSection>,
    sourceStartOffset: number = 0,
    sourceFlatAssets?: Array<PhotoAsset>,
  ): Array<GridItem> {
    const items: Array<GridItem> = [];
    let sourceIndex = Math.max(0, sourceStartOffset);
    const flatAssets = sourceFlatAssets;
    sections.forEach((section: PhotoSection) => {
      const sectionSourceStartOffset = this.resolveSectionSourceStartOffset(section, sourceIndex);
      let sectionLocalIndex = 0;
      const sectionFlatStartIndex = this.resolveSectionFlatStartIndex(section);
      const sectionFlatEndIndexExclusive = this.resolveSectionFlatEndIndexExclusive(section);
      if (flatAssets !== undefined &&
        this.canUseSectionFlatRange(sectionFlatStartIndex, sectionFlatEndIndexExclusive, flatAssets)) {
        for (let flatIndex = sectionFlatStartIndex; flatIndex < sectionFlatEndIndexExclusive; flatIndex += 1) {
          const asset = flatAssets[flatIndex];
          const photoItem = new GridItemRecord();
          photoItem.id = this.buildStablePhotoItemId(asset, section.key);
          photoItem.kind = 'photo';
          photoItem.asset = asset;
          photoItem.sectionKey = section.key;
          photoItem.sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
          items.push(photoItem);
          sectionLocalIndex += 1;
        }
        sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
        return;
      }

      section.rows.forEach((row: Array<PhotoAsset>) => {
        row.forEach((asset: PhotoAsset) => {
          const photoItem = new GridItemRecord();
          photoItem.id = this.buildStablePhotoItemId(asset, section.key);
          photoItem.kind = 'photo';
          photoItem.asset = asset;
          photoItem.sectionKey = section.key;
          photoItem.sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
          items.push(photoItem);
          sectionLocalIndex += 1;
        });
      });
      sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
    });

    return items;
  }

  public buildGroupGridItems(
    sections: Array<PhotoSection>,
    groups: Array<GroupInfo>,
    sourceStartOffset: number = 0,
    sourceFlatAssets?: Array<PhotoAsset>,
  ): Array<GridItem> {
    const items: Array<GridItem> = [];

    let sourceIndex = Math.max(0, sourceStartOffset);
    const flatAssets = sourceFlatAssets;
    sections.forEach((section: PhotoSection, sectionIndex: number) => {
      const group = groups[sectionIndex];
      const sectionFlatStartIndex = this.resolveSectionFlatStartIndex(section);
      const sectionFlatEndIndexExclusive = this.resolveSectionFlatEndIndexExclusive(section);
      const sectionAssetCount = this.canUseSectionFlatRange(
        sectionFlatStartIndex,
        sectionFlatEndIndexExclusive,
        flatAssets,
      )
        ? sectionFlatEndIndexExclusive - sectionFlatStartIndex
        : this.countSectionAssets(section);
      if (sectionAssetCount <= 0) {
        return;
      }

      const headerItem = new GridItemRecord();
      headerItem.id = this.buildStableGroupHeaderId(section, group);
      headerItem.kind = 'groupHeader';
      headerItem.headerText = section.title;
      headerItem.headerCount = group?.count ?? sectionAssetCount;
      headerItem.sectionKey = section.key;
      items.push(headerItem);

      const sectionSourceStartOffset = this.resolveSectionSourceStartOffset(
        section,
        group?.offset ?? sourceIndex,
      );
      let sectionLocalIndex = 0;
      if (flatAssets !== undefined &&
        this.canUseSectionFlatRange(sectionFlatStartIndex, sectionFlatEndIndexExclusive, flatAssets)) {
        for (let flatIndex = sectionFlatStartIndex; flatIndex < sectionFlatEndIndexExclusive; flatIndex += 1) {
          const asset = flatAssets[flatIndex];
          const photoItem = new GridItemRecord();
          photoItem.id = this.buildStablePhotoItemId(asset, section.key);
          photoItem.kind = 'photo';
          photoItem.asset = asset;
          photoItem.sectionKey = section.key;
          photoItem.sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
          items.push(photoItem);
          sectionLocalIndex += 1;
        }
        sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
        return;
      }

      section.rows.forEach((row: Array<PhotoAsset>) => {
        row.forEach((asset: PhotoAsset) => {
          const photoItem = new GridItemRecord();
          photoItem.id = this.buildStablePhotoItemId(asset, section.key);
          photoItem.kind = 'photo';
          photoItem.asset = asset;
          photoItem.sectionKey = section.key;
          photoItem.sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
          items.push(photoItem);
          sectionLocalIndex += 1;
        });
      });
      sourceIndex = sectionSourceStartOffset + sectionLocalIndex;
    });

    return items;
  }

  public flattenAssets(sections: Array<PhotoSection>): Array<PhotoAsset> {
    const assets: Array<PhotoAsset> = [];
    sections.forEach((section: PhotoSection) => {
      section.rows.forEach((row: Array<PhotoAsset>) => {
        row.forEach((asset: PhotoAsset) => assets.push(asset));
      });
    });
    return assets;
  }

  public flattenSectionAssets(section: PhotoSection): Array<PhotoAsset> {
    const assets: Array<PhotoAsset> = [];
    section.rows.forEach((row: Array<PhotoAsset>) => {
      row.forEach((asset: PhotoAsset) => assets.push(asset));
    });
    return assets;
  }

  public countAssets(sections: Array<PhotoSection>): number {
    let count = 0;
    sections.forEach((section: PhotoSection) => {
      count += this.countSectionAssets(section);
    });
    return count;
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

  public countSectionAssets(section: PhotoSection): number {
    if (typeof section.assetCount === 'number' && section.assetCount >= 0) {
      return section.assetCount;
    }

    const sectionFlatStartIndex = this.resolveSectionFlatStartIndex(section);
    const sectionFlatEndIndexExclusive = this.resolveSectionFlatEndIndexExclusive(section);
    if (sectionFlatStartIndex >= 0 && sectionFlatEndIndexExclusive >= sectionFlatStartIndex) {
      const assetCount = sectionFlatEndIndexExclusive - sectionFlatStartIndex;
      section.assetCount = assetCount;
      return assetCount;
    }

    let count = 0;
    for (let rowIndex = 0; rowIndex < section.rows.length; rowIndex += 1) {
      count += section.rows[rowIndex].length;
    }
    section.assetCount = count;
    return count;
  }

  private resolveSectionSourceStartOffset(section: PhotoSection, fallbackOffset: number): number {
    return typeof section.sourceStartOffset === 'number'
      ? Math.max(0, section.sourceStartOffset)
      : Math.max(0, fallbackOffset);
  }

  private resolveSectionFlatStartIndex(section: PhotoSection): number {
    return typeof section.sourceFlatStartIndex === 'number'
      ? section.sourceFlatStartIndex
      : -1;
  }

  private resolveSectionFlatEndIndexExclusive(section: PhotoSection): number {
    return typeof section.sourceFlatEndIndexExclusive === 'number'
      ? section.sourceFlatEndIndexExclusive
      : -1;
  }

  private canUseSectionFlatRange(
    flatStartIndex: number,
    flatEndIndexExclusive: number,
    sourceFlatAssets?: Array<PhotoAsset>,
  ): boolean {
    return sourceFlatAssets !== undefined &&
      flatStartIndex >= 0 &&
      flatEndIndexExclusive > flatStartIndex &&
      flatEndIndexExclusive <= sourceFlatAssets.length;
  }
}
