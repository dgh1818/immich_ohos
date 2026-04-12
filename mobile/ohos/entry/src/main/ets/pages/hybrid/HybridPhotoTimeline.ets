import * as Shared from "./HybridPhotoGridShared";
import { FormIndex, getFormIndexByColumns } from './statemanager/constants/GridDefine';

type HybridPhotoAsset = Shared.HybridPhotoAsset;
type HybridBucketInfo = Shared.HybridBucketInfo;
type HybridGroupInfo = Shared.HybridGroupInfo;
type HybridPhotoPageResult = Shared.HybridPhotoPageResult;
type HybridPhotoSection = Shared.HybridPhotoSection;
type HybridSectionMergeResult = Shared.HybridSectionMergeResult;
type HybridTimelineAssetEntry = Shared.HybridTimelineAssetEntry;
type HybridTimelineItem = Shared.HybridTimelineItem;
type HybridTimelineTailUpdate = Shared.HybridTimelineTailUpdate;

class HybridSectionBucket {
  key: string = '';
  title: string = '';
  assets: Array<HybridPhotoAsset> = [];
}

class HybridSectionDescriptor {
  key: string = '';
  title: string = '';
}

class HybridDateParts {
  year: number = 0;
  month: number = 0;
  day: number = 0;
}

export class HybridPhotoTimelineBuilder {
  private nextTimelineLayoutId: number = 0;

  resetLayoutIds(): void {
    this.nextTimelineLayoutId = 0;
  }

  parsePageResult(raw: string): HybridPhotoPageResult {
    if (!raw) {
      return {
        ready: false,
        offset: 0,
        hasMore: false,
        nextOffset: 0,
        windowStartOffset: 0,
        windowEndOffset: 0,
        sections: [],
        groupDayGroups: [],
        yearBuckets: [],
        monthBuckets: [],
        reason: "Empty response",
      };
    }

    const parsed = JSON.parse(raw) as Record<string, Object>;
    const sectionsRaw = Array.isArray(parsed["sections"])
      ? (parsed["sections"] as Array<Record<string, Object>>)
      : [];
    const yearBucketsRaw = Array.isArray(parsed["yearBuckets"])
      ? (parsed["yearBuckets"] as Array<Record<string, Object>>)
      : [];
    const monthBucketsRaw = Array.isArray(parsed["monthBuckets"])
      ? (parsed["monthBuckets"] as Array<Record<string, Object>>)
      : [];
    const groupDayGroupsRaw = Array.isArray(parsed["groupDayGroups"])
      ? (parsed["groupDayGroups"] as Array<Record<string, Object>>)
      : [];

    return {
      ready: parsed["ready"] === true,
      offset: Number(parsed["offset"] ?? 0),
      hasMore: parsed["hasMore"] === true,
      nextOffset: Number(parsed["nextOffset"] ?? 0),
      windowStartOffset: Number(parsed["windowStartOffset"] ?? parsed["offset"] ?? 0),
      windowEndOffset: Number(parsed["windowEndOffset"] ?? parsed["nextOffset"] ?? 0),
      reason: typeof parsed["reason"] === "string" ? parsed["reason"] : undefined,
      sections: sectionsRaw.map((section) => this.parseSection(section)),
      groupDayGroups: groupDayGroupsRaw.map((group) => this.parseGroupInfo(group)),
      yearBuckets: yearBucketsRaw.map((bucket) => this.parseBucketInfo(bucket)),
      monthBuckets: monthBucketsRaw.map((bucket) => this.parseBucketInfo(bucket)),
    };
  }

