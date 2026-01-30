import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:immich_mobile/providers/image/cache/image_loader.dart';
import 'package:immich_mobile/providers/image/cache/remote_image_cache_manager.dart';
import 'package:openapi/api.dart' as api;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:immich_mobile/services/app_settings.service.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';

/// The remote image provider for full size remote images
class ImmichRemoteImageProvider extends ImageProvider<ImmichRemoteImageProvider> {
  /// The [Asset.remoteId] of the asset to fetch
  final String assetId;
  final bool? is_image;

  /// The image cache manager
  //final CacheManager? cacheManager;
  static final cacheImage = RemoteImageCacheManager();

  const ImmichRemoteImageProvider({
    required this.assetId,
    //this.cacheManager,
    this.is_image,
  });

  /// Converts an [ImageProvider]'s settings plus an [ImageConfiguration] to a key
  /// that describes the precise image to load.
  @override
  Future<ImmichRemoteImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(ImmichRemoteImageProvider key, ImageDecoderCallback decode) {
    //final cache = cacheManager ?? RemoteImageCacheManager();
    final chunkEvents = StreamController<ImageChunkEvent>();
    return MultiImageStreamCompleter(
      codec: _codec(key, cacheImage, decode, chunkEvents),
      scale: 1.0,
      chunkEvents: chunkEvents.stream,
    );
  }

  /// Whether to show the original file or load a compressed version
  bool get _useOriginal => Store.get(AppSettingsEnum.loadOriginal.storeKey, AppSettingsEnum.loadOriginal.defaultValue);

  // Streams in each stage of the image as we ask for it
  Stream<ui.Codec> _codec(
    ImmichRemoteImageProvider key,
    CacheManager cache,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async* {
    // Load the higher resolution version of the image
    final url = getThumbnailUrlForRemoteId(key.assetId);
    final codec = await ImageLoader.loadImageFromCache(url, cache: cache, decode: decode, chunkEvents: chunkEvents);
    yield codec;

    // 2. 再用 preview：中倍数分辨率，用来替代直接从 thumbnail 跳原图那一下的“糊”
    final previewUrl = getThumbnailUrlForRemoteId(key.assetId, type: api.AssetMediaSize.preview);
    final previewCodec = ImageLoader.loadImageFromCache(
      previewUrl,
      cache: cache,
      decode: decode,
      chunkEvents: chunkEvents,
    );

    if (!(is_image ?? true)) {
      yield await previewCodec;
      await chunkEvents.close();
      return;
    }

    // Load the final remote image
    if (_useOriginal) {
      // Load the original image
      final url = getOriginalUrlForRemoteId(key.assetId);
      final codec = ImageLoader.loadImageFromCache(url, cache: cache, decode: decode, chunkEvents: chunkEvents);

      final previewTask = previewCodec.then((codec) => (codec: codec, isOriginal: false));
      final originalTask = codec.then((codec) => (codec: codec, isOriginal: true));
      final first = await Future.any([previewTask, originalTask]);
      yield first.codec;
      if (!first.isOriginal) {
        yield await codec;
      }
    } else {
      yield await previewCodec;
    }
    await chunkEvents.close();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is ImmichRemoteImageProvider) {
      return assetId == other.assetId;
    }

    return false;
  }

  @override
  int get hashCode => assetId.hashCode;
}
