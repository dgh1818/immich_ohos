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

import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import { BackgroundServicePlugin } from '../../../main/ets/plugins/BackgroundServicePlugin';
import { NativeSyncApiOhos } from '../../../main/ets/plugins/sync/Messages_ohos.g';
import {MessagesImplBase} from '../plugins/sync/MessagesImplBase'

export default class EntryAbility extends FlutterAbility {
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    this.addPlugin(new BackgroundServicePlugin()); // 加载插件
    let nativeSyncApiImpl = new MessagesImplBase(super.getAbility().context);


    NativeSyncApiOhos.setup(flutterEngine.dartExecutor.getBinaryMessenger(), nativeSyncApiImpl)
  }
}