  mergeSections(
    current: Array<HybridPhotoSection>,
    incoming: Array<HybridPhotoSection>,
    columns: number = Shared.HYBRID_GRID_COLUMNS,
  ): HybridSectionMergeResult {
    const merged: Array<HybridPhotoSection> = current.map((section: HybridPhotoSection) =>
      this.createSection(
        section.key,
        section.title,
        section.rows.map((row) => row.slice()),
      ),
    );
    const appendedEntries: Array<HybridTimelineAssetEntry> = [];
    const seenAssetKeys: Set<string> = new Set();
    merged.forEach((section: HybridPhotoSection) => {
      this.flattenRows(section.rows).forEach((asset: HybridPhotoAsset) => {
        seenAssetKeys.add(this.assetStableKey(asset));
      });
    });

    incoming.forEach((section: HybridPhotoSection) => {
      const incomingAssets = this.flattenRows(section.rows).filter((asset: HybridPhotoAsset) => {
        const assetKey = this.assetStableKey(asset);
        if (seenAssetKeys.has(assetKey)) {
          return false;
        }
        seenAssetKeys.add(assetKey);
        return true;
      });
      if (incomingAssets.length === 0) {
        return;
      }
      const last = merged.length > 0 ? merged[merged.length - 1] : undefined;

      if (last && this.isSameVisualSection(last, section)) {
        const combinedAssets = this.flattenRows(last.rows);
        const combinedCountBeforeAppend = combinedAssets.length;
        incomingAssets.forEach((asset: HybridPhotoAsset) => combinedAssets.push(asset));
        last.rows = this.chunkAssets(combinedAssets, columns);
        incomingAssets.forEach((asset: HybridPhotoAsset, assetIndex: number) => {
          appendedEntries.push({
            asset: asset,
            sectionKey: last.key,
            sectionTitle: last.title,
            sectionCount: combinedAssets.length,
            isSectionLead: combinedCountBeforeAppend === 0 && assetIndex === 0,
          });
        });
        return;
      }

      const newSection = this.createSection(
        section.key,
        section.title,
        this.chunkAssets(incomingAssets, columns),
      );
      merged.push(newSection);
      incomingAssets.forEach((asset: HybridPhotoAsset, assetIndex: number) => {
        appendedEntries.push({
          asset: asset,
          sectionKey: newSection.key,
          sectionTitle: newSection.title,
          sectionCount: incomingAssets.length,
          isSectionLead: assetIndex === 0,
        });
      });
    });

    return {
      sections: merged,
      appendedEntries: appendedEntries,
    };
  }

  buildTimelineItems(
    sections: Array<HybridPhotoSection>,
    columns: number = Shared.HYBRID_GRID_COLUMNS,
  ): Array<HybridTimelineItem> {
    const items: Array<HybridTimelineItem> = [];

    const entries: Array<HybridTimelineAssetEntry> = [];
    sections.forEach((section: HybridPhotoSection) => {
      const sectionAssets = this.flattenRows(section.rows);
      sectionAssets.forEach((asset: HybridPhotoAsset, assetIndex: number) => {
        entries.push({
          asset: asset,
          sectionKey: section.key,
          sectionTitle: section.title,
          sectionCount: sectionAssets.length,
          isSectionLead: assetIndex === 0,
        });
      });
    });

    for (let index = 0; index < entries.length; index += columns) {
      const rowEntries = entries.slice(index, index + columns);
      if (rowEntries.length <= 0) {
        continue;
      }
      items.push(this.createTimelineRowItem(rowEntries));
    }

    return items;
  }

