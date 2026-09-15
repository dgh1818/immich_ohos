import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';

class AssetPreloader {
  static final _dummyListener = ImageStreamListener((image, _) => image.dispose());

  final TimelineService timelineService;
  final bool Function() mounted;

  Timer? _timer;
  ImageStream? _prevStream;
  ImageStream? _nextStream;

  AssetPreloader({required this.timelineService, required this.mounted});

  /// Preloads adjacent images with the current thumbnail size.
  void preload(int index, Size size, {Size? thumbnailSize, ui.ImageDynamicRangePolicy? dynamicRangePolicy}) {
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
      _prevStream = prev != null ? _resolveImage(prev, size, thumbnailSize, dynamicRangePolicy) : null;
      _nextStream = next != null ? _resolveImage(next, size, thumbnailSize, dynamicRangePolicy) : null;
    });
  }

  ImageStream _resolveImage(
    BaseAsset asset,
    Size size,
    Size? thumbnailSize,
    ui.ImageDynamicRangePolicy? dynamicRangePolicy,
  ) {
    // Warm exactly the provider key the asset page resolves, including the
    // source-preserving dynamic-range policy used by the visible image.
    final provider = getFullImageProvider(
      asset,
      size: size,
      remoteThumbnailSize: thumbnailSize,
      dynamicRangePolicy: dynamicRangePolicy,
    );
    return provider.resolve(ImageConfiguration.empty)..addListener(_dummyListener);
  }

  void dispose() {
    _timer?.cancel();
    _prevStream?.removeListener(_dummyListener);
    _nextStream?.removeListener(_dummyListener);
  }
}
