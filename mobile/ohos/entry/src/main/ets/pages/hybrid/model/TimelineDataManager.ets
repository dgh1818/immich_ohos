import * as Shared from '../PhotoGridShared';
import { PhotoGridDataAdapter } from '../adapter/PhotoGridDataAdapter';
import { FormIndex, getColumnsByFormIndex } from '../statemanager/constants/GridDefine';

type BucketInfo = Shared.BucketInfo;
type GroupInfo = Shared.GroupInfo;
type GridItem = Shared.GridItem;
type PhotoSection = Shared.PhotoSection;
type PhotoAsset = Shared.PhotoAsset;
type TimelineItem = Shared.TimelineItem;

interface TimelineFormWindowState {
  sections: Array<PhotoSection>;
  groupDayGroups: Array<GroupInfo>;
  windowStartOffset: number;
  windowPhotoCount: number;
}

interface TimelineSlidingWindowUpdateResult {
  windowState: TimelineFormWindowState;
  anchorGridIndex: number;
  fillPosition: number;
}

interface SourceSectionIndexEntry {
  key: string;
  title: string;
  startOffset: number;
  endOffset: number;
  count: number;
  flatStartIndex: number;
  flatEndIndex: number;
}

class SourceSectionIndexEntryRecord implements SourceSectionIndexEntry {
  key: string = '';
  title: string = '';
  startOffset: number = 0;
  endOffset: number = 0;
  count: number = 0;
  flatStartIndex: number = 0;
  flatEndIndex: number = 0;
}

class GroupInfoRecord implements GroupInfo {
  key: string = '';
  title: string = '';
  count: number = 0;
  offset: number = 0;
}

export interface TimelineDataSourceState {
  sections: Array<PhotoSection>;
  groupDayGroups: Array<GroupInfo>;
  yearBuckets: Array<BucketInfo>;
  monthBuckets: Array<BucketInfo>;
  windowStartOffset: number;
  windowEndOffset: number;
  hasMore: boolean;
}

export enum TimelinePreloadReason {
  ADJACENT_PRELOAD = 0,
  PINCH_PRE_SWITCH,
  ACTIVE_VISIBLE_WINDOW,
  POST_COMMIT,
}

export interface TimelinePreloadRequest {
  form: FormIndex;
  firstIndex: number;
  anchorPhotoOffset: number;
  fillPosition: number;
  includeTail: boolean;
  reason: TimelinePreloadReason;
  viewportItemCount: number;
  backwardBufferItemCount: number;
  forwardBufferItemCount: number;
}

export interface TimelinePreloadResult {
  gridItems: Array<GridItem>;
  anchorGridIndex: number;
  windowStartPhotoOffset: number;
  windowPhotoCount: number;
  fillPosition: number;
}

interface TimelineWindowUpdateMetricBucket {
  reason: TimelinePreloadReason;
  startedAt: number;
  eventCount: number;
  totalMs: number;
  maxMs: number;
  over8MsCount: number;
  buildDefaultTotalMs: number;
  buildDefaultMaxMs: number;
  flattenAssetsTotalMs: number;
  flattenAssetsMaxMs: number;
  rangeResolveTotalMs: number;
  rangeResolveMaxMs: number;
  sliceSectionsTotalMs: number;
  sliceSectionsMaxMs: number;
  groupDayGroupsTotalMs: number;
  groupDayGroupsMaxMs: number;
  fillPositionTotalMs: number;
  fillPositionMaxMs: number;
  buildGridItemsTotalMs: number;
  buildGridItemsMaxMs: number;
  anchorResolveTotalMs: number;
  anchorResolveMaxMs: number;
}

class TimelineWindowPerfStats {
  private static readonly SUMMARY_INTERVAL_MS: number = 2000;
  private static readonly MAX_EVENT_COUNT: number = 32;
  private static readonly SLOW_WINDOW_UPDATE_MS: number = 8;
  private static bucket: TimelineWindowUpdateMetricBucket = TimelineWindowPerfStats.createBucket(
    TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW,
  );

  private static createBucket(reason: TimelinePreloadReason): TimelineWindowUpdateMetricBucket {
    return {
      reason: reason,
      startedAt: Date.now(),
      eventCount: 0,
      totalMs: 0,
      maxMs: 0,
      over8MsCount: 0,
      buildDefaultTotalMs: 0,
      buildDefaultMaxMs: 0,
      flattenAssetsTotalMs: 0,
      flattenAssetsMaxMs: 0,
      rangeResolveTotalMs: 0,
      rangeResolveMaxMs: 0,
      sliceSectionsTotalMs: 0,
      sliceSectionsMaxMs: 0,
      groupDayGroupsTotalMs: 0,
      groupDayGroupsMaxMs: 0,
      fillPositionTotalMs: 0,
      fillPositionMaxMs: 0,
      buildGridItemsTotalMs: 0,
      buildGridItemsMaxMs: 0,
      anchorResolveTotalMs: 0,
      anchorResolveMaxMs: 0,
    };
  }

  private static hasMetrics(): boolean {
    return TimelineWindowPerfStats.bucket.eventCount > 0;
  }

  private static ensureBucket(reason: TimelinePreloadReason): void {
    if (!TimelineWindowPerfStats.hasMetrics()) {
      TimelineWindowPerfStats.bucket = TimelineWindowPerfStats.createBucket(reason);
      return;
    }
    if (TimelineWindowPerfStats.bucket.reason !== reason) {
      TimelineWindowPerfStats.flush('reason-switch');
      TimelineWindowPerfStats.bucket = TimelineWindowPerfStats.createBucket(reason);
    }
  }

  private static resolveReasonLabel(reason: TimelinePreloadReason): string {
    switch (reason) {
      case TimelinePreloadReason.ADJACENT_PRELOAD:
        return 'ADJACENT_PRELOAD';
      case TimelinePreloadReason.PINCH_PRE_SWITCH:
        return 'PINCH_PRE_SWITCH';
      case TimelinePreloadReason.POST_COMMIT:
        return 'POST_COMMIT';
      case TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW:
      default:
        return 'ACTIVE_VISIBLE_WINDOW';
    }
  }