  buildAppendTail(
    previousLastItem: HybridTimelineItem,
    previousItemCount: number,
    appendedEntries: Array<HybridTimelineAssetEntry>,
    columns: number = Shared.HYBRID_GRID_COLUMNS,
  ): HybridTimelineTailUpdate {
    const tailItems: Array<HybridTimelineItem> = [];
    const remainingEntries = appendedEntries.slice();
    let startIndex = previousItemCount;

    if (previousItemCount > 0 && previousLastItem.count < columns && remainingEntries.length > 0) {
      const missingCount = columns - previousLastItem.count;
      const fillEntries: Array<HybridTimelineAssetEntry> = [];

      while (fillEntries.length < missingCount && remainingEntries.length > 0) {
        const nextEntry = remainingEntries.shift();
        if (nextEntry) {
          fillEntries.push(nextEntry);
        }
      }

      if (fillEntries.length > 0) {
        startIndex = previousItemCount - 1;
        tailItems.push({
          layoutId: previousLastItem.layoutId,
          key: previousLastItem.key,
          kind: previousLastItem.kind,
          count: previousLastItem.assets.length + fillEntries.length,
          sectionKey: previousLastItem.sectionKey,
          sectionTitle: previousLastItem.sectionTitle,
          sectionCount: previousLastItem.sectionCount,
          assets: previousLastItem.assets.concat(
            fillEntries.map((entry: HybridTimelineAssetEntry) => entry.asset),
          ),
          isFirstInSection: previousLastItem.isFirstInSection,
        });
      }
    }

    while (remainingEntries.length > 0) {
      const rowEntries = remainingEntries.splice(0, columns);
      tailItems.push(this.createTimelineRowItem(rowEntries));
    }

    return {
      startIndex: startIndex,
      items: tailItems,
    };
  }

  collectPredownloadAssets(
    sections: Array<HybridPhotoSection>,
    includeAllAssets: boolean,
  ): Array<HybridPhotoAsset> {
    const selected: Array<HybridPhotoAsset> = [];
    const seenUrls: Set<string> = new Set();
    const pushAsset = (asset: HybridPhotoAsset): void => {
      const url = asset.thumbnailUrl;
      if (!url || seenUrls.has(url)) {
        return;
      }
      seenUrls.add(url);
      selected.push(asset);
    };

    if (includeAllAssets) {
      this.flattenSectionsToAssets(sections).forEach((asset: HybridPhotoAsset) => pushAsset(asset));
      return selected;
    }

    sections.forEach((section: HybridPhotoSection) => {
      const assets = this.flattenRows(section.rows);
      const warmupLimit =
        assets.length <= Shared.HYBRID_SMALL_SECTION_WARMUP_ASSET_LIMIT
          ? assets.length
          : Math.min(assets.length, Shared.HYBRID_LARGE_SECTION_WARMUP_ASSET_LIMIT);
      for (let index = 0; index < warmupLimit; index += 1) {
        pushAsset(assets[index]);
      }
    });

    return selected;
  }

  sectionAssetCount(section: HybridPhotoSection): number {
    let count = 0;
    section.rows.forEach((row: Array<HybridPhotoAsset>) => {
      count += row.length;
    });
    return count;
  }

  retainSectionsForMerge(sections: Array<HybridPhotoSection>): Array<HybridPhotoSection> {
    if (sections.length <= 1) {
      return sections;
    }
    return [sections[sections.length - 1]];
  }

  reflowSections(
    sections: Array<HybridPhotoSection>,
    columns: number = Shared.HYBRID_GRID_COLUMNS,
  ): Array<HybridPhotoSection> {
    const safeColumns = Math.max(1, columns);
    const form = getFormIndexByColumns(safeColumns);
    const buckets = this.bucketSectionsByForm(sections, form);
    return buckets.map((bucket: HybridSectionBucket) =>
      this.createSection(
        bucket.key,
        bucket.title,
        this.chunkAssets(bucket.assets, safeColumns),
      ),
    );
  }

  private parseSection(raw: Record<string, Object>): HybridPhotoSection {
    const rowsRaw = Array.isArray(raw["rows"])
      ? (raw["rows"] as Array<Array<Record<string, Object>>>)
      : [];
    return {
      key: typeof raw["key"] === "string" ? raw["key"] : "",
      title: typeof raw["title"] === "string" ? raw["title"] : "",
      rows: rowsRaw.map((row) => row.map((asset) => this.parseAsset(asset))),
    };
  }

  private parseBucketInfo(raw: Record<string, Object>): HybridBucketInfo {
    return {
      date: typeof raw["date"] === "string" ? raw["date"] : "",
      count: Number(raw["count"] ?? 0),
      offset: Number(raw["offset"] ?? 0),
    };
  }

