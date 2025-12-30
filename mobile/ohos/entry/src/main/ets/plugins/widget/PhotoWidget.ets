import { DEFAULT_SLIDE_INTERVAL_SECONDS, WidgetImageEntry, WidgetState } from './model/Model';

class WidgetStorage {
  text: string = '';
  loaded: boolean = false;
  imgName: string = '';
  deeplink: string = 'immich://';
  entriesJson: string = '[]';
  activeIndex: number = 0;
  slideIntervalSeconds: number = DEFAULT_SLIDE_INTERVAL_SECONDS;
  state: WidgetState = WidgetState.LOADING;
}

const storage = new LocalStorage(new WidgetStorage());

@Entry(storage)
@Component
struct PhotoWidget {
  @Watch('onDataChange')
  @LocalStorageProp('state') state: WidgetState = WidgetState.LOADING;
  @Watch('onEntriesChange')
  @LocalStorageProp('entriesJson') entriesJson: string = '[]';
  @Watch('onDataChange')
  @LocalStorageProp('imgName') imgName: string = '';
  @LocalStorageProp('formImages') formImages: Record<string, number> = {};
  @LocalStorageProp('text') text: string = '';
  @LocalStorageProp('loaded') loaded: boolean = false;
  @LocalStorageProp('deeplink') deeplink: string = 'immich://';
  @LocalStorageProp('activeIndex') activeIndex: number = 0;
  @LocalStorageProp('slideIntervalSeconds') slideIntervalSeconds: number = DEFAULT_SLIDE_INTERVAL_SECONDS;

  @State lastLoadMoreImgName: string = '';

  aboutToAppear() {
    this.logFormData('aboutToAppear');
    this.syncActiveIndex();
  }

  private onDataChange(): void {
    this.logFormData('onDataChange');
  }

  private onEntriesChange(): void {
    this.logFormData('onEntriesChange');
    this.syncActiveIndex();
    const entry = this.resolveEntryAtIndex(this.activeIndex);
    if (entry && this.activeIndex >= this.resolveEntries().length - 2) {
      this.lastLoadMoreImgName = entry.imgName;
    } else {
      this.lastLoadMoreImgName = '';
    }
  }

  private logFormData(source: string): void {
    console.error(
      `[PhotoWidget] ${source} state=${this.state} loaded=${this.loaded} imgName=${this.imgName} text=${this.text} deeplink=${this.deeplink} entriesLen=${this.entriesJson?.length ?? 0} activeIndex=${this.activeIndex} slideInterval=${this.slideIntervalSeconds}`,
    );
  }