  static noteWindowUpdate(
    reason: TimelinePreloadReason,
    totalMs: number,
    buildDefaultMs: number,
    flattenAssetsMs: number,
    rangeResolveMs: number,
    sliceSectionsMs: number,
    groupDayGroupsMs: number,
    fillPositionMs: number,
    buildGridItemsMs: number,
    anchorResolveMs: number,
  ): void {
    TimelineWindowPerfStats.ensureBucket(reason);
    const bucket = TimelineWindowPerfStats.bucket;
    bucket.eventCount += 1;
    bucket.totalMs += totalMs;
    bucket.maxMs = Math.max(bucket.maxMs, totalMs);
    if (totalMs > TimelineWindowPerfStats.SLOW_WINDOW_UPDATE_MS) {
      bucket.over8MsCount += 1;
    }
    bucket.buildDefaultTotalMs += buildDefaultMs;
    bucket.buildDefaultMaxMs = Math.max(bucket.buildDefaultMaxMs, buildDefaultMs);
    bucket.flattenAssetsTotalMs += flattenAssetsMs;
    bucket.flattenAssetsMaxMs = Math.max(bucket.flattenAssetsMaxMs, flattenAssetsMs);
    bucket.rangeResolveTotalMs += rangeResolveMs;
    bucket.rangeResolveMaxMs = Math.max(bucket.rangeResolveMaxMs, rangeResolveMs);
    bucket.sliceSectionsTotalMs += sliceSectionsMs;
    bucket.sliceSectionsMaxMs = Math.max(bucket.sliceSectionsMaxMs, sliceSectionsMs);
    bucket.groupDayGroupsTotalMs += groupDayGroupsMs;
    bucket.groupDayGroupsMaxMs = Math.max(bucket.groupDayGroupsMaxMs, groupDayGroupsMs);
    bucket.fillPositionTotalMs += fillPositionMs;
    bucket.fillPositionMaxMs = Math.max(bucket.fillPositionMaxMs, fillPositionMs);
    bucket.buildGridItemsTotalMs += buildGridItemsMs;
    bucket.buildGridItemsMaxMs = Math.max(bucket.buildGridItemsMaxMs, buildGridItemsMs);
    bucket.anchorResolveTotalMs += anchorResolveMs;
    bucket.anchorResolveMaxMs = Math.max(bucket.anchorResolveMaxMs, anchorResolveMs);
    TimelineWindowPerfStats.maybeFlush('interval');
  }

  private static maybeFlush(reason: string): void {
    if (!TimelineWindowPerfStats.hasMetrics()) {
      return;
    }
    if (
      TimelineWindowPerfStats.bucket.eventCount < TimelineWindowPerfStats.MAX_EVENT_COUNT &&
      Date.now() - TimelineWindowPerfStats.bucket.startedAt < TimelineWindowPerfStats.SUMMARY_INTERVAL_MS
    ) {
      return;
    }
    TimelineWindowPerfStats.flush(reason);
  }

  static flush(reason: string): void {
    if (!TimelineWindowPerfStats.hasMetrics()) {
      return;
    }
    const bucket = TimelineWindowPerfStats.bucket;
    const durationMs = Math.max(1, Date.now() - bucket.startedAt);
    const avgMs = Math.round(bucket.totalMs / Math.max(1, bucket.eventCount));
    console.info(
      `[TimelineDataManager] windowUpdateMetrics reason=${TimelineWindowPerfStats.resolveReasonLabel(bucket.reason)} ` +
      `flush=${reason} durationMs=${durationMs} events=${bucket.eventCount} totalMs=${bucket.totalMs} avgMs=${avgMs} ` +
      `maxMs=${bucket.maxMs} over8Ms=${bucket.over8MsCount} ` +
      `buildDefaultMs=${bucket.buildDefaultTotalMs} buildDefaultMaxMs=${bucket.buildDefaultMaxMs} ` +
      `flattenAssetsMs=${bucket.flattenAssetsTotalMs} flattenAssetsMaxMs=${bucket.flattenAssetsMaxMs} ` +
      `rangeResolveMs=${bucket.rangeResolveTotalMs} rangeResolveMaxMs=${bucket.rangeResolveMaxMs} ` +
      `sliceSectionsMs=${bucket.sliceSectionsTotalMs} sliceSectionsMaxMs=${bucket.sliceSectionsMaxMs} ` +
      `groupDayGroupsMs=${bucket.groupDayGroupsTotalMs} groupDayGroupsMaxMs=${bucket.groupDayGroupsMaxMs} ` +
      `fillPositionMs=${bucket.fillPositionTotalMs} fillPositionMaxMs=${bucket.fillPositionMaxMs} ` +
      `buildGridItemsMs=${bucket.buildGridItemsTotalMs} buildGridItemsMaxMs=${bucket.buildGridItemsMaxMs} ` +
      `anchorResolveMs=${bucket.anchorResolveTotalMs} anchorResolveMaxMs=${bucket.anchorResolveMaxMs}`,
    );
    TimelineWindowPerfStats.bucket = TimelineWindowPerfStats.createBucket(bucket.reason);
  }
}

export class TimelineDataManager {
  private readonly dataAdapter: PhotoGridDataAdapter = new PhotoGridDataAdapter();
  private readonly formWindowStates: Array<TimelineFormWindowState | undefined> = [undefined, undefined, undefined, undefined];
  private sections: Array<PhotoSection> = [];
  private sourceFlatAssets: Array<PhotoAsset> = [];
  private sourceSectionIndexEntries: Array<SourceSectionIndexEntry> = [];
  private sourceGroupDayGroups: Array<GroupInfo> = [];
  private yearBuckets: Array<BucketInfo> = [];
  private monthBuckets: Array<BucketInfo> = [];
  private windowStartOffset: number = 0;
  private windowEndOffset: number = 0;

  public updateSourceState(state: TimelineDataSourceState): void {
    this.mergeSourceState(state, true);
    this.yearBuckets = state.yearBuckets.slice();
    this.monthBuckets = state.monthBuckets.slice();
    this.resetSlidingWindowState();
  }

  /**
   * 更新数据源但保留现有滑动窗口位置（滚动中使用）
   * 对齐参考程序: 滚动中数据加载不重置窗口位置
   */
  public updateSourceStatePreservingWindow(state: TimelineDataSourceState): void {
    this.mergeSourceState(state, true);
    this.yearBuckets = state.yearBuckets.slice();
    this.monthBuckets = state.monthBuckets.slice();
    // 不调用 resetSlidingWindowState()，保留滚动中的窗口位置
  }

  public appendSourcePage(state: TimelineDataSourceState): void {
    this.mergeSourceState(state, false);
    if (state.yearBuckets.length > 0) {
      this.yearBuckets = state.yearBuckets.slice();
    }
    if (state.monthBuckets.length > 0) {
      this.monthBuckets = state.monthBuckets.slice();
    }
  }

  public reset(): void {
    this.sections = [];
    this.sourceFlatAssets = [];
    this.sourceSectionIndexEntries = [];
    this.sourceGroupDayGroups = [];
    this.yearBuckets = [];
    this.monthBuckets = [];
    this.windowStartOffset = 0;
    this.windowEndOffset = 0;
    this.resetSlidingWindowState();
  }

  public hasSections(): boolean {
    return this.sections.length > 0;
  }

  public getSections(): Array<PhotoSection> {
    return this.dataAdapter.cloneSections(this.sections);
  }

  public getSectionsForForm(form: FormIndex): Array<PhotoSection> {
    return this.dataAdapter.cloneSections(this.resolveOwnedWindowState(form).sections);
  }

  public getSourceSectionsForForm(form: FormIndex): Array<PhotoSection> {
    return this.dataAdapter.cloneSections(this.resolveSourceSectionsForForm(form));
  }