  private parseGroupInfo(raw: Record<string, Object>): HybridGroupInfo {
    return {
      key: typeof raw["key"] === "string" ? raw["key"] : "",
      title: typeof raw["title"] === "string" ? raw["title"] : "",
      count: Number(raw["count"] ?? 0),
      offset: Number(raw["offset"] ?? 0),
    };
  }

  private parseAsset(raw: Record<string, Object>): HybridPhotoAsset {
    return {
      id: typeof raw["id"] === "string" ? raw["id"] : "",
      localId: typeof raw["localId"] === "string" ? raw["localId"] : undefined,
      remoteId: typeof raw["remoteId"] === "string" ? raw["remoteId"] : undefined,
      storage: typeof raw["storage"] === "string" ? raw["storage"] : undefined,
      thumbnailUrl: typeof raw["thumbnailUrl"] === "string" ? raw["thumbnailUrl"] : undefined,
      thumbHash: typeof raw["thumbHash"] === "string" ? raw["thumbHash"] : undefined,
      createdAt: typeof raw["createdAt"] === "string" ? raw["createdAt"] : undefined,
      isVideo: raw["isVideo"] === true,
      durationInSeconds: Number(raw["durationInSeconds"] ?? 0),
      width: typeof raw["width"] === "number" ? Number(raw["width"]) : undefined,
      height: typeof raw["height"] === "number" ? Number(raw["height"]) : undefined,
      isFavorite: raw["isFavorite"] === true,
    };
  }

  private bucketSectionsByForm(
    sections: Array<HybridPhotoSection>,
    form: FormIndex,
  ): Array<HybridSectionBucket> {
    const buckets: Array<HybridSectionBucket> = [];
    const bucketIndexByKey: Map<string, number> = new Map();

    sections.forEach((section: HybridPhotoSection) => {
      this.flattenRows(section.rows).forEach((asset: HybridPhotoAsset) => {
        const descriptor = this.resolveSectionDescriptor(asset, section, form);
        const existingIndex = bucketIndexByKey.get(descriptor.key);
        if (existingIndex !== undefined) {
          buckets[existingIndex].assets.push(asset);
          return;
        }

        const bucket = new HybridSectionBucket();
        bucket.key = descriptor.key;
        bucket.title = descriptor.title;
        bucket.assets.push(asset);
        bucketIndexByKey.set(bucket.key, buckets.length);
        buckets.push(bucket);
      });
    });

    return buckets;
  }

  private resolveSectionDescriptor(
    asset: HybridPhotoAsset,
    fallbackSection: HybridPhotoSection,
    form: FormIndex,
  ): HybridSectionDescriptor {
    const dateParts = this.resolveAssetDateParts(asset, fallbackSection);
    const descriptor = new HybridSectionDescriptor();
    if (!dateParts) {
      const fallbackKey = fallbackSection.key || fallbackSection.title || asset.id;
      descriptor.key = fallbackKey;
      descriptor.title = fallbackSection.title || fallbackKey;
      return descriptor;
    }

    if (form === FormIndex.YEAR) {
      descriptor.key = `${dateParts.year}`;
      descriptor.title = descriptor.key;
      return descriptor;
    }

    if (form === FormIndex.MONTH) {
      descriptor.key = `${dateParts.year}-${this.pad2(dateParts.month)}`;
      descriptor.title = descriptor.key;
      return descriptor;
    }

    descriptor.key = `${dateParts.year}-${this.pad2(dateParts.month)}-${this.pad2(dateParts.day)}`;
    descriptor.title = fallbackSection.title || descriptor.key;
    return descriptor;
  }