  private parseEntriesJson(raw: string): Array<WidgetImageEntry> {
    if (!raw) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as Array<WidgetImageEntry>;
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed.filter(
        (entry) => !!entry && typeof entry.imgName === 'string' && entry.imgName.length > 0,
      );
    } catch (_) {
      return [];
    }
  }

  private resolveEntries(): Array<WidgetImageEntry> {
    const parsed = this.parseEntriesJson(this.entriesJson);
    if (parsed.length > 0) {
      return parsed;
    }
    const formImageNames = this.resolveFormImageNames();
    if (formImageNames.length > 0) {
      return formImageNames.map((imgName) => this.buildEntry(imgName));
    }
    if (this.imgName) {
      return [this.buildEntry(this.imgName)];
    }
    return [];
  }

  private buildEntry(imgName: string): WidgetImageEntry {
    const entry: WidgetImageEntry = {
      imgName,
      text: this.text,
      deeplink: this.deeplink,
    };
    return entry;
  }

  private resolveFormImageNames(): Array<string> {
    const names = Object.keys(this.formImages);
    if (names.length <= 1) {
      return names;
    }
    return names.slice().sort((a, b) => {
      const aIndex = this.parseImageIndex(a);
      const bIndex = this.parseImageIndex(b);
      if (aIndex !== null && bIndex !== null) {
        return aIndex - bIndex;
      }
      return a.localeCompare(b);
    });
  }

  private parseImageIndex(imgName: string): number | null {
    const lastUnderscore = imgName.lastIndexOf('_');
    if (lastUnderscore < 0) {
      return null;
    }
    const raw = imgName.substring(lastUnderscore + 1);
    const parsed = parseInt(raw, 10);
    if (!Number.isFinite(parsed)) {
      return null;
    }
    return parsed;
  }

  private resolvePreloadEntries(): Array<WidgetImageEntry> {
    const entries = this.resolveEntries();
    if (entries.length === 0) {
      return [];
    }
    const currentIndex = this.activeIndex;
    const result: Array<WidgetImageEntry> = [];
    const current = entries[currentIndex];
    if (current) {
      result.push(current);
    }
    const prevIndex = currentIndex - 1;
    if (prevIndex >= 0) {
      result.push(entries[prevIndex]);
    }
    const nextIndex = currentIndex + 1;
    if (nextIndex < entries.length) {
      result.push(entries[nextIndex]);
    }
    return result;
  }

  private syncActiveIndex(): void {
    const entries = this.resolveEntries();
    if (entries.length === 0) {
      this.activeIndex = 0;
      return;
    }
    if (this.activeIndex >= entries.length) {
      this.activeIndex = 0;
    }
  }

  private resolveEntryAtIndex(index: number): WidgetImageEntry | null {
    const entries = this.resolveEntries();
    if (entries.length === 0) {
      return null;
    }
    if (index < 0 || index >= entries.length) {
      return null;
    }
    return entries[index];
  }

  private notifyIndexChange(index: number): void {
    const entries = this.resolveEntries();
    if (entries.length === 0) {
      return;
    }
    const entry = this.resolveEntryAtIndex(index);
    if (!entry) {
      return;
    }
    const shouldLoadMore = index >= entries.length - 2;
    const loadMore = shouldLoadMore && entry.imgName !== this.lastLoadMoreImgName;
    if (loadMore) {
      this.lastLoadMoreImgName = entry.imgName;
    }
    postCardAction(this, {
      action: 'message',
      params: {
        event: 'index_change',
        index,
        imgName: entry.imgName,
        loadMore,
      },
    });
  }

  private isReady(): boolean {
    return this.state === WidgetState.SUCCESS && this.loaded && this.resolveEntries().length > 0;
  }

  private resolveEntryText(entry: WidgetImageEntry): string {
    if (entry.text) {
      return entry.text;
    }
    return this.text;
  }

  private resolveEntryDeeplink(entry: WidgetImageEntry): string {
    if (entry.deeplink) {
      return entry.deeplink;
    }
    return this.deeplink;
  }

  private handlePhotoClick(deeplink: string): void {
    if (!deeplink) {
      return;
    }
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { deeplink },
    });
  }

  build() {
    Stack() {
      if (this.isReady()) {
        Swiper() {
          ForEach(
            this.resolveEntries(),
            (entry: WidgetImageEntry, _index: number) => {
              Stack() {
                Image(`memory://${entry.imgName}`)
                  .objectFit(ImageFit.Cover)
                  .syncLoad(true)
                  .width('100%')
                  .height('100%');

                if (this.resolveEntryText(entry)) {
                  Column() {
                    Text(this.resolveEntryText(entry))
                      .fontSize(16)
                      .fontColor(Color.White)
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(0x99000000)
                      .borderRadius(8);
                  }
                  .width('100%')
                  .height('100%')
                  .justifyContent(FlexAlign.End)
                  .alignItems(HorizontalAlign.Start)
                  .padding(12);
                }
              }
              .width('100%')
              .height('100%')
              .backgroundColor(0xFF000000)
              .onClick(() => {
                this.handlePhotoClick(this.resolveEntryDeeplink(entry));
              });
            },
            (entry: WidgetImageEntry) => entry.imgName,
          );
        }
        .width('100%')
        .height('100%')
        .autoPlay(this.resolveEntries().length > 1)
        .interval(Math.max(1, this.slideIntervalSeconds) * 1000)
        .indicator(false)
        .loop(true)
        .disableSwipe(this.resolveEntries().length <= 1)
        .index(this.activeIndex)
        .onChange((index: number) => {
          this.activeIndex = index;
          this.notifyIndexChange(index);
        });

        Column() {
          ForEach(
            this.resolvePreloadEntries(),
            (entry: WidgetImageEntry, _index: number) => {
              Image(`memory://${entry.imgName}`)
                .syncLoad(true)
                .width(1)
                .height(1)
                .opacity(0);
            },
            (entry: WidgetImageEntry) => `preload_${entry.imgName}`,
          );
        }
        .width(1)
        .height(1)
        .opacity(0);
      } else {
        Column() {
          Image($r('app.media.app_icon'))
            .width(48)
            .height(48);

          if (this.state === WidgetState.LOG_IN) {
            Text('Log in to your Immich server')
              .fontSize(14)
              .fontColor(0xFF8A8A8A)
              .textAlign(TextAlign.Center)
              .padding(12);
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center);
      }
    }
    .width('100%')
    .height('100%');
  }
}