  public getSourceGroupDayGroups(form: FormIndex = FormIndex.GROUP_DAY): Array<GroupInfo> {
    if (form !== FormIndex.GROUP_DAY) {
      return [];
    }
    return this.cloneGroups(this.sourceGroupDayGroups);
  }

  public buildSourceGridItemsForForm(form: FormIndex): Array<GridItem> {
    const sourceWindowState = this.buildSourceWindowState(form);
    return this.buildGridItemsFromWindowState(form, sourceWindowState);
  }

  public buildSourceTimelineItemsForForm(form: FormIndex): Array<TimelineItem> {
    return this.buildTimelineItemsFromWindowState(form, this.buildSourceWindowState(form));
  }

  public resolveSourceFillPositionForForm(form: FormIndex): number {
    const sourceWindowState = this.buildSourceWindowState(form);
    return this.resolveSourceFillPositionForWindowStart(
      form,
      sourceWindowState,
      sourceWindowState.windowStartOffset,
    );
  }

  public resolveSourceGridIndexForPhotoOffset(form: FormIndex, photoOffset: number): number {
    const sourceWindowState = this.buildSourceWindowState(form);
    const fillPosition = this.resolveSourceFillPositionForWindowStart(
      form,
      sourceWindowState,
      sourceWindowState.windowStartOffset,
    );
    return this.resolveGridIndexForPhotoOffsetInWindowState(form, sourceWindowState, photoOffset, fillPosition);
  }

  public resolveSourceTimelineRowIndexForGridIndex(form: FormIndex, gridIndex: number): number {
    const sourceWindowState = this.buildSourceWindowState(form);
    const fillPosition = this.resolveSourceFillPositionForWindowStart(
      form,
      sourceWindowState,
      sourceWindowState.windowStartOffset,
    );
    const safeGridIndex = Math.max(0, gridIndex - fillPosition);
    const columns = Math.max(1, getColumnsByFormIndex(form));
    if (form !== FormIndex.GROUP_DAY) {
      return Math.max(0, Math.floor(safeGridIndex / columns));
    }
    return this.resolveGroupTimelineRowIndex(sourceWindowState.groupDayGroups, columns, safeGridIndex);
  }

  public getGroupDayGroups(form: FormIndex = FormIndex.GROUP_DAY): Array<GroupInfo> {
    if (form !== FormIndex.GROUP_DAY) {
      return [];
    }
    return this.resolveOwnedWindowState(form).groupDayGroups.slice();
  }

  public getYearBuckets(): Array<BucketInfo> {
    return this.yearBuckets.slice();
  }

  public getMonthBuckets(): Array<BucketInfo> {
    return this.monthBuckets.slice();
  }

  public getWindowStartOffsetForForm(form: FormIndex): number {
    return this.resolveOwnedWindowState(form).windowStartOffset;
  }

  public getWindowEndOffsetForForm(form: FormIndex): number {
    const windowState = this.resolveOwnedWindowState(form);
    return windowState.windowStartOffset + Math.max(0, windowState.windowPhotoCount);
  }

  public getWindowPhotoCountForForm(form: FormIndex): number {
    return this.resolveOwnedWindowState(form).windowPhotoCount;
  }

  public getSourceWindowStartOffset(): number {
    return this.windowStartOffset;
  }

  public getSourceWindowEndOffset(): number {
    return this.windowEndOffset;
  }

  public resetSlidingWindowState(form?: FormIndex): void {
    if (form === undefined) {
      this.formWindowStates.fill(undefined);
      return;
    }
    if (!this.isValidForm(form)) {
      return;
    }
    this.formWindowStates[form] = undefined;
  }

  public updateSlidingWindowState(
    activeForm: FormIndex,
    preloadRequest?: TimelinePreloadRequest,
  ): TimelinePreloadResult | undefined {
    if (!preloadRequest) {
      if (this.isValidForm(activeForm) && this.formWindowStates[activeForm] === undefined) {
        this.setFormWindowState(activeForm, this.buildDefaultWindowState(activeForm));
      }
      return undefined;
    }

    if (preloadRequest.form !== activeForm && this.isValidForm(activeForm) && this.formWindowStates[activeForm] === undefined) {
      this.setFormWindowState(activeForm, this.buildDefaultWindowState(activeForm));
    }

    const existingWindowState = this.isValidForm(preloadRequest.form)
      ? this.formWindowStates[preloadRequest.form]
      : undefined;
    if (
      preloadRequest.reason === TimelinePreloadReason.ACTIVE_VISIBLE_WINDOW &&
      preloadRequest.form === activeForm &&
      existingWindowState &&
      !this.shouldShiftActiveWindow(preloadRequest, existingWindowState)
    ) {
      return undefined;
    }

    const preloadWindowResult = this.buildWindowUpdateResult(preloadRequest);
    this.setFormWindowState(preloadRequest.form, preloadWindowResult.windowState);
    const gridItems = this.buildGridItemsFromWindowState(preloadRequest.form, preloadWindowResult.windowState);
    return {
      gridItems: gridItems,
      anchorGridIndex: preloadWindowResult.anchorGridIndex,
      windowStartPhotoOffset: preloadWindowResult.windowState.windowStartOffset,
      windowPhotoCount: preloadWindowResult.windowState.windowPhotoCount,
      fillPosition: preloadWindowResult.fillPosition,
    };
  }

  public buildGridItemsForForm(form: FormIndex): Array<GridItem> {
    return this.buildGridItemsFromWindowState(form, this.resolveOwnedWindowState(form));
  }

  public buildTimelineItemsForForm(form: FormIndex): Array<TimelineItem> {
    return this.buildTimelineItemsFromWindowState(form, this.resolveOwnedWindowState(form));
  }

  public resolveGridIndexForPhotoOffset(
    form: FormIndex,
    photoOffset: number,
    fillPosition: number = 0,
  ): number {
    return this.resolveGridIndexForPhotoOffsetInWindowState(
      form,
      this.resolveOwnedWindowState(form),
      photoOffset,
      fillPosition,
    );
  }

  public resolveTimelineRowIndexForGridIndex(
    form: FormIndex,
    gridIndex: number,
    fillPosition: number = 0,
  ): number {
    const safeGridIndex = Math.max(0, gridIndex - Math.max(0, fillPosition));
    const columns = Math.max(1, getColumnsByFormIndex(form));
    if (form !== FormIndex.GROUP_DAY) {
      return Math.max(0, Math.floor(safeGridIndex / columns));
    }
    return this.resolveGroupTimelineRowIndex(
      this.resolveOwnedWindowState(form).groupDayGroups,
      columns,
      safeGridIndex,
    );
  }

  public resolveFormPhotoAssets(form: FormIndex): Array<PhotoAsset> {
    return this.dataAdapter.flattenAssets(this.resolveOwnedWindowState(form).sections);
  }

  private resolveSourcePhotoAssets(form: FormIndex, sections: Array<PhotoSection>): Array<PhotoAsset> {
    if (form === FormIndex.DAY || form === FormIndex.GROUP_DAY) {
      return this.sourceFlatAssets;
    }
    return this.dataAdapter.flattenAssets(sections);
  }

