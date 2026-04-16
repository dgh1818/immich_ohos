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

export class TimelineDataManager {
  private readonly dataAdapter: PhotoGridDataAdapter = new PhotoGridDataAdapter();
  private readonly formWindowStates: Array<TimelineFormWindowState | undefined> = [undefined, undefined, undefined, undefined];
  private sections: Array<PhotoSection> = [];
  private groupDayGroups: Array<GroupInfo> = [];
  private yearBuckets: Array<BucketInfo> = [];
  private monthBuckets: Array<BucketInfo> = [];
  private windowStartOffset: number = 0;
  private windowEndOffset: number = 0;
  private hasMore: boolean = true;

  public updateSourceState(state: TimelineDataSourceState): void {
    this.mergeSourceState(state, true);
    this.yearBuckets = state.yearBuckets.slice();
    this.monthBuckets = state.monthBuckets.slice();
    this.hasMore = state.hasMore;
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
    this.hasMore = state.hasMore;
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
    this.groupDayGroups = [];
    this.yearBuckets = [];
    this.monthBuckets = [];
    this.windowStartOffset = 0;
    this.windowEndOffset = 0;
    this.hasMore = true;
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
    return this.buildSourceWindowState(form).groupDayGroups.slice();
  }

  public buildSourceGridItemsForForm(
    form: FormIndex,
    includeTail: boolean = true,
  ): Array<GridItem> {
    const sourceWindowState = this.buildSourceWindowState(form);
    const fillPosition = this.resolveSourceFillPositionForWindowStart(
      form,
      sourceWindowState,
      sourceWindowState.windowStartOffset,
    );
    return this.buildGridItemsFromWindowState(form, sourceWindowState, fillPosition, includeTail);
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
    const gridItems = this.buildGridItemsFromWindowState(
      preloadRequest.form,
      preloadWindowResult.windowState,
      preloadWindowResult.fillPosition,
      preloadRequest.includeTail,
    );
    return {
      gridItems: gridItems,
      anchorGridIndex: preloadWindowResult.anchorGridIndex,
      windowStartPhotoOffset: preloadWindowResult.windowState.windowStartOffset,
      windowPhotoCount: preloadWindowResult.windowState.windowPhotoCount,
      fillPosition: preloadWindowResult.fillPosition,
    };
  }

  public buildGridItemsForForm(
    form: FormIndex,
    fillPosition: number = 0,
    includeTail: boolean = true,
  ): Array<GridItem> {
    return this.buildGridItemsFromWindowState(
      form,
      this.resolveOwnedWindowState(form),
      fillPosition,
      includeTail,
    );
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
    const incomingPhotoCount = this.dataAdapter.flattenAssets(incomingSections).length;
    const incomingEndOffset = state.windowEndOffset > 0
      ? Math.max(0, state.windowEndOffset)
      : Math.max(0, state.windowStartOffset) + incomingPhotoCount;
    const incomingStartOffset = Math.max(0, incomingEndOffset - incomingPhotoCount);

    if (incomingSections.length <= 0 || incomingPhotoCount <= 0) {
      if (replaceExisting) {
        this.sections = [];
        this.groupDayGroups = [];
        this.windowStartOffset = 0;
        this.windowEndOffset = 0;
      }
      return;
    }

    if (this.sections.length <= 0) {
      this.applySourceSections(incomingSections, incomingStartOffset, incomingEndOffset);
      return;
    }

    const currentStartOffset = this.windowStartOffset;
    const currentEndOffset = this.windowEndOffset;

    if (incomingStartOffset <= currentStartOffset && incomingEndOffset >= currentEndOffset) {
      this.applySourceSections(incomingSections, incomingStartOffset, incomingEndOffset);
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
      );
      return;
    }

    if (incomingEndOffset === currentStartOffset) {
      this.applySourceSections(
        this.mergeContiguousSections(incomingSections, this.sections),
        incomingStartOffset,
        currentEndOffset,
      );
      return;
    }

