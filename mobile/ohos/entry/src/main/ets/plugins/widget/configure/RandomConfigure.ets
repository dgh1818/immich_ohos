import { common } from '@kit.AbilityKit';

import { ImmichAPI } from '../ImmichAPI';
import {
  DEFAULT_ALBUM_ID,
  DEFAULT_ALBUM_NAME,
  DEFAULT_REFRESH_MINUTES,
  DEFAULT_SLIDE_INTERVAL_SECONDS,
  FAVORITES_ALBUM_ID,
  FORM_NAME_MEMORIES,
  WidgetConfig,
  WidgetConfigState,
  WidgetType,
  markWidgetAlbumOverride,
  loadServerConfig,
  loadWidgetConfig,
  saveWidgetConfig,
} from '../model/Model';
import { updateWidgetForm } from '../ImageDownloadWorker';

import { Dropdown, DropdownItem } from './Dropdown';

@Entry
@Component
export struct RandomConfigure {
  private context = getContext(this) as common.UIAbilityContext;

  @StorageProp('widgetConfigFormId') formId: string = '';
  @StorageProp('widgetConfigFormName') formName: string = '';

  @State configState: WidgetConfigState = WidgetConfigState.LOADING;
  @State albumItems: Array<DropdownItem> = [];
  @State selectedAlbumId: string = DEFAULT_ALBUM_ID;
  @State selectedAlbumName: string = DEFAULT_ALBUM_NAME;
  @State showAlbumName: boolean = false;
  @State slideItems: Array<DropdownItem> = [];
  @State selectedSlideId: string = DEFAULT_SLIDE_INTERVAL_SECONDS.toString();
  @State selectedSlideLabel: string = `${DEFAULT_SLIDE_INTERVAL_SECONDS} sec`;

  aboutToAppear() {
    console.error(`[WidgetConfig] aboutToAppear formId=${this.formId} formName=${this.formName}`);
    this.loadConfig();
  }

  private isRandomWidget(): boolean {
    return this.formName !== FORM_NAME_MEMORIES;
  }

  private resolveWidgetType(): WidgetType {
    return this.formName === FORM_NAME_MEMORIES ? WidgetType.MEMORIES : WidgetType.RANDOM;
  }

  private buildItem(label: string, id: string): DropdownItem {
    const item: DropdownItem = { label, id };
    return item;
  }

  private buildSlideItems(): Array<DropdownItem> {
    return [
      this.buildItem('5 sec', '5'),
      this.buildItem('15 sec', '15'),
      this.buildItem('30 sec', '30'),
      this.buildItem('45 sec', '45'),
      this.buildItem('60 sec', '60'),
      this.buildItem('2 min', '120'),
      this.buildItem('3 min', '180'),
      this.buildItem('5 min', '300'),
      this.buildItem('10 min', '600'),
      this.buildItem('15 min', '900'),
      this.buildItem('20 min', '1200'),
      this.buildItem('30 min', '1800'),
    ];
  }

  private async loadConfig(): Promise<void> {
    console.error(
      `[WidgetConfig] loadConfig start formId=${this.formId} formName=${this.formName} isRandom=${this.isRandomWidget()}`
    );
    const stored = loadWidgetConfig(this.context, this.formId);
    this.selectedAlbumId = stored.albumId;
    this.selectedAlbumName = stored.albumName;
    this.showAlbumName = stored.showAlbumName;
    this.selectedSlideId = stored.slideIntervalSeconds.toString();
    this.selectedSlideLabel = `${stored.slideIntervalSeconds} sec`;
    console.error(
      `[WidgetConfig] stored config albumId=${stored.albumId} albumName=${stored.albumName} show=${stored.showAlbumName} slide=${stored.slideIntervalSeconds}`
    );
    this.slideItems = this.buildSlideItems();
    this.syncSlideSelection();

    const serverConfig = loadServerConfig(this.context);
    if (!serverConfig) {
      this.configState = WidgetConfigState.LOG_IN;
      console.error('[WidgetConfig] serverConfig missing');
      return;
    }
    console.error(
      `[WidgetConfig] serverConfig ok endpoint=${serverConfig.serverEndpoint} tokenLen=${serverConfig.sessionKey.length}`
    );

    if (!this.isRandomWidget()) {
      this.configState = WidgetConfigState.SUCCESS;
      console.error('[WidgetConfig] skip album fetch for non-random widget');
      return;
    }

    let items: Array<DropdownItem> = [];
    let nextState = WidgetConfigState.SUCCESS;
    try {
      const api = new ImmichAPI(serverConfig);
      const albums = await api.fetchAlbums();
      console.error(`[WidgetConfig] fetched albums count=${albums.length}`);
      const albumItems = albums.map((album): DropdownItem => this.buildItem(album.albumName, album.id));
      items = [
        this.buildItem(DEFAULT_ALBUM_NAME, DEFAULT_ALBUM_ID),
        this.buildItem('Favorites', FAVORITES_ALBUM_ID),
        ...albumItems,
      ];
    } catch (err) {
      console.error(`[WidgetConfig] failed to fetch albums: ${err}`);
      nextState = WidgetConfigState.NO_CONNECTION;
      items = [
        this.buildItem(
          this.selectedAlbumName || DEFAULT_ALBUM_NAME,
          this.selectedAlbumId || DEFAULT_ALBUM_ID,
        ),
      ];
    }

    this.albumItems = items;
    console.error(`[WidgetConfig] albumItems count=${items.length}`);
    this.syncSelection();
    console.error(
      `[WidgetConfig] selected albumId=${this.selectedAlbumId} albumName=${this.selectedAlbumName}`
    );
    this.configState = nextState;
    console.error(`[WidgetConfig] configState=${this.configState}`);
  }