  private resolveSourcePhotoCount(form: FormIndex, sections: Array<PhotoSection>): number {
    if (form === FormIndex.DAY || form === FormIndex.GROUP_DAY) {
      return this.sourceFlatAssets.length;
    }
    return this.dataAdapter.countAssets(sections);
  }

  private resolveOwnedWindowState(form: FormIndex): TimelineFormWindowState {
    if (!this.isValidForm(form)) {
      return {
        sections: [],
        groupDayGroups: [],
        windowStartOffset: this.windowStartOffset,
        windowPhotoCount: 0,
      };
    }
    return this.formWindowStates[form] ?? this.buildDefaultWindowState(form);
  }

  private mergeSourceState(state: TimelineDataSourceState, replaceExisting: boolean): void {
    const incomingSections = this.dataAdapter.cloneSections(state.sections);
    const incomingPhotoCount = this.dataAdapter.countAssets(incomingSections);
    const incomingEndOffset = state.windowEndOffset > 0
      ? Math.max(0, state.windowEndOffset)
      : Math.max(0, state.windowStartOffset) + incomingPhotoCount;
    const incomingStartOffset = Math.max(0, incomingEndOffset - incomingPhotoCount);

    if (incomingSections.length <= 0 || incomingPhotoCount <= 0) {
      if (replaceExisting) {
        this.sections = [];
        this.sourceFlatAssets = [];
        this.sourceSectionIndexEntries = [];
        this.sourceGroupDayGroups = [];
        this.windowStartOffset = 0;
        this.windowEndOffset = 0;
      }
      return;
    }

    if (this.sections.length <= 0) {
      this.applySourceSections(incomingSections, incomingStartOffset, incomingEndOffset, state.groupDayGroups);
      return;
    }

    const currentStartOffset = this.windowStartOffset;
    const currentEndOffset = this.windowEndOffset;

    if (incomingStartOffset <= currentStartOffset && incomingEndOffset >= currentEndOffset) {
      this.applySourceSections(incomingSections, incomingStartOffset, incomingEndOffset, state.groupDayGroups);
      return;
    }

    if (incomingStartOffset >= currentStartOffset && incomingEndOffset <= currentEndOffset) {
      return;
    }

    if (incomingStartOffset === currentEndOffset) {
      this.applySourceSections(
        this.mergeContiguousSections(this.sections, incomingSections),
        currentStartOffset,
        Math.max(currentEndOffset, incomingEndOffset),
        [],
      );
      return;
    }

    if (incomingEndOffset === currentStartOffset) {
      this.applySourceSections(
        this.mergeContiguousSections(incomingSections, this.sections),
        incomingStartOffset,
        currentEndOffset,
        [],
      );
      return;
    }

    if (replaceExisting) {
      this.applySourceSections(incomingSections, incomingStartOffset, incomingEndOffset, state.groupDayGroups);
    }
  }

  private applySourceSections(
    sections: Array<PhotoSection>,
    startOffset: number,
    endOffset: number,
    sourceGroups: Array<GroupInfo>,
  ): void {
    this.sections = this.dataAdapter.cloneSections(sections);
    this.sourceFlatAssets = this.dataAdapter.flattenAssets(this.sections);
    this.windowStartOffset = Math.max(0, startOffset);
    this.windowEndOffset = Math.max(this.windowStartOffset, endOffset);
    this.sourceGroupDayGroups = this.resolveSourceGroupDayGroups(this.sections, this.windowStartOffset, sourceGroups);
    this.sourceSectionIndexEntries = this.buildSourceSectionIndexEntries(this.sections, this.sourceGroupDayGroups, this.windowStartOffset);
  }

  private cloneGroups(groups: Array<GroupInfo>): Array<GroupInfo> {
    const clonedGroups: Array<GroupInfo> = [];
    groups.forEach((group: GroupInfo) => {
      const record = new GroupInfoRecord();
      record.key = group.key;
      record.title = group.title;
      record.count = group.count;
      record.offset = group.offset;
      clonedGroups.push(record);
    });
    return clonedGroups;
  }

  private resolveSourceGroupDayGroups(
    sections: Array<PhotoSection>,
    windowStartOffset: number,
    sourceGroups: Array<GroupInfo>,
  ): Array<GroupInfo> {
    if (this.areGroupsAlignedToSections(sourceGroups, sections, windowStartOffset)) {
      return this.cloneGroups(sourceGroups);
    }
    return this.deriveGroupsForSections(sections, windowStartOffset);
  }

  private areGroupsAlignedToSections(
    groups: Array<GroupInfo>,
    sections: Array<PhotoSection>,
    windowStartOffset: number,
  ): boolean {
    if (groups.length !== sections.length) {
      return false;
    }

    let expectedOffset = Math.max(0, windowStartOffset);
    for (let index = 0; index < sections.length; index += 1) {
      const section = sections[index];
      const group = groups[index];
      const sectionCount = this.dataAdapter.countSectionAssets(section);
      if (!group || group.key !== section.key || group.title !== section.title) {
        return false;
      }
      if (group.offset !== expectedOffset || group.count !== sectionCount) {
        return false;
      }
      expectedOffset += sectionCount;
    }

    return true;
  }

  private buildSourceSectionIndexEntries(
    sections: Array<PhotoSection>,
    groups: Array<GroupInfo>,
    startOffset: number,
  ): Array<SourceSectionIndexEntry> {
    const entries: Array<SourceSectionIndexEntry> = [];
    let runningOffset = Math.max(0, startOffset);
    let runningFlatIndex = 0;
    for (let index = 0; index < sections.length; index += 1) {
      const section = sections[index];
      const group = groups[index];
      const count = this.dataAdapter.countSectionAssets(section);
      const sectionStartOffset = group ? group.offset : runningOffset;
      const sectionEndOffset = sectionStartOffset + count;
      const entry = new SourceSectionIndexEntryRecord();
      entry.key = section.key;
      entry.title = section.title;
      entry.startOffset = sectionStartOffset;
      entry.endOffset = sectionEndOffset;
      entry.count = count;
      entry.flatStartIndex = runningFlatIndex;
      entry.flatEndIndex = runningFlatIndex + count;
      entries.push(entry);
      runningOffset = sectionEndOffset;
      runningFlatIndex = entry.flatEndIndex;
    }
    return entries;
  }

  private mergeContiguousSections(
    currentSections: Array<PhotoSection>,
    incomingSections: Array<PhotoSection>,
  ): Array<PhotoSection> {
    const mergedSections = this.dataAdapter.cloneSections(currentSections);
    const normalizedIncomingSections = this.dataAdapter.cloneSections(incomingSections);
    if (mergedSections.length <= 0) {
      return normalizedIncomingSections;
    }
    if (normalizedIncomingSections.length <= 0) {
      return mergedSections;
    }

    const lastSection = mergedSections[mergedSections.length - 1];
    const firstIncomingSection = normalizedIncomingSections[0];
    if (lastSection.key === firstIncomingSection.key && lastSection.title === firstIncomingSection.title) {
      const dedupedCount = this.appendDedupedSectionRows(lastSection, firstIncomingSection);
      if (dedupedCount > 0) {
        console.info(
          `[TimelineDataManager] deduped ${dedupedCount} overlapping assets while merging section ${lastSection.key || lastSection.title}`,
        );
      }
      normalizedIncomingSections.shift();
    }

    normalizedIncomingSections.forEach((section: PhotoSection) => {
      mergedSections.push(section);
    });
    return mergedSections;
  }

