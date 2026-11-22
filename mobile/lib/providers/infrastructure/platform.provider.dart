import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/services/background_worker.service.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/platform/background_worker_api.g.dart';
import 'package:immich_mobile/platform/background_worker_lock_api.g.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';
import 'package:immich_mobile/platform/local_image_api.g.dart';
import 'package:immich_mobile/platform/local_image_api_ohos.g.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/platform/network_api.g.dart';
import 'package:immich_mobile/platform/passkey_api.g.dart';
import 'package:immich_mobile/platform/permission_api.g.dart';
import 'package:immich_mobile/platform/remote_image_api.g.dart';
import 'package:immich_mobile/platform/remote_image_api_ohos.g.dart';

final backgroundWorkerFgServiceProvider = Provider((_) => BackgroundWorkerFgService(BackgroundWorkerFgHostApi()));

final backgroundWorkerLockServiceProvider = Provider<BackgroundWorkerLockService>(
  (_) => BackgroundWorkerLockService(BackgroundWorkerLockApi()),
);

final nativeSyncApiProvider = Provider<NativeSyncApiOhos>((_) => NativeSyncApiOhos());

final permissionApiProvider = Provider<PermissionApi>((_) => PermissionApi());

final connectivityApiProvider = Provider<ConnectivityApi>((_) => ConnectivityApi());

final passkeyHostApiProvider = Provider<PasskeyHostApi>((_) => PasskeyHostApi());

// Both clients use the same arguments. Widen the standard client's integer
// maps so callers can also read OHOS metadata such as the boolean isHdr.
final localImageApi = (() {
  if (CurrentPlatform.isOhos) {
    final api = LocalImageApiOhos();
    return (requestImage: api.requestImage, cancelRequest: api.cancelRequest, getThumbhash: api.getThumbhash);
  }
  final api = LocalImageApi();
  return (requestImage: api.requestImage, cancelRequest: api.cancelRequest, getThumbhash: api.getThumbhash);
})();

final remoteImageApi = (() {
  if (CurrentPlatform.isOhos) {
    final api = RemoteImageApiOhos();
    return (requestImage: api.requestImage, cancelRequest: api.cancelRequest, clearCache: api.clearCache);
  }
  final api = RemoteImageApi();
  return (requestImage: api.requestImage, cancelRequest: api.cancelRequest, clearCache: api.clearCache);
})();

final networkApi = NetworkApi();
