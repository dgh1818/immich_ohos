/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import common from '@ohos.app.ability.common';
import { FlutterPage } from '@ohos/flutter_ohos'
import { HybridFlutterBridge } from '../bridge/HybridFlutterBridge';
import { PhotoGridPage } from './hybrid/PhotoGridPage';

let storage = LocalStorage.getShared()
const EVENT_BACK_PRESS = 'EVENT_BACK_PRESS'
const LAUNCH_MODE_LEGACY = 'legacy_flutter'
const LAUNCH_MODE_HYBRID = 'hybrid_arkui_photos'

@Entry(storage)
@Component
struct Index {
  private context = getContext(this) as common.UIAbilityContext
  @LocalStorageLink('viewId') viewId: string = "";
  @State launchMode: string = LAUNCH_MODE_LEGACY;
  @StorageLink('hybridSelectedPane') selectedPane: number = 0;

  aboutToAppear() {
    AppStorage.setOrCreate('hybridSelectedPane', 0);
    const launchMode = HybridFlutterBridge.getSavedLaunchMode();
    this.launchMode = launchMode === LAUNCH_MODE_HYBRID ? LAUNCH_MODE_HYBRID : LAUNCH_MODE_LEGACY;
    this.selectedPane = 0;
  }

  build() {
    Column() {
      if (this.launchMode === LAUNCH_MODE_HYBRID) {
        Stack({ alignContent: Alignment.TopStart }) {
          if (this.selectedPane === 0) {
            PhotoGridPage({ topInset: 76 })
              .width('100%')
              .height('100%');
          } else {
            FlutterPage({ viewId: this.viewId })
              .width('100%')
              .height('100%');
          }

          Row({ space: 4 }) {
            Button('Photos')
              .type(ButtonType.Capsule)
              .height(32)
              .padding({ left: 14, right: 14 })
              .backgroundColor(this.selectedPane === 0 ? 0xFF111827 : 0x00000000)
              .fontColor(this.selectedPane === 0 ? 0xFFFFFFFF : 0xFF111827)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.selectedPane = 0;
              });

            Button('Flutter')
              .type(ButtonType.Capsule)
              .height(32)
              .padding({ left: 14, right: 14 })
              .backgroundColor(this.selectedPane === 1 ? 0xFF111827 : 0x00000000)
              .fontColor(this.selectedPane === 1 ? 0xFFFFFFFF : 0xFF111827)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.selectedPane = 1;
              });
          }
          .padding(3)
          .backgroundColor(0xEAF8FAFC)
          .borderRadius(20)
          .margin({ left: 12, top: 20 });
        }
        .width('100%')
        .height('100%')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP]);
      } else {
        FlutterPage({ viewId: this.viewId })
          .layoutWeight(1);
      }
    }
    .width('100%')
    .height('100%')
  }

  onBackPress(): boolean {
    if (this.launchMode === LAUNCH_MODE_HYBRID && this.selectedPane === 0) {
      return false
    }
    this.context.eventHub.emit(EVENT_BACK_PRESS)
    return true
  }
}