  private appendDedupedSectionRows(targetSection: PhotoSection, incomingSection: PhotoSection): number {
    const seenAssetKeys: Set<string> = new Set();
    let dedupedCount = 0;
    let appendedAssetCount = 0;

    targetSection.rows.forEach((row: Array<PhotoAsset>) => {
      row.forEach((asset: PhotoAsset) => {
        seenAssetKeys.add(this.assetStableKey(asset));
      });
    });

    incomingSection.rows.forEach((row: Array<PhotoAsset>) => {
      const filteredRow: Array<PhotoAsset> = [];
      row.forEach((asset: PhotoAsset) => {
        const assetKey = this.assetStableKey(asset);
        if (seenAssetKeys.has(assetKey)) {
          dedupedCount += 1;
          return;
        }
        seenAssetKeys.add(assetKey);
        filteredRow.push(asset);
      });

      if (filteredRow.length > 0) {
        appendedAssetCount += filteredRow.length;
        targetSection.rows.push(filteredRow);
      }
    });

    if (appendedAssetCount > 0) {
      this.invalidateSectionDerivedMetadata(targetSection);
    }

    return dedupedCount;
  }

  private invalidateSectionDerivedMetadata(section: PhotoSection): void {
    section.assetCount = undefined;
    section.sourceStartOffset = undefined;
    section.sourceEndOffsetExclusive = undefined;
    section.sourceFlatStartIndex = undefined;
    section.sourceFlatEndIndexExclusive = undefined;
  }

  private assetStableKey(asset: PhotoAsset): string {
    return asset.remoteId ?? asset.localId ?? asset.id ?? asset.thumbnailUrl ?? '';
  }

  private setFormWindowState(form: FormIndex, windowState: TimelineFormWindowState): void {
    if (!this.isValidForm(form)) {
      return;
    }
    this.formWindowStates[form] = {
      sections: this.dataAdapter.cloneSections(windowState.sections),
      groupDayGroups: windowState.groupDayGroups.slice(),
      windowStartOffset: Math.max(0, windowState.windowStartOffset),
      windowPhotoCount: Math.max(0, windowState.windowPhotoCount),
    };
  }

  private buildDefaultWindowState(form: FormIndex): TimelineFormWindowState {
    const sections = this.resolveSourceSectionsForForm(form);
    return {
      sections: this.dataAdapter.cloneSections(sections),
      groupDayGroups: form === FormIndex.GROUP_DAY
        ? this.cloneGroups(this.sourceGroupDayGroups)
        : [],
      windowStartOffset: this.windowStartOffset,
      windowPhotoCount: this.resolveSourcePhotoCount(form, sections),
    };
  }

  private buildSourceWindowState(form: FormIndex): TimelineFormWindowState {
    const sections = this.resolveSourceSectionsForForm(form);
    return {
      sections: sections,
      groupDayGroups: form === FormIndex.GROUP_DAY
        ? this.cloneGroups(this.sourceGroupDayGroups)
        : [],
      windowStartOffset: this.windowStartOffset,
      windowPhotoCount: this.resolveSourcePhotoCount(form, sections),
    };
  }

  private buildWindowUpdateResult(request: TimelinePreloadRequest): TimelineSlidingWindowUpdateResult {
    const startedAt = Date.now();
    const buildDefaultStartedAt = Date.now();
    const fullSections = this.resolveSourceSectionsForForm(request.form);
    const fullWindowState: TimelineFormWindowState = {
      sections: fullSections,
      groupDayGroups: request.form === FormIndex.GROUP_DAY
        ? this.cloneGroups(this.sourceGroupDayGroups)
        : [],
      windowStartOffset: this.windowStartOffset,
      windowPhotoCount: 0,
    };
    const buildDefaultMs = Date.now() - buildDefaultStartedAt;

    const flattenAssetsStartedAt = Date.now();
    const formPhotoAssets = this.resolveSourcePhotoAssets(request.form, fullSections);
    const flattenAssetsMs = Date.now() - flattenAssetsStartedAt;
    const totalPhotoCount = formPhotoAssets.length;
    fullWindowState.windowPhotoCount = totalPhotoCount;
    if (totalPhotoCount <= 0) {
      TimelineWindowPerfStats.noteWindowUpdate(
        request.reason,
        Date.now() - startedAt,
        buildDefaultMs,
        flattenAssetsMs,
        0,
        0,
        0,
        0,
        0,
        0,
      );
      return {
        windowState: {
          sections: [],
          groupDayGroups: [],
          windowStartOffset: fullWindowState.windowStartOffset,
          windowPhotoCount: 0,
        },
        anchorGridIndex: Math.max(0, request.fillPosition),
        fillPosition: Math.max(0, request.fillPosition),
      };
    }

    const columns = getColumnsByFormIndex(request.form);

    const rangeResolveStartedAt = Date.now();
    const anchorLocalPhotoIndex = this.resolveLocalPhotoOffsetForWindow(
      request.anchorPhotoOffset,
      fullWindowState.windowStartOffset,
      totalPhotoCount,
    );
    const preloadPhotoRange = this.resolvePreloadPhotoRange(
      request,
      totalPhotoCount,
      anchorLocalPhotoIndex,
    );
    const rangeResolveMs = Date.now() - rangeResolveStartedAt;
    const startLocalPhotoIndex = preloadPhotoRange[0];
    const endLocalPhotoIndexExclusive = preloadPhotoRange[1];
    const windowStartOffset = fullWindowState.windowStartOffset + startLocalPhotoIndex;

    const sliceSectionsStartedAt = Date.now();
    const slicedSections = this.sliceSectionsByPhotoRange(
      fullSections,
      startLocalPhotoIndex,
      endLocalPhotoIndexExclusive,
      columns,
      request.form === FormIndex.DAY || request.form === FormIndex.GROUP_DAY ? this.sourceSectionIndexEntries : [],
    );
    const sliceSectionsMs = Date.now() - sliceSectionsStartedAt;

    const groupDayGroupsStartedAt = Date.now();
    const groupDayGroups = request.form === FormIndex.GROUP_DAY
      ? this.sliceSourceGroupsByPhotoRange(windowStartOffset, endLocalPhotoIndexExclusive - startLocalPhotoIndex)
      : [];
    const groupDayGroupsMs = Date.now() - groupDayGroupsStartedAt;
    const windowState: TimelineFormWindowState = {
      sections: slicedSections,
      groupDayGroups: groupDayGroups,
      windowStartOffset: windowStartOffset,
      windowPhotoCount: Math.max(0, endLocalPhotoIndexExclusive - startLocalPhotoIndex),
    };

    const fillPositionStartedAt = Date.now();
    const resolvedFillPosition = request.fillPosition >= 0
      ? Math.max(0, request.fillPosition)
      : this.resolveSourceFillPositionForWindowStart(request.form, fullWindowState, windowState.windowStartOffset);
    const fillPositionMs = Date.now() - fillPositionStartedAt;

    const buildGridItemsStartedAt = Date.now();
    const gridItems = this.buildGridItemsFromWindowState(request.form, windowState);
    const buildGridItemsMs = Date.now() - buildGridItemsStartedAt;
    const anchorAssetId = formPhotoAssets[anchorLocalPhotoIndex]?.id;

    const anchorResolveStartedAt = Date.now();
    const anchorGridIndex = this.resolveAnchorGridIndex(gridItems, anchorAssetId, resolvedFillPosition);
    const anchorResolveMs = Date.now() - anchorResolveStartedAt;
    TimelineWindowPerfStats.noteWindowUpdate(
      request.reason,
      Date.now() - startedAt,
      buildDefaultMs,
      flattenAssetsMs,
      rangeResolveMs,
      sliceSectionsMs,
      groupDayGroupsMs,
      fillPositionMs,
      buildGridItemsMs,
      anchorResolveMs,
    );
    return {
      windowState: windowState,
      anchorGridIndex: anchorGridIndex,
      fillPosition: resolvedFillPosition,
    };
  }

