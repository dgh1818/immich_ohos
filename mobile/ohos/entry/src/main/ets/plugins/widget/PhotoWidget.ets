import { WidgetState } from './model/Model';

class WidgetStorage {
  text: string = '';
  loaded: boolean = false;
  imgName: string = '';
  deeplink: string = 'immich://';
  state: WidgetState = WidgetState.LOADING;
}

const storage = new LocalStorage(new WidgetStorage());

@Entry(storage)
@Component
struct PhotoWidget {
  @Watch('onDataChange')
  @LocalStorageProp('state') state: WidgetState = WidgetState.LOADING;
  @Watch('onDataChange')
  @LocalStorageProp('imgName') imgName: string = '';
  @LocalStorageProp('text') text: string = '';
  @LocalStorageProp('loaded') loaded: boolean = false;
  @LocalStorageProp('deeplink') deeplink: string = 'immich://';

  aboutToAppear() {
    this.logFormData('aboutToAppear');
  }

  private onDataChange(): void {
    this.logFormData('onDataChange');
  }

  private logFormData(source: string): void {
    console.error(
      `[PhotoWidget] ${source} state=${this.state} loaded=${this.loaded} imgName=${this.imgName} text=${this.text} deeplink=${this.deeplink}`,
    );
  }

  build() {
    Stack() {
      if (this.state === WidgetState.SUCCESS && this.loaded && this.imgName) {
        Image(`memory://${this.imgName}`)
          .objectFit(ImageFit.Cover)
          .width('100%')
          .height('100%');

        if (this.text) {
          Column() {
            Text(this.text)
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
          } else {
            Row() {
              Text('Loading widget...')
                .fontSize(14)
                .fontColor(0xFF8A8A8A);
            }
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
