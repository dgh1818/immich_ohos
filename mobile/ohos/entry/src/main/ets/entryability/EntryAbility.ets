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
import { LocalImageApiOhos } from '../../../main/ets/plugins/Images/LocalImages.g';
import { RemoteImageApiOhos } from '../../../main/ets/plugins/Images/RemoteImages.g';
import {MessagesImplBase} from '../plugins/sync/MessagesImplBase'
import { LocalImagesImpl } from '../plugins/Images/LocalImagesImpl';
import { RemoteImagesImpl } from '../plugins/Images/RemoteImagesImpl';
import { BackgroundWorkerApiImpl } from '../WorkSchedulerExtension/BackgroundWorkerApiImpl';
import { BackgroundWorkerFgHostApi } from '../WorkSchedulerExtension/BackgroundWorker.g';
import { ConnectivityApi } from '../plugins/connectivity/Connectivity.g';
import { ConnectivityApiImpl } from '../plugins/connectivity/ConnectivityApiImpl';
import { MediaObserverScheduler } from '../WorkSchedulerExtension/MediaObserverScheduler';
import { workScheduler } from '@kit.BackgroundTasksKit';
import BackgroundEngineLock from '../plugins/Background/BackgroundEngineLock';
import { BackgroundWorkerLockApi } from '../plugins/Background/BackgroundWorkerLock.g';
import ImmichPlugin from '../plugins/core/ImmichPlugin';
import HomeWidgetPlugin from '../plugins/widget/HomeWidgetPlugin';
import { AbilityConstant, Want } from '@kit.AbilityKit';
import { NetworkApi } from '../plugins/core/Network.g';
import { NetworkApiImpl } from '../plugins/core/NetworkApiImpl';
import { PermissionApi } from '../plugins/permission/PermissionApi.g';
import { PermissionApiImpl } from '../plugins/permission/PermissionApiImpl';
import { ViewIntentHostApi } from '../plugins/viewintent/ViewIntent.g';
import { ViewIntentApiImpl } from '../plugins/viewintent/ViewIntentApiImpl';

export default class EntryAbility extends FlutterAbility {
  private pendingDeepLink: string | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onCreate(want, launchParam);
    this.handleWidgetRouter(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    this.handleWidgetRouter(want);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    this.registerPlugins(super.getAbility().context,flutterEngine);
    this.dispatchPendingDeepLink();
  }

  public registerPlugins(ctx: Context, flutterEngine: FlutterEngine){
    this.addPlugin(new BackgroundServicePlugin()); // 加载插件
    this.addPlugin(new HomeWidgetPlugin());
    
    //this.addPlugin(new HttpSSLOptionsPlugin());

    let nativeSyncApiImpl = new MessagesImplBase(super.getAbility().context);
    let localImageApiImpl = new LocalImagesImpl(super.getAbility().context);
    let remoteImageApiImpl = new RemoteImagesImpl(ctx.getApplicationContext());
    let backgroundWorkerApiImpl = new BackgroundWorkerApiImpl(ctx.getApplicationContext());
    let connectivityApiImpl = new ConnectivityApiImpl(ctx.getApplicationContext());
    let backgroundEngineLock = new BackgroundEngineLock(ctx.getApplicationContext())
    let networkApiImpl = new NetworkApiImpl(super.getAbility().context);
    let permissionApiImpl = new PermissionApiImpl(super.getAbility().context);
    let viewIntentApiImpl = new ViewIntentApiImpl();
    let messenger = flutterEngine.dartExecutor.getBinaryMessenger();
    NativeSyncApiOhos.setup(messenger, nativeSyncApiImpl)
    LocalImageApiOhos.setup(messenger, localImageApiImpl);
    RemoteImageApiOhos.setup(messenger, remoteImageApiImpl);
    BackgroundWorkerFgHostApi.setup(messenger,backgroundWorkerApiImpl);
    ConnectivityApi.setup(messenger,connectivityApiImpl);
    BackgroundWorkerLockApi.setup(messenger,backgroundEngineLock);
    NetworkApi.setup(messenger, networkApiImpl);
    PermissionApi.setup(messenger, permissionApiImpl);
    ViewIntentHostApi.setup(messenger, viewIntentApiImpl);

    const constraints: workScheduler.WorkInfo = BackgroundWorkerApiImpl.BACKGROUND_WORKER_INFO;
    try {
      workScheduler.startWork(constraints);
    } catch (e) {

    }

    console.info("MediaObserverScheduler", "Enqueued background worker");
  }

  private handleWidgetRouter(want: Want): void {
    const rawParams = want?.parameters?.params as string | undefined;
    if (!rawParams) {
      return;
    }
    try {
      const params = JSON.parse(rawParams) as Record<string, string>;
      const deeplink = params?.deeplink ?? '';
      if (!deeplink) {
        return;
      }
      this.pendingDeepLink = deeplink;
      this.dispatchPendingDeepLink();
    } catch (error) {
      console.error(`[EntryAbility] parse widget params failed: ${error}`);
    }
  }

  private dispatchPendingDeepLink(): void {
    if (!this.pendingDeepLink) {
      return;
    }
    const engine = this.getFlutterEngine();
    const nav = engine?.getNavigationChannel();
    if (!nav) {
      return;
    }
    nav.pushRouteInformation(this.pendingDeepLink);
    this.pendingDeepLink = null;
  }
}
