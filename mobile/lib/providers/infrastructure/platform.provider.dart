import 'package:hooks_riverpod/hooks_riverpod.dart';
//import 'package:immich_mobile/platform/native_sync_api.g.dart';
//import 'package:immich_mobile/platform/thumbnail_api.g.dart';

import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/platform/thumbnail_api_ohos.g.dart';

final nativeSyncApiProvider = Provider<NativeSyncApiOhos>((_) => NativeSyncApiOhos());

final connectivityApiProvider = Provider<ConnectivityApi>((_) => ConnectivityApi());

final thumbnailApi = ThumbnailApi();