  private resolveAssetDateParts(
    asset: HybridPhotoAsset,
    fallbackSection: HybridPhotoSection,
  ): HybridDateParts | undefined {
    if (asset.createdAt) {
      const createdAt = new Date(asset.createdAt);
      if (!Number.isNaN(createdAt.getTime())) {
        const dateParts = new HybridDateParts();
        dateParts.year = createdAt.getFullYear();
        dateParts.month = createdAt.getMonth() + 1;
        dateParts.day = createdAt.getDate();
        return dateParts;
      }
    }

    const fallbackText = fallbackSection.key || fallbackSection.title || '';
    const matched = fallbackText.match(/(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?/);
    if (!matched) {
      return undefined;
    }

    const dateParts = new HybridDateParts();
    dateParts.year = Number(matched[1]);
    dateParts.month = Number(matched[2] ?? '1');
    dateParts.day = Number(matched[3] ?? '1');
    return dateParts;
  }

  private pad2(value: number): string {
    return `${value}`.padStart(2, '0');
  }

  private isSameVisualSection(left: HybridPhotoSection, right: HybridPhotoSection): boolean {
    if (left.key && right.key && left.key === right.key) {
      return true;
    }

    if (left.title && right.title && left.title === right.title) {
      return true;
    }

    return false;
  }

  private createSection(
    key: string,
    title: string,
    rows: Array<Array<HybridPhotoAsset>>,
  ): HybridPhotoSection {
    return {
      key: key,
      title: title,
      rows: rows,
    };
  }

  private flattenRows(rows: Array<Array<HybridPhotoAsset>>): Array<HybridPhotoAsset> {
    const assets: Array<HybridPhotoAsset> = [];
    rows.forEach((row: Array<HybridPhotoAsset>) =>
      row.forEach((asset: HybridPhotoAsset) => assets.push(asset)),
    );
    return assets;
  }

  private chunkAssets(
    assets: Array<HybridPhotoAsset>,
    chunkSize: number,
  ): Array<Array<HybridPhotoAsset>> {
    const rows: Array<Array<HybridPhotoAsset>> = [];
    for (let index = 0; index < assets.length; index += chunkSize) {
      rows.push(assets.slice(index, index + chunkSize));
    }
    return rows;
  }

  private createTimelineRowItem(
    rowEntries: Array<HybridTimelineAssetEntry>,
    layoutId?: number,
  ): HybridTimelineItem {
    const firstEntry = rowEntries[0];
    const stableLayoutId = layoutId ?? this.nextTimelineLayoutId++;
    return {
      layoutId: stableLayoutId,
      key: `row_${stableLayoutId}`,
      kind: "row",
      count: rowEntries.length,
      sectionKey: firstEntry.sectionKey,
      sectionTitle: firstEntry.sectionTitle,
      sectionCount: firstEntry.sectionCount,
      assets: rowEntries.map((entry: HybridTimelineAssetEntry) => entry.asset),
      isFirstInSection: firstEntry.isSectionLead,
    };
  }

  private isSameEntrySection(
    left: HybridTimelineAssetEntry,
    right: HybridTimelineAssetEntry,
  ): boolean {
    if (left.sectionKey && right.sectionKey) {
      return left.sectionKey === right.sectionKey;
    }

    if (left.sectionTitle && right.sectionTitle) {
      return left.sectionTitle === right.sectionTitle;
    }

    return left.sectionKey === right.sectionKey && left.sectionTitle === right.sectionTitle;
  }

  private isSameEntrySectionAsItem(
    entry: HybridTimelineAssetEntry,
    item: HybridTimelineItem,
  ): boolean {
    if (entry.sectionKey && item.sectionKey) {
      return entry.sectionKey === item.sectionKey;
    }

    if (entry.sectionTitle && item.sectionTitle) {
      return entry.sectionTitle === item.sectionTitle;
    }

    return entry.sectionKey === item.sectionKey && entry.sectionTitle === item.sectionTitle;
  }

  private assetStableKey(asset: HybridPhotoAsset): string {
    return asset.remoteId ?? asset.localId ?? asset.id ?? asset.thumbnailUrl ?? "";
  }

  private flattenSectionsToAssets(sections: Array<HybridPhotoSection>): Array<HybridPhotoAsset> {
    const assets: Array<HybridPhotoAsset> = [];
    sections.forEach((section: HybridPhotoSection) => {
      this.flattenRows(section.rows).forEach((asset: HybridPhotoAsset) => assets.push(asset));
    });
    return assets;
  }
}
