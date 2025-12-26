import { common } from '@kit.AbilityKit';

import { ImmichAPI } from '../ImmichAPI';
import {
  DEFAULT_ALBUM_ID,
  DEFAULT_ALBUM_NAME,
  DEFAULT_REFRESH_MINUTES,
  FAVORITES_ALBUM_ID,
  FORM_NAME_MEMORIES,
  WidgetConfig,
  WidgetConfigState,
  WidgetType,
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
  @State refreshItems: Array<DropdownItem> = [];
  @State selectedRefreshId: string = DEFAULT_REFRESH_MINUTES.toString();
  @State selectedRefreshLabel: string = `${DEFAULT_REFRESH_MINUTES} min`;

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

  private buildRefreshItems(): Array<DropdownItem> {
    return [
      this.buildItem('5 min', '5'),
      this.buildItem('15 min', '15'),
      this.buildItem('20 min', '20'),
      this.buildItem('30 min', '30'),
      this.buildItem('60 min', '60'),
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
    this.selectedRefreshId = stored.refreshMinutes.toString();
    this.selectedRefreshLabel = `${stored.refreshMinutes} min`;
    console.error(
      `[WidgetConfig] stored config albumId=${stored.albumId} albumName=${stored.albumName} show=${stored.showAlbumName} refresh=${stored.refreshMinutes}`
    );
    this.refreshItems = this.buildRefreshItems();
    this.syncRefreshSelection();

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

  private syncRefreshSelection(): void {
    if (this.refreshItems.length === 0) {
      console.error('[WidgetConfig] syncRefreshSelection skipped: no items');
      return;
    }
    const selected = this.refreshItems.find((item) => item.id === this.selectedRefreshId);
    if (selected) {
      this.selectedRefreshLabel = selected.label;
    } else {
      this.selectedRefreshId = this.refreshItems[0].id;
      this.selectedRefreshLabel = this.refreshItems[0].label;
    }
    console.error(
      `[WidgetConfig] syncRefreshSelection result refreshId=${this.selectedRefreshId} refreshLabel=${this.selectedRefreshLabel}`
    );
  }

  private saveAndClose(): void {
    console.error(
      `[WidgetConfig] saveAndClose formId=${this.formId} isRandom=${this.isRandomWidget()}`
    );
    if (this.formId) {
      const parsedRefresh = parseInt(this.selectedRefreshId, 10);
      const refreshMinutes =
        parsedRefresh > 0 ? parsedRefresh : DEFAULT_REFRESH_MINUTES;
      const config: WidgetConfig = {
        albumId: this.selectedAlbumId,
        albumName: this.selectedAlbumName,
        showAlbumName: this.showAlbumName,
        refreshMinutes,
      };
      console.error(
        `[WidgetConfig] saving config albumId=${config.albumId} albumName=${config.albumName} show=${config.showAlbumName} refresh=${config.refreshMinutes}`
      );
      saveWidgetConfig(this.context, this.formId, config);
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
        Text('Widget Configuration')
          .fontSize(18)
          .fontColor(0xFF222222)
          .fontWeight(FontWeight.Medium);
        Button(this.isRandomWidget() ? '保存' : '完成')
          .onClick(() => this.saveAndClose());
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 });

      if (this.configState === WidgetConfigState.LOADING) {
        Column() {
          Text('加载配置中...')
            .fontSize(14)
            .fontColor(0xFF8A8A8A);
        }
        .width('100%')
        .padding(16);
      } else if (this.configState === WidgetConfigState.LOG_IN) {
        Column() {
          Text('需要登录')
            .fontSize(14)
            .fontColor(0xFF8A8A8A);
        }
        .width('100%')
        .padding(16);
      } else {
        Column() {
          if (this.isRandomWidget()) {
            Text('选择一个待展示随机相册')
              .fontSize(14)
              .fontColor(0xFF666666);
          } else {
            Text('刷新间隔')
              .fontSize(14)
              .fontColor(0xFF666666);
          }

          if (this.isRandomWidget() && this.configState === WidgetConfigState.NO_CONNECTION) {
            Column() {
              Text('No connection to the server is available. Please try again later.')
                .fontSize(14)
                .fontColor(0xFF8A1C1C);
            }
            .width('100%')
            .padding(12)
            .backgroundColor(0xFFFCE8E8)
            .borderRadius(8);
          }

          Column() {
            if (this.isRandomWidget()) {
              Text('Album')
                .fontSize(14)
                .fontColor(0xFF222222);
              Dropdown({
                items: this.albumItems,
                selectedId: $selectedAlbumId,
                selectedLabel: $selectedAlbumName,
                isEnabled: this.configState !== WidgetConfigState.NO_CONNECTION,
              });

              Row() {
                Text('Show Album Name')
                  .fontSize(14)
                  .fontColor(0xFF222222);
                Toggle({ type: ToggleType.Switch, isOn: this.showAlbumName })
                  .onChange((value: boolean) => {
                    this.showAlbumName = value;
                  })
                  .enabled(this.configState !== WidgetConfigState.NO_CONNECTION);
              }
              .justifyContent(FlexAlign.SpaceBetween)
              .width('100%')
              .padding({ top: 8 });
            }

            Text('Refresh Interval')
              .fontSize(14)
              .fontColor(0xFF222222)
              .padding({ top: 12 });
            Dropdown({
              items: this.refreshItems,
              selectedId: $selectedRefreshId,
              selectedLabel: $selectedRefreshLabel,
              isEnabled: true,
            });
          }
          .padding(12)
          .backgroundColor(0xFFF5F5F5)
          .borderRadius(8);
        }
        .padding(16)
        .width('100%')
        .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(0xFFFFFFFF);
  }
}
