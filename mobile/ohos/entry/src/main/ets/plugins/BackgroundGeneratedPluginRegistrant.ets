import { FlutterEngine, Log } from '@ohos/flutter_ohos';
import PathProviderPlugin from 'path_provider_ohos';
import PhotoManagerPlugin from 'photo_manager';
import OhosHttpPlugin from 'ohos_http';
import NetworkInfoPlusOhosPlugin from 'network_info_plus_ohos';
import FlutterSecureStorageOhosPlugin from 'flutter_secure_storage_ohos';
import SharedPreferencesPlugin from 'shared_preferences_ohos';
import ConnectivityPlugin from 'connectivity_plus';
import BDPlugin from 'background_downloader';

const TAG = 'BackgroundGeneratedPluginRegistrant';

export class BackgroundGeneratedPluginRegistrant {
  static registerWith(flutterEngine: FlutterEngine) {
    try {
      // Keep the background engine limited to the plugins used by background sync.
      // Importing UI/video plugins here can crash workScheduler on HarmonyOS 6
      // because multimedia modules are blocklisted in that process.
      flutterEngine.getPlugins()?.add(new PathProviderPlugin());
      flutterEngine.getPlugins()?.add(new PhotoManagerPlugin());
      flutterEngine.getPlugins()?.add(new OhosHttpPlugin());
      flutterEngine.getPlugins()?.add(new NetworkInfoPlusOhosPlugin());
      flutterEngine.getPlugins()?.add(new FlutterSecureStorageOhosPlugin());
      flutterEngine.getPlugins()?.add(new SharedPreferencesPlugin());
      flutterEngine.getPlugins()?.add(new ConnectivityPlugin());
      flutterEngine.getPlugins()?.add(new BDPlugin());
    } catch (e) {
      Log.e(
        TAG,
        'Tried to register background plugins with FlutterEngine ('
          + flutterEngine
          + ') failed.',
      );
      Log.e(TAG, 'Received exception while registering background plugins', e);
    }
  }
}