  private resolveSourceFillPositionForWindowStart(
    form: FormIndex,
    fullWindowState: TimelineFormWindowState,
    windowStartPhotoOffset: number,
  ): number {
    return this.resolveGridIndexForPhotoOffsetInWindowState(form, fullWindowState, windowStartPhotoOffset, 0);
  }

  private resolveGridIndexForPhotoOffsetInWindowState(
    form: FormIndex,
    windowState: TimelineFormWindowState,
    photoOffset: number,
    fillPosition: number = 0,
  ): number {
    const safeFillPosition = Math.max(0, fillPosition);
    const safePhotoOffset = Math.max(0, photoOffset);
    const maxLocalOffset = Math.max(0, windowState.windowPhotoCount - 1);
    if (form !== FormIndex.GROUP_DAY) {
      const localOffset = Math.min(
        maxLocalOffset,
        this.resolveLocalPhotoOffset(safePhotoOffset, windowState.windowStartOffset),
      );
      return safeFillPosition + localOffset;
    }

    const localOffset = Math.min(
      maxLocalOffset,
      this.resolveLocalPhotoOffset(safePhotoOffset, windowState.windowStartOffset),
    );
    const headerCount = this.resolveGroupHeaderCountBeforeOffset(windowState.groupDayGroups, safePhotoOffset);
    return safeFillPosition + headerCount + localOffset;
  }

  private buildGridItemsFromWindowState(
    form: FormIndex,
    windowState: TimelineFormWindowState,
  ): Array<GridItem> {
    const columns = getColumnsByFormIndex(form);
    if (form === FormIndex.GROUP_DAY) {
      return this.buildGroupGridItems(
        windowState.sections,
        windowState.groupDayGroups,
        windowState.windowStartOffset,
        this.sourceFlatAssets,
      );
    }
    if (this.shouldUseBucketProjection(form)) {
      return this.dataAdapter.buildGridItemsFromSections(
        windowState.sections,
        windowState.windowStartOffset,
        this.sourceFlatAssets,
      );
    }
    return this.dataAdapter.buildGridItemsForColumns(
      windowState.sections,
      columns,
      windowState.windowStartOffset,
      this.sourceFlatAssets,
    );
  }

  private buildTimelineItemsFromWindowState(
    form: FormIndex,
    windowState: TimelineFormWindowState,
  ): Array<TimelineItem> {
    const columns = getColumnsByFormIndex(form);
    if (this.shouldUseBucketProjection(form)) {
      return this.dataAdapter.buildTimelineItemsForSections(windowState.sections, columns);
    }
    return this.dataAdapter.buildTimelineItemsForColumns(windowState.sections, columns);
  }

  private resolveSourceSectionsForForm(form: FormIndex): Array<PhotoSection> {
    if (form === FormIndex.YEAR) {
      return this.buildBucketProjectedSections(this.yearBuckets, getColumnsByFormIndex(form));
    }
    if (form === FormIndex.MONTH) {
      return this.buildBucketProjectedSections(this.monthBuckets, getColumnsByFormIndex(form));
    }
    return this.sections;
  }

  private buildCanonicalGroupWindowGroups(
    sections: Array<PhotoSection>,
    windowStartOffset: number,
  ): Array<GroupInfo> {
    const canonicalGroups = this.deriveGroupsForSections(sections, windowStartOffset);
    this.validateCanonicalGroupWindowGroups(canonicalGroups, sections, windowStartOffset);
    return canonicalGroups;
  }

  private deriveGroupsForSections(sections: Array<PhotoSection>, startOffset: number): Array<GroupInfo> {
    const derivedGroups: Array<GroupInfo> = [];
    let runningOffset = Math.max(0, startOffset);
    sections.forEach((section: PhotoSection) => {
      const count = this.dataAdapter.countSectionAssets(section);
      derivedGroups.push({
        key: section.key,
        title: section.title,
        count: count,
        offset: runningOffset,
      });
      runningOffset += count;
    });
    return derivedGroups;
  }

  private validateCanonicalGroupWindowGroups(
    canonicalGroups: Array<GroupInfo>,
    sections: Array<PhotoSection>,
    windowStartOffset: number,
  ): void {
    const normalizedWindowStartOffset = Math.max(0, windowStartOffset);
    if (canonicalGroups.length !== sections.length) {
      console.warn(
        `[TimelineDataManager] GROUP_DAY canonical group size mismatch: groups=${canonicalGroups.length}, sections=${sections.length}`,
      );
      return;
    }

    let expectedOffset = normalizedWindowStartOffset;
    for (let index = 0; index < sections.length; index += 1) {
      const section = sections[index];
      const group = canonicalGroups[index];
      const sectionCount = this.dataAdapter.countSectionAssets(section);
      if (!group) {
        console.warn(`[TimelineDataManager] GROUP_DAY canonical group missing at index=${index}`);
        return;
      }
      if (index === 0 && group.offset !== normalizedWindowStartOffset) {
        console.warn(
          `[TimelineDataManager] GROUP_DAY group count mismatch at index=${index}: expected=${sectionCount}, actual=${group.count}`,
        );
        return;
      }
      if (group.offset !== expectedOffset) {
        console.warn(
          `[TimelineDataManager] GROUP_DAY group offset mismatch at index=${index}: expected=${expectedOffset}, actual=${group.offset}`,
        );
        return;
      }
    }
  }

  private isValidForm(form: FormIndex): boolean {
    return form >= FormIndex.YEAR && form <= FormIndex.GROUP_DAY;
  }

