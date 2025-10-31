import 'package:hooks_riverpod/hooks_riverpod.dart';
<<<<<<< HEAD
//import 'package:immich_mobile/platform/native_sync_api.g.dart';
//import 'package:immich_mobile/platform/thumbnail_api.g.dart';

import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/platform/thumbnail_api_ohos.g.dart';

final nativeSyncApiProvider = Provider<NativeSyncApiOhos>((_) => NativeSyncApiOhos());
=======
import 'package:immich_mobile/domain/services/background_worker.service.dart';
import 'package:immich_mobile/platform/background_worker_api.g.dart';
import 'package:immich_mobile/platform/background_worker_lock_api.g.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';
import 'package:immich_mobile/platform/native_sync_api.g.dart';
import 'package:immich_mobile/platform/thumbnail_api.g.dart';

final backgroundWorkerFgServiceProvider = Provider((_) => BackgroundWorkerFgService(BackgroundWorkerFgHostApi()));

final backgroundWorkerLockServiceProvider = Provider<BackgroundWorkerLockService>(
  (_) => BackgroundWorkerLockService(BackgroundWorkerLockApi()),
);

final nativeSyncApiProvider = Provider<NativeSyncApi>((_) => NativeSyncApi());
>>>>>>> v2.2.0

final connectivityApiProvider = Provider<ConnectivityApi>((_) => ConnectivityApi());

final thumbnailApi = ThumbnailApi();
