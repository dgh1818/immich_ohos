import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/services/background_worker.service.dart';
import 'package:immich_mobile/platform/background_worker_api.g.dart';
import 'package:immich_mobile/platform/background_worker_lock_api.g.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/platform/local_image_api_ohos.g.dart';
import 'package:immich_mobile/platform/network_api.g.dart';
import 'package:immich_mobile/platform/remote_image_api_ohos.g.dart';

final backgroundWorkerFgServiceProvider = Provider((_) => BackgroundWorkerFgService(BackgroundWorkerFgHostApi()));

final backgroundWorkerLockServiceProvider = Provider<BackgroundWorkerLockService>(
  (_) => BackgroundWorkerLockService(BackgroundWorkerLockApi()),
);

final nativeSyncApiProvider = Provider<NativeSyncApiOhos>((_) => NativeSyncApiOhos());

final connectivityApiProvider = Provider<ConnectivityApi>((_) => ConnectivityApi());

final localImageApi = LocalImageApiOhos();

final remoteImageApi = RemoteImageApiOhos();

final networkApi = NetworkApi();