  private shouldUseBucketProjection(form: FormIndex): boolean {
    if (form === FormIndex.YEAR) {
      return this.yearBuckets.length > 0;
    }
    if (form === FormIndex.MONTH) {
      return this.monthBuckets.length > 0;
    }
    return false;
  }

  private buildBucketProjectedSections(
    buckets: Array<BucketInfo>,
    columns: number,
  ): Array<PhotoSection> {
    if (buckets.length <= 0) {
      return this.sections;
    }

    const assets = this.sourceFlatAssets;
    if (assets.length <= 0) {
      return [];
    }

    const projectedSections: Array<PhotoSection> = [];
    buckets.forEach((bucket: BucketInfo) => {
      const bucketStartOffset = Math.max(this.windowStartOffset, bucket.offset);
      const bucketEndOffset = Math.min(this.windowEndOffset, bucket.offset + Math.max(0, bucket.count));
      const availableCount = Math.max(0, bucketEndOffset - bucketStartOffset);
      if (availableCount <= 0) {
        return;
      }
      const localStart = Math.max(0, bucketStartOffset - this.windowStartOffset);
      const localEnd = Math.min(assets.length, localStart + availableCount);
      const sectionAssets = assets.slice(localStart, localEnd);
      if (sectionAssets.length <= 0) {
        return;
      }
      projectedSections.push({
        key: bucket.date,
        title: bucket.date,
        rows: this.chunkAssets(sectionAssets, columns),
        assetCount: sectionAssets.length,
        sourceStartOffset: bucketStartOffset,
        sourceEndOffsetExclusive: bucketStartOffset + sectionAssets.length,
        sourceFlatStartIndex: localStart,
        sourceFlatEndIndexExclusive: localStart + sectionAssets.length,
      });
    });

    if (projectedSections.length <= 0) {
      return this.sections;
    }

    return projectedSections;
  }

  private chunkAssets(assets: Array<PhotoAsset>, chunkSize: number): Array<Array<PhotoAsset>> {
    const rows: Array<Array<PhotoAsset>> = [];
    const safeChunkSize = Math.max(1, chunkSize);
    for (let index = 0; index < assets.length; index += safeChunkSize) {
      rows.push(assets.slice(index, Math.min(assets.length, index + safeChunkSize)));
    }
    return rows;
  }

  private resolveLocalPhotoOffset(globalPhotoOffset: number, windowStartOffset: number): number {
    return Math.max(0, globalPhotoOffset - windowStartOffset);
  }

  private buildGroupGridItems(
    sections: Array<PhotoSection>,
    groups: Array<GroupInfo>,
    sourceStartOffset: number = 0,
    sourceFlatAssets?: Array<PhotoAsset>,
  ): Array<GridItem> {
    return this.dataAdapter.buildGroupGridItems(sections, groups, sourceStartOffset, sourceFlatAssets);
  }

  private resolvePreloadPhotoRange(
    request: TimelinePreloadRequest,
    totalPhotoCount: number,
    anchorLocalPhotoIndex: number,
  ): [number, number] {
    const maxPhotoIndex = Math.max(0, totalPhotoCount - 1);
    const safeFirstIndex = this.clamp(request.firstIndex, 0, maxPhotoIndex);
    const safeAnchorLocalPhotoIndex = this.clamp(anchorLocalPhotoIndex, 0, maxPhotoIndex);
    const safeViewportItemCount = Math.max(1, request.viewportItemCount);
    const safeBackwardBufferItemCount = Math.max(1, request.backwardBufferItemCount);
    const safeForwardBufferItemCount = Math.max(1, request.forwardBufferItemCount);
    let startLocalPhotoIndex = Math.max(
      0,
      Math.min(safeFirstIndex, safeAnchorLocalPhotoIndex) - safeBackwardBufferItemCount,
    );
    let endLocalPhotoIndexExclusive = Math.min(
      totalPhotoCount,
      Math.max(
        safeFirstIndex + safeViewportItemCount + safeForwardBufferItemCount,
        safeAnchorLocalPhotoIndex + safeForwardBufferItemCount + 1,
      ),
    );
    const minimumWindowPhotoCount = Math.min(
      totalPhotoCount,
      safeViewportItemCount + safeBackwardBufferItemCount + safeForwardBufferItemCount,
    );
    if (endLocalPhotoIndexExclusive - startLocalPhotoIndex < minimumWindowPhotoCount) {
      endLocalPhotoIndexExclusive = Math.min(totalPhotoCount, startLocalPhotoIndex + minimumWindowPhotoCount);
      startLocalPhotoIndex = Math.max(0, endLocalPhotoIndexExclusive - minimumWindowPhotoCount);
    }
    return [startLocalPhotoIndex, endLocalPhotoIndexExclusive];
  }

  private shouldShiftActiveWindow(
    request: TimelinePreloadRequest,
    currentWindowState: TimelineFormWindowState,
  ): boolean {
    if (currentWindowState.windowPhotoCount <= 0) {
      return true;
    }

    const anchorLocalPhotoOffset = request.anchorPhotoOffset - currentWindowState.windowStartOffset;
    if (anchorLocalPhotoOffset < 0 || anchorLocalPhotoOffset >= currentWindowState.windowPhotoCount) {
      return true;
    }

    const remainingPhotoCount = Math.max(0, currentWindowState.windowPhotoCount - anchorLocalPhotoOffset - 1);
    const shiftThresholdItemCount = this.resolveWindowShiftThresholdItemCount(request);
    return !(anchorLocalPhotoOffset > shiftThresholdItemCount && remainingPhotoCount > shiftThresholdItemCount);
  }

  private resolveWindowShiftThresholdItemCount(request: TimelinePreloadRequest): number {
    const columns = Math.max(1, getColumnsByFormIndex(request.form));
    return Math.max(
      columns * Shared.HYBRID_WINDOW_EMERGENCY_MARGIN,
      Math.min(
        columns * Shared.HYBRID_WINDOW_SHIFT_THRESHOLD,
        Math.max(columns, Math.floor(request.backwardBufferItemCount / 2)),
        Math.max(columns, Math.floor(request.forwardBufferItemCount / 2)),
      ),
    );
  }

  private resolveLocalPhotoOffsetForWindow(
    globalPhotoOffset: number,
    windowStartOffset: number,
    totalPhotoCount: number,
  ): number {
    if (totalPhotoCount <= 0) {
      return 0;
    }
    return this.clamp(globalPhotoOffset - windowStartOffset, 0, totalPhotoCount - 1);
  }

