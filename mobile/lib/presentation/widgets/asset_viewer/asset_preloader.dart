import 'dart:async';

import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/remote_image_provider.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';

class AssetPreloader {
  static final _dummyListener = ImageStreamListener((image, _) => image.dispose());

  final TimelineService timelineService;
  final bool Function() mounted;

  Timer? _timer;
  ImageStream? _prevStream;
  ImageStream? _nextStream;

  AssetPreloader({required this.timelineService, required this.mounted});

  void preload(int index, Size size) {
    unawaited(timelineService.preloadAssets(index));
    _timer?.cancel();
    _timer = Timer(Durations.medium4, () async {
      if (!mounted()) {
        return;
      }
      final current = await timelineService.getAssetAsync(index);
      if (!mounted()) {
        return;
      }
      if (current?.isVideo == true) {
        _prevStream?.removeListener(_dummyListener);
        _nextStream?.removeListener(_dummyListener);
        _prevStream = null;
        _nextStream = null;
        return;
      }
      final (prev, next) = await (
        timelineService.getAssetAsync(index - 1),
        timelineService.getAssetAsync(index + 1),
      ).wait;
      if (!mounted()) {
        return;
      }
      _prevStream?.removeListener(_dummyListener);
      _nextStream?.removeListener(_dummyListener);
      _prevStream = prev != null ? _resolveImage(prev, size) : null;
      _nextStream = next != null ? _resolveImage(next, size) : null;
    });
  }

  ImageStream _resolveImage(BaseAsset asset, Size size) {
    final provider =
        asset is RemoteAsset &&
            asset.isImage &&
            !asset.isAnimatedImage &&
            SettingsRepository.instance.appConfig.image.loadOriginal
        ? RemoteImageProvider(url: getOriginalUrlForRemoteId(asset.id))
        : getFullImageProvider(asset, size: size);
    return provider.resolve(ImageConfiguration.empty)..addListener(_dummyListener);
  }

  void dispose() {
    _timer?.cancel();
    _prevStream?.removeListener(_dummyListener);
    _nextStream?.removeListener(_dummyListener);
  }
}