    if (replaceExisting) {
      this.applySourceSections(incomingSections, incomingStartOffset, incomingEndOffset);
    }
  }

  private applySourceSections(
    sections: Array<PhotoSection>,
    startOffset: number,
    endOffset: number,
  ): void {
    this.sections = this.dataAdapter.cloneSections(sections);
    this.windowStartOffset = Math.max(0, startOffset);
    this.windowEndOffset = Math.max(this.windowStartOffset, endOffset);
    this.groupDayGroups = this.deriveGroupsForSections(this.sections, this.windowStartOffset);
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
      lastSection.rows = lastSection.rows.concat(firstIncomingSection.rows.map((row: Array<PhotoAsset>) => row.slice()));
      normalizedIncomingSections.shift();
    }

    normalizedIncomingSections.forEach((section: PhotoSection) => {
      mergedSections.push(section);
    });
    return mergedSections;
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
        ? this.buildCanonicalGroupWindowGroups(
            sections,
            this.windowStartOffset,
            this.resolveSourceGroupsForForm(form, sections),
          )
        : [],
      windowStartOffset: this.windowStartOffset,
      windowPhotoCount: this.dataAdapter.flattenAssets(sections).length,
    };
  }

  private buildSourceWindowState(form: FormIndex): TimelineFormWindowState {
    const sections = this.resolveSourceSectionsForForm(form);
    return {
      sections: sections,
      groupDayGroups: form === FormIndex.GROUP_DAY
        ? this.buildCanonicalGroupWindowGroups(
            sections,
            this.windowStartOffset,
            this.resolveSourceGroupsForForm(form, sections),
          )
        : [],
      windowStartOffset: this.windowStartOffset,
      windowPhotoCount: this.dataAdapter.flattenAssets(sections).length,
    };
  }

  private buildWindowUpdateResult(request: TimelinePreloadRequest): TimelineSlidingWindowUpdateResult {
    const fullWindowState = this.buildDefaultWindowState(request.form);
    const fullSections = fullWindowState.sections;
    const sourceGroups = request.form === FormIndex.GROUP_DAY
      ? this.resolveSourceGroupsForForm(request.form, fullSections)
      : [];
    const formPhotoAssets = this.dataAdapter.flattenAssets(fullSections);
    const totalPhotoCount = formPhotoAssets.length;
    if (totalPhotoCount <= 0) {
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
    const startLocalPhotoIndex = preloadPhotoRange[0];
    const endLocalPhotoIndexExclusive = preloadPhotoRange[1];
    const windowStartOffset = fullWindowState.windowStartOffset + startLocalPhotoIndex;
    const slicedSections = this.sliceSectionsByPhotoRange(
      fullSections,
      startLocalPhotoIndex,
      endLocalPhotoIndexExclusive,
      columns,
    );
    const windowState: TimelineFormWindowState = {
      sections: slicedSections,
      groupDayGroups: request.form === FormIndex.GROUP_DAY
        ? this.buildCanonicalGroupWindowGroups(
            slicedSections,
            windowStartOffset,
            this.sliceGroupsByPhotoRange(
              sourceGroups,
              fullWindowState.windowStartOffset,
              startLocalPhotoIndex,
              endLocalPhotoIndexExclusive,
            ),
          )
        : [],
      windowStartOffset: windowStartOffset,
      windowPhotoCount: Math.max(0, endLocalPhotoIndexExclusive - startLocalPhotoIndex),
    };
    const resolvedFillPosition = request.fillPosition >= 0
      ? Math.max(0, request.fillPosition)
      : this.resolveSourceFillPositionForWindowStart(request.form, fullWindowState, windowState.windowStartOffset);
    const gridItems = this.buildGridItemsFromWindowState(
      request.form,
      windowState,
      resolvedFillPosition,
      request.includeTail,
    );
    const anchorAssetId = formPhotoAssets[anchorLocalPhotoIndex]?.id;
    return {
      windowState: windowState,
      anchorGridIndex: this.resolveAnchorGridIndex(gridItems, anchorAssetId, resolvedFillPosition),
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
    const maxLocalOffset = Math.max(0, this.dataAdapter.flattenAssets(windowState.sections).length - 1);
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
    fillPosition: number,
    includeTail: boolean,
  ): Array<GridItem> {
    const columns = getColumnsByFormIndex(form);
    if (form === FormIndex.GROUP_DAY) {
      return this.buildGroupGridItems(
        windowState.sections,
        windowState.groupDayGroups,
        columns,
        this.hasMore,
        fillPosition,
        includeTail,
      );
    }
    if (this.shouldUseBucketProjection(form)) {
      return this.dataAdapter.buildGridItemsFromSections(
        windowState.sections,
        columns,
        this.hasMore,
        fillPosition,
        includeTail,
      );
    }
    return this.dataAdapter.buildGridItemsForColumns(
      windowState.sections,
      columns,
      0,
      this.hasMore,
      fillPosition,
      includeTail,
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

  private resolveSourceGroupsForForm(
    form: FormIndex,
    sections: Array<PhotoSection> = this.sections,
  ): Array<GroupInfo> {
    if (form !== FormIndex.GROUP_DAY) {
      return [];
    }
    if (this.groupDayGroups.length > 0) {
      return this.groupDayGroups.slice();
    }

    return this.deriveGroupsForSections(sections, this.windowStartOffset);
  }

  private buildCanonicalGroupWindowGroups(
    sections: Array<PhotoSection>,
    windowStartOffset: number,
    sourceGroups: Array<GroupInfo> = [],
  ): Array<GroupInfo> {
    const canonicalGroups = this.deriveGroupsForSections(sections, windowStartOffset);
    this.validateCanonicalGroupWindowGroups(canonicalGroups, sections, windowStartOffset, sourceGroups);
    return canonicalGroups;
  }

  private deriveGroupsForSections(sections: Array<PhotoSection>, startOffset: number): Array<GroupInfo> {
    const derivedGroups: Array<GroupInfo> = [];
    let runningOffset = Math.max(0, startOffset);
    sections.forEach((section: PhotoSection) => {
      const count = this.dataAdapter.flattenAssets([section]).length;
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
    sourceGroups: Array<GroupInfo>,
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
      const sectionCount = this.dataAdapter.flattenAssets([section]).length;
      if (!group) {
        console.warn(`[TimelineDataManager] GROUP_DAY canonical group missing at index=${index}`);
        return;
      }
      if (index === 0 && group.offset !== normalizedWindowStartOffset) {
        console.warn(
          `[TimelineDataManager] GROUP_DAY first group offset mismatch: expected=${normalizedWindowStartOffset}, actual=${group.offset}`,
        );
        return;
      }
      if (group.count !== sectionCount) {
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
      expectedOffset += sectionCount;
    }

    if (sourceGroups.length > 0) {
      this.validateSourceAlignedGroups(canonicalGroups, sourceGroups);
    }
  }

  private validateSourceAlignedGroups(
    canonicalGroups: Array<GroupInfo>,
    sourceGroups: Array<GroupInfo>,
  ): void {
    if (canonicalGroups.length !== sourceGroups.length) {
      console.warn(
        `[TimelineDataManager] GROUP_DAY source group size mismatch: canonical=${canonicalGroups.length}, source=${sourceGroups.length}`,
      );
      return;
    }

    for (let index = 0; index < canonicalGroups.length; index += 1) {
      const canonicalGroup = canonicalGroups[index];
      const sourceGroup = sourceGroups[index];
      if (
        canonicalGroup.offset !== sourceGroup.offset ||
        canonicalGroup.count !== sourceGroup.count ||
        canonicalGroup.key !== sourceGroup.key ||
        canonicalGroup.title !== sourceGroup.title
      ) {
        console.warn(
          `[TimelineDataManager] GROUP_DAY source alignment mismatch at index=${index}: ` +
          `canonical={key:${canonicalGroup.key},offset:${canonicalGroup.offset},count:${canonicalGroup.count}} ` +
          `source={key:${sourceGroup.key},offset:${sourceGroup.offset},count:${sourceGroup.count}}`,
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

    const assets = this.dataAdapter.flattenAssets(this.sections);
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
    columns: number,
    hasMore: boolean,
    fillPosition: number,
    includeTail: boolean,
  ): Array<GridItem> {
    const items: Array<GridItem> = [];
    const safeFillPosition = Math.max(0, fillPosition);
    for (let index = 0; index < safeFillPosition; index += 1) {
      items.push({
        id: `placeholder_${columns}_${safeFillPosition}_${index}`,
        kind: 'placeholder',
        sectionKey: '',
      });
    }

    let runningSourceIndex = 0;
    sections.forEach((section: PhotoSection, sectionIndex: number) => {
      const group = groups[sectionIndex];
      const sectionAssets = this.dataAdapter.flattenAssets([section]);
      if (sectionAssets.length <= 0) {
        return;
      }

      items.push({
        id: `group_header_${section.key}_${sectionIndex}`,
        kind: 'groupHeader',
        headerText: section.title,
        headerCount: group?.count ?? sectionAssets.length,
        sectionKey: section.key,
      });

      sectionAssets.forEach((asset: PhotoAsset, assetIndex: number) => {
        const sourceIndex = group?.offset !== undefined
          ? group.offset + assetIndex
          : runningSourceIndex;
        items.push({
          id: `photo_${sourceIndex}_${asset.id}`,
          kind: 'photo',
          asset: asset,
          sectionKey: section.key,
          sourceIndex: sourceIndex,
        });
        runningSourceIndex += 1;
      });
    });

    if (includeTail && hasMore) {
      const tailCount = Math.max(1, columns);
      for (let index = 0; index < tailCount; index += 1) {
        items.push({
          id: `tail_${columns}_${index}`,
          kind: 'tail',
          sectionKey: '',
        });
      }
    }

    return items;
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
  ): Array<PhotoSection> {
    if (sections.length <= 0 || endLocalPhotoIndexExclusive <= startLocalPhotoIndex) {
      return [];
    }

    const slicedSections: Array<PhotoSection> = [];
    let currentPhotoOffset = 0;
    sections.forEach((section: PhotoSection) => {
      const sectionAssets = this.dataAdapter.flattenAssets([section]);
      const sectionPhotoCount = sectionAssets.length;
      const sectionStartOffset = currentPhotoOffset;
      const sectionEndOffset = sectionStartOffset + sectionPhotoCount;
      currentPhotoOffset = sectionEndOffset;
      if (sectionPhotoCount <= 0 || startLocalPhotoIndex >= sectionEndOffset || endLocalPhotoIndexExclusive <= sectionStartOffset) {
        return;
      }

      const localStartOffset = Math.max(0, startLocalPhotoIndex - sectionStartOffset);
      const localEndOffset = Math.min(sectionPhotoCount, endLocalPhotoIndexExclusive - sectionStartOffset);
      const slicedAssets = sectionAssets.slice(localStartOffset, localEndOffset);
      if (slicedAssets.length <= 0) {
        return;
      }

      slicedSections.push({
        key: section.key,
        title: section.title,
        rows: this.chunkAssets(slicedAssets, Math.max(1, columns)),
      });
    });
    return slicedSections;
  }

  private sliceGroupsByPhotoRange(
    groups: Array<GroupInfo>,
    windowStartOffset: number,
    startLocalPhotoIndex: number,
    endLocalPhotoIndexExclusive: number,
  ): Array<GroupInfo> {
    if (groups.length <= 0 || endLocalPhotoIndexExclusive <= startLocalPhotoIndex) {
      return [];
    }

    const startPhotoOffset = windowStartOffset + startLocalPhotoIndex;
    const endPhotoOffsetExclusive = windowStartOffset + endLocalPhotoIndexExclusive;
    const slicedGroups: Array<GroupInfo> = [];
    groups.forEach((group: GroupInfo) => {
      const groupStartOffset = group.offset;
      const groupEndOffsetExclusive = group.offset + Math.max(0, group.count);
      if (startPhotoOffset >= groupEndOffsetExclusive || endPhotoOffsetExclusive <= groupStartOffset) {
        return;
      }

      const slicedStartOffset = Math.max(startPhotoOffset, groupStartOffset);
      const slicedEndOffsetExclusive = Math.min(endPhotoOffsetExclusive, groupEndOffsetExclusive);
      slicedGroups.push({
        key: group.key,
        title: group.title,
        count: Math.max(0, slicedEndOffsetExclusive - slicedStartOffset),
        offset: slicedStartOffset,
      });
    });
    return slicedGroups;
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
