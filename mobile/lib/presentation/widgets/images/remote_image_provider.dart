import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/loaders/image_request.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/presentation/widgets/images/animated_image_stream_completer.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/one_frame_multi_image_stream_completer.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:openapi/api.dart';

class RemoteImageProvider extends CancellableImageProvider<RemoteImageProvider>
    with CancellableImageProviderMixin<RemoteImageProvider> {
  final String url;
  final bool edited;
  final bool aiHdr;

  RemoteImageProvider({required this.url, this.edited = true, this.aiHdr = false});

  RemoteImageProvider.thumbnail({
    required String assetId,
    required String thumbhash,
    this.edited = true,
    this.aiHdr = false,
  }) : url = getThumbnailUrlForRemoteId(assetId, thumbhash: thumbhash, edited: edited);

  @override
  Future<RemoteImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteImageProvider key, ImageDecoderCallback decode) {
    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('URL', key.url),
      ],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteImageProvider key, ImageDecoderCallback decode) {
    final effectiveDecode = key.aiHdr ? aiHdrDecodeCallback(decode) : decode;
    final request = this.request = RemoteImageRequest(uri: key.url, aiHdr: key.aiHdr);
    return loadRequest(request, effectiveDecode, isFinal: true);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is RemoteImageProvider) {
      return url == other.url && edited == other.edited && aiHdr == other.aiHdr;
    }
    return false;
  }

  @override
  int get hashCode => url.hashCode ^ edited.hashCode ^ aiHdr.hashCode;
}

class RemoteFullImageProvider extends CancellableImageProvider<RemoteFullImageProvider>
    with CancellableImageProviderMixin<RemoteFullImageProvider> {
  final String assetId;
  final String thumbhash;
  final AssetType assetType;
  final bool isAnimated;
  final bool edited;
  final bool aiHdr;

  RemoteFullImageProvider({
    required this.assetId,
    required this.thumbhash,
    required this.assetType,
    required this.isAnimated,
    this.edited = true,
    this.aiHdr = false,
  });

  @override
  Future<RemoteFullImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteFullImageProvider key, ImageDecoderCallback decode) {
    final effectiveDecode = key.aiHdr ? aiHdrDecodeCallback(decode) : decode;
    if (key.isAnimated) {
      return AnimatedImageStreamCompleter(
        stream: _animatedCodec(key, effectiveDecode),
        scale: 1.0,
        initialImage: getInitialImage(
          RemoteImageProvider.thumbnail(assetId: key.assetId, thumbhash: key.thumbhash, aiHdr: false),
        ),
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<String>('Asset Id', key.assetId),
          DiagnosticsProperty<bool>('isAnimated', key.isAnimated),
        ],
        onLastListenerRemoved: cancel,
      );
    }

    ImageInfo? initialImage;
    final loadOriginal = key.assetType == AssetType.image && SettingsRepository.instance.appConfig.image.loadOriginal;
    if (loadOriginal) {
      final originalProvider = RemoteImageProvider(url: getOriginalUrlForRemoteId(key.assetId, edited: key.edited));
      final originalStatus = PaintingBinding.instance.imageCache.statusForKey(originalProvider);
      if (!originalStatus.pending && (originalStatus.keepAlive || originalStatus.live)) {
        initialImage = getInitialImage(originalProvider);
      }
    }
    if (initialImage != null) {
      isFinished = true;
    }
    initialImage ??= getInitialImage(
      // SDR placeholder (OHOS AI HDR): it is shown while the surface is still
      // SDR — the surface flips to HLG only when the preview tier arrives.
      RemoteImageProvider.thumbnail(
        assetId: key.assetId,
        thumbhash: key.thumbhash,
        edited: key.edited,
        aiHdr: false,
      ),
    );

    return OneFramePlaceholderImageStreamCompleter(
      initialImage != null && isFinished ? const Stream<ImageInfo>.empty() : _codec(key, effectiveDecode),
      initialImage: initialImage,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Asset Id', key.assetId),
        DiagnosticsProperty<bool>('isAnimated', key.isAnimated),
      ],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteFullImageProvider key, ImageDecoderCallback decode) async* {
    yield* initialImageStream();

    if (isCancelled) {
      return;
    }

    final previewRequest = request = RemoteImageRequest(
      uri: getThumbnailUrlForRemoteId(
        key.assetId,
        type: AssetMediaSize.preview,
        thumbhash: key.thumbhash,
        edited: key.edited,
      ),
      aiHdr: key.aiHdr,
    );
    final loadOriginal = assetType == AssetType.image && SettingsRepository.instance.appConfig.image.loadOriginal;
    yield* loadRequest(previewRequest, decode, isFinal: !loadOriginal);

    if (!loadOriginal) {
      return;
    }

    if (isCancelled) {
      return;
    }

    final originalRequest = request = RemoteImageRequest(
      uri: getOriginalUrlForRemoteId(key.assetId, edited: key.edited),
      aiHdr: key.aiHdr,
    );
    yield* loadRequest(originalRequest, decode, isFinal: true);
  }

  Stream<Object> _animatedCodec(RemoteFullImageProvider key, ImageDecoderCallback decode) async* {
    yield* initialImageStream();

    if (isCancelled) {
      return;
    }

    final previewRequest = request = RemoteImageRequest(
      uri: getThumbnailUrlForRemoteId(
        key.assetId,
        type: AssetMediaSize.preview,
        thumbhash: key.thumbhash,
        edited: key.edited,
      ),
    );
    yield* loadRequest(previewRequest, decode, isFinal: false);

    if (isCancelled) {
      return;
    }

    // always try original for animated, since previews don't support animation
    final originalRequest = request = RemoteImageRequest(
      uri: getOriginalUrlForRemoteId(key.assetId, edited: key.edited),
    );
    final codec = await loadCodecRequest(originalRequest, isFinal: true);
    if (codec == null) {
      if (isCancelled) {
        return;
      }
      throw StateError('Failed to load animated codec for asset ${key.assetId}');
    }
    yield codec;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is RemoteFullImageProvider) {
      return assetId == other.assetId &&
          thumbhash == other.thumbhash &&
          isAnimated == other.isAnimated &&
          edited == other.edited;
    }

    return false;
  }

  @override
  int get hashCode => assetId.hashCode ^ thumbhash.hashCode ^ isAnimated.hashCode ^ edited.hashCode ^ aiHdr.hashCode;
}