  private syncSelection(): void {
    if (this.albumItems.length === 0) {
      console.error('[WidgetConfig] syncSelection skipped: no items');
      return;
    }
    const selected = this.albumItems.find((item) => item.id === this.selectedAlbumId);
    if (selected) {
      this.selectedAlbumName = selected.label;
    } else {
      this.selectedAlbumId = this.albumItems[0].id;
      this.selectedAlbumName = this.albumItems[0].label;
    }
    console.error(
      `[WidgetConfig] syncSelection result albumId=${this.selectedAlbumId} albumName=${this.selectedAlbumName}`
    );
  }

  private syncSlideSelection(): void {
    if (this.slideItems.length === 0) {
      console.error('[WidgetConfig] syncSlideSelection skipped: no items');
      return;
    }
    const selected = this.slideItems.find((item) => item.id === this.selectedSlideId);
    if (selected) {
      this.selectedSlideLabel = selected.label;
    } else {
      this.selectedSlideId = this.slideItems[0].id;
      this.selectedSlideLabel = this.slideItems[0].label;
    }
    console.error(
      `[WidgetConfig] syncSlideSelection result slideId=${this.selectedSlideId} slideLabel=${this.selectedSlideLabel}`
    );
  }

  private saveAndClose(): void {
    console.error(
      `[WidgetConfig] saveAndClose formId=${this.formId} isRandom=${this.isRandomWidget()}`
    );
    if (this.formId) {
      const parsedSlideInterval = parseInt(this.selectedSlideId, 10);
      const slideIntervalSeconds =
        parsedSlideInterval > 0 ? parsedSlideInterval : DEFAULT_SLIDE_INTERVAL_SECONDS;
      const config: WidgetConfig = {
        albumId: this.selectedAlbumId,
        albumName: this.selectedAlbumName,
        showAlbumName: this.showAlbumName,
        refreshMinutes: DEFAULT_REFRESH_MINUTES,
        slideIntervalSeconds,
      };
      console.error(
        `[WidgetConfig] saving config albumId=${config.albumId} albumName=${config.albumName} show=${config.showAlbumName} slide=${config.slideIntervalSeconds}`
      );
      saveWidgetConfig(this.context, this.formId, config);
      markWidgetAlbumOverride(this.context, this.formId);
      console.error('[WidgetConfig] saveWidgetConfig done');
      updateWidgetForm(this.context, this.formId, this.resolveWidgetType()).catch(() => {});
    } else {
      console.error('[WidgetConfig] skip save: missing formId');
    }
    this.context.terminateSelf();
  }

  build() {
    Column() {
      Row() {
        Text('服务卡片设置')
          .fontSize(22)
          .fontColor(0xFF1F1F1F)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(0.5);
        Button(this.isRandomWidget() ? '保存' : '完成')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .onClick(() => this.saveAndClose());
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20, top: 16, bottom: 12 });

      if (this.configState === WidgetConfigState.LOADING) {
        Column() {
          Text('加载配置中...')
            .fontSize(14)
            .fontColor(0xFF8A8A8A)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Center);
      } else if (this.configState === WidgetConfigState.LOG_IN) {
        Column() {
          Text('需要登录')
            .fontSize(14)
            .fontColor(0xFF8A8A8A)
            .textAlign(TextAlign.Center);
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Center);
      } else {
        Column() {
          if (this.isRandomWidget()) {
            Text('选择一个待展示随机相册')
              .fontSize(14)
              .fontColor(0xFF6A6A6A)
              .margin({ bottom: 8 })
              .width('100%')
              .textAlign(TextAlign.Start);
          }

          if (this.isRandomWidget() && this.configState === WidgetConfigState.NO_CONNECTION) {
            Column() {
              Text('服务器未连接')
                .fontSize(14)
                .fontColor(0xFFB3261E)
                .textAlign(TextAlign.Center);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(0xFFFCE8E8)
            .border({ width: 1, color: 0xFFF2B8B5 })
            .borderRadius(10);
          }

          Column() {
            if (this.isRandomWidget()) {
              Text('相册')
                .fontSize(12)
                .fontColor(0xFF555555)
                .fontWeight(FontWeight.Medium)
                .letterSpacing(0.6)
                .padding({ bottom: 6 })
                .width('100%')
                .textAlign(TextAlign.Start);
              Dropdown({
                items: this.albumItems,
                selectedId: $selectedAlbumId,
                selectedLabel: $selectedAlbumName,
                isEnabled: this.configState !== WidgetConfigState.NO_CONNECTION,
              });

              Row() {
                Text('显示相册名字')
                  .fontSize(14)
                  .fontColor(0xFF444444)
                  .fontWeight(FontWeight.Medium);
                Toggle({ type: ToggleType.Switch, isOn: this.showAlbumName })
                  .onChange((value: boolean) => {
                    this.showAlbumName = value;
                  })
                  .enabled(this.configState !== WidgetConfigState.NO_CONNECTION);
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .alignItems(VerticalAlign.Center)
              .width('100%')
              .padding({ top: 8 });
            }

            Text('滑动间隔')
              .fontSize(12)
              .fontColor(0xFF555555)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(0.6)
              .padding({ top: 16 })
              .width('100%')
              .textAlign(TextAlign.Start);
            Dropdown({
              items: this.slideItems,
              selectedId: $selectedSlideId,
              selectedLabel: $selectedSlideLabel,
              isEnabled: true,
            });
          }
          .padding(16)
          .backgroundColor(0xFFF9F9FB)
          .border({ width: 1, color: 0xFFE6E6E8 })
          .borderRadius(12);
        }
        .padding(16)
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(0xFFF7F7FA);
  }
}
