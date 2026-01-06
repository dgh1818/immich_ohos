import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';

import 'package:immich_mobile/domain/models/store.model.dart';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'dart:async';
import 'dart:io';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';

part 'video_viewer_controller_provider.g.dart';

@riverpod
Future<VideoPlayerController> videoViewerController(VideoViewerControllerRef ref, {required BaseAsset asset}) async {
  late VideoPlayerController controller;
  if (asset.hasLocal && asset.livePhotoVideoId == null) {
    final id = asset is LocalAsset ? asset.id : (asset as RemoteAsset).localId!;
    final nativeSyncApi = NativeSyncApiOhos();
    final path = await nativeSyncApi.getPathFromUri(id);
    //final file = await StorageRepository().getFileForAsset(id);
    final file = File(path);
    //final file = await StorageRepository().getReadableFileForAsset(asset.name, asset.updatedAt.millisecondsSinceEpoch);

    controller = VideoPlayerController.file(file!);
  } else {
    final remoteId = (asset as RemoteAsset).id;
    // Use a network URL for the video player controller
    final serverEndpoint = Store.get(StoreKey.serverEndpoint);
    final String videoUrl = asset.livePhotoVideoId != null
        ? '$serverEndpoint/assets/${asset.livePhotoVideoId}/original'
        : '$serverEndpoint/assets/$remoteId/original';
    final url = Uri.parse(videoUrl);
    controller = VideoPlayerController.networkUrl(
      url,
      httpHeaders: ApiService.getRequestHeaders(),
      videoPlayerOptions: asset.livePhotoVideoId != null
          ? VideoPlayerOptions(mixWithOthers: true)
          : VideoPlayerOptions(mixWithOthers: false),
    );
  }

  final log = Logger("ImmichErrorLogger");
  try {
    await controller.initialize();
  } catch (e) {
    log.severe('Error playing video: $e');
  }

  ref.onDispose(() {
    unawaited(controller.dispose());
  });

  return controller;
}