  private sliceSectionsByPhotoRange(
    sections: Array<PhotoSection>,
    startLocalPhotoIndex: number,
    endLocalPhotoIndexExclusive: number,
    columns: number,
    sectionIndexEntries: Array<SourceSectionIndexEntry> = [],
  ): Array<PhotoSection> {
    if (sections.length <= 0 || endLocalPhotoIndexExclusive <= startLocalPhotoIndex) {
      return [];
    }

    const slicedSections: Array<PhotoSection> = [];
    let currentPhotoOffset = 0;
    sections.forEach((section: PhotoSection, sectionIndex: number) => {
      const sectionIndexEntry = sectionIndexEntries.length === sections.length ? sectionIndexEntries[sectionIndex] : undefined;
      const sectionPhotoCount = sectionIndexEntry ? sectionIndexEntry.count : this.dataAdapter.countSectionAssets(section);
      const sectionStartOffset = sectionIndexEntry ? sectionIndexEntry.startOffset - this.windowStartOffset : currentPhotoOffset;
      const sectionEndOffset = sectionStartOffset + sectionPhotoCount;
      currentPhotoOffset = sectionEndOffset;
      if (sectionPhotoCount <= 0 || startLocalPhotoIndex >= sectionEndOffset || endLocalPhotoIndexExclusive <= sectionStartOffset) {
        return;
      }

      const localStartOffset = Math.max(0, startLocalPhotoIndex - sectionStartOffset);
      const localEndOffset = Math.min(sectionPhotoCount, endLocalPhotoIndexExclusive - sectionStartOffset);
      const slicedAssets = sectionIndexEntry
        ? this.sliceSourceFlatAssetsBySectionRange(sectionIndexEntry, localStartOffset, localEndOffset)
        : this.sliceSectionAssets(section, localStartOffset, localEndOffset);
      if (slicedAssets.length <= 0) {
        return;
      }

      const sourceStartOffset = this.windowStartOffset + sectionStartOffset + localStartOffset;
      const sourceFlatStartIndex = sectionIndexEntry
        ? sectionIndexEntry.flatStartIndex + localStartOffset
        : undefined;
      slicedSections.push({
        key: section.key,
        title: section.title,
        rows: this.chunkAssets(slicedAssets, Math.max(1, columns)),
        assetCount: slicedAssets.length,
        sourceStartOffset: sourceStartOffset,
        sourceEndOffsetExclusive: sourceStartOffset + slicedAssets.length,
        sourceFlatStartIndex: sourceFlatStartIndex,
        sourceFlatEndIndexExclusive: typeof sourceFlatStartIndex === 'number'
          ? sourceFlatStartIndex + slicedAssets.length
          : undefined,
      });
    });
    return slicedSections;
  }

  private sliceSourceGroupsByPhotoRange(windowStartOffset: number, windowPhotoCount: number): Array<GroupInfo> {
    if (windowPhotoCount <= 0 || this.sourceSectionIndexEntries.length <= 0) {
      return [];
    }

    const windowEndOffset = windowStartOffset + windowPhotoCount;
    const groups: Array<GroupInfo> = [];
    for (let index = 0; index < this.sourceSectionIndexEntries.length; index += 1) {
      const entry = this.sourceSectionIndexEntries[index];
      if (windowStartOffset >= entry.endOffset || windowEndOffset <= entry.startOffset) {
        continue;
      }

      const clippedStart = Math.max(windowStartOffset, entry.startOffset);
      const clippedEnd = Math.min(windowEndOffset, entry.endOffset);
      const clippedCount = Math.max(0, clippedEnd - clippedStart);
      if (clippedCount <= 0) {
        continue;
      }

      const group = new GroupInfoRecord();
      group.key = entry.key;
      group.title = entry.title;
      group.count = clippedCount;
      group.offset = clippedStart;
      groups.push(group);
    }
    return groups;
  }

  private sliceSourceFlatAssetsBySectionRange(
    sectionIndexEntry: SourceSectionIndexEntry,
    startOffset: number,
    endOffsetExclusive: number,
  ): Array<PhotoAsset> {
    if (endOffsetExclusive <= startOffset) {
      return [];
    }

    const flatStartIndex = Math.max(
      sectionIndexEntry.flatStartIndex,
      sectionIndexEntry.flatStartIndex + startOffset,
    );
    const flatEndIndex = Math.min(
      sectionIndexEntry.flatEndIndex,
      sectionIndexEntry.flatStartIndex + endOffsetExclusive,
    );
    if (flatEndIndex <= flatStartIndex) {
      return [];
    }

    return this.sourceFlatAssets.slice(flatStartIndex, flatEndIndex);
  }

  private sliceSectionAssets(
    section: PhotoSection,
    startOffset: number,
    endOffsetExclusive: number,
  ): Array<PhotoAsset> {
    if (endOffsetExclusive <= startOffset) {
      return [];
    }

    const slicedAssets: Array<PhotoAsset> = [];
    let currentOffset = 0;
    for (let rowIndex = 0; rowIndex < section.rows.length; rowIndex += 1) {
      const row = section.rows[rowIndex];
      const rowStartOffset = currentOffset;
      const rowEndOffset = rowStartOffset + row.length;
      currentOffset = rowEndOffset;
      if (startOffset >= rowEndOffset || endOffsetExclusive <= rowStartOffset) {
        continue;
      }

      const localRowStart = Math.max(0, startOffset - rowStartOffset);
      const localRowEnd = Math.min(row.length, endOffsetExclusive - rowStartOffset);
      for (let assetIndex = localRowStart; assetIndex < localRowEnd; assetIndex += 1) {
        slicedAssets.push(row[assetIndex]);
      }
    }
    return slicedAssets;
  }

  private resolveAnchorGridIndex(
    gridItems: Array<GridItem>,
    anchorAssetId: string | undefined,
    fillPosition: number,
  ): number {
    if (!anchorAssetId) {
      return Math.max(0, fillPosition);
    }

    for (let index = 0; index < gridItems.length; index += 1) {
      const item = gridItems[index];
      if (item.kind === 'photo' && item.asset?.id === anchorAssetId) {
        return index;
      }
    }
    return Math.max(0, fillPosition);
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }

  private resolveGroupHeaderCountBeforeOffset(
    groups: Array<GroupInfo>,
    globalPhotoOffset: number,
  ): number {
    if (groups.length <= 0) {
      return 0;
    }

    let headerCount = 0;
    groups.forEach((group: GroupInfo) => {
      if (group.offset < globalPhotoOffset) {
        headerCount += 1;
      }
    });
    return headerCount;
  }

  private resolveGroupTimelineRowIndex(
    groups: Array<GroupInfo>,
    columns: number,
    safeGridIndex: number,
  ): number {
    if (groups.length <= 0) {
      return Math.max(0, Math.floor(safeGridIndex / Math.max(1, columns)));
    }

    let remainingGridIndex = Math.max(0, safeGridIndex);
    let visiblePhotoCount = 0;
    for (const group of groups) {
      if (remainingGridIndex <= 0) {
        break;
      }

      remainingGridIndex -= 1;
      if (remainingGridIndex < group.count) {
        visiblePhotoCount += remainingGridIndex + 1;
        return Math.max(0, Math.floor(Math.max(0, visiblePhotoCount - 1) / Math.max(1, columns)));
      }

      visiblePhotoCount += group.count;
      remainingGridIndex -= group.count;
    }
    return Math.max(0, Math.floor(Math.max(0, visiblePhotoCount - 1) / Math.max(1, columns)));
  }
}
