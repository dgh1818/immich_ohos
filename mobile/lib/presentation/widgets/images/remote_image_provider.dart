import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/domain/services/setting.service.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/one_frame_multi_image_stream_completer.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:openapi/api.dart';

class RemoteImageProvider extends CancellableImageProvider<RemoteImageProvider>
    with CancellableImageProviderMixin<RemoteImageProvider> {
  final String url;
  ImageStream? _networkStream;
  ImageStreamListener? _networkListener;

  RemoteImageProvider({required this.url});

  RemoteImageProvider.thumbnail({required String assetId, required String thumbhash})
      : url = getThumbnailUrlForRemoteId(assetId, thumbhash: thumbhash);

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
    final headers = ApiService.getRequestHeaders();
    final provider = NetworkImage(key.url, headers: headers);
    final controller = StreamController<ImageInfo>();

    _networkStream = provider.resolve(const ImageConfiguration());
    _networkListener = ImageStreamListener(
      (image, _) {
        if (!controller.isClosed) {
          controller.add(image);
          controller.close();
        }
        _clearNetworkListener();
      },
      onError: (error, stack) {
        if (!controller.isClosed) {
          controller.addError(error, stack);
          controller.close();
        }
        _clearNetworkListener();
      },
    );

    _networkStream!.addListener(_networkListener!);
    return controller.stream;
  }

  void _clearNetworkListener() {
    final stream = _networkStream;
    final listener = _networkListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _networkStream = null;
    _networkListener = null;
  }

  @override
  void cancel() {
    super.cancel();
    _clearNetworkListener();
    PaintingBinding.instance.imageCache.evict(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is RemoteImageProvider) {
      return url == other.url;
    }
    return false;
  }

  @override
  int get hashCode => url.hashCode;
}

class RemoteFullImageProvider extends CancellableImageProvider<RemoteFullImageProvider>
    with CancellableImageProviderMixin<RemoteFullImageProvider> {
  final String assetId;
  final String thumbhash;
  final AssetType assetType;
  ImageStream? _previewStream;
  ImageStreamListener? _previewListener;
  StreamController<ImageInfo>? _previewController;
  ImageStream? _originalStream;
  ImageStreamListener? _originalListener;
  StreamController<ImageInfo>? _originalController;

  RemoteFullImageProvider({required this.assetId, required this.thumbhash, required this.assetType});

  @override
  Future<RemoteFullImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteFullImageProvider key, ImageDecoderCallback decode) {
    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      initialImage: getInitialImage(RemoteImageProvider.thumbnail(assetId: key.assetId, thumbhash: key.thumbhash)),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Asset Id', key.assetId),
      ],
      onLastListenerRemoved: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteFullImageProvider key, ImageDecoderCallback decode) async* {
    yield* initialImageStream();

    if (isCancelled) {
      PaintingBinding.instance.imageCache.evict(this);
      return;
    }

    final headers = ApiService.getRequestHeaders();

    final previewStream = _startNetworkStream(
      getThumbnailUrlForRemoteId(key.assetId, type: AssetMediaSize.preview, thumbhash: key.thumbhash),
      headers,
      isPreview: true,
    );

    if (assetType != AssetType.image || !AppSetting.get(Setting.loadOriginal)) {
      yield* previewStream;
      return;
    }

    if (isCancelled) {
      PaintingBinding.instance.imageCache.evict(this);
      return;
    }

    final originalStream = _startNetworkStream(
      getOriginalUrlForRemoteId(key.assetId),
      headers,
      isPreview: false,
      onFirstImage: _clearPreviewListener,
    );
    yield* StreamGroup.merge([previewStream, originalStream]);
  }

  Stream<ImageInfo> _startNetworkStream(
    String url,
    Map<String, String> headers, {
    required bool isPreview,
    void Function()? onFirstImage,
  }) {
    final provider = NetworkImage(url, headers: headers);
    final controller = StreamController<ImageInfo>();
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (image, _) {
        if (!controller.isClosed) {
          controller.add(image);
          controller.close();
        }
        if (isPreview) {
          _clearPreviewListener();
        } else {
          _clearOriginalListener();
        }
        onFirstImage?.call();
      },
      onError: (error, stack) {
        if (!controller.isClosed) {
          controller.addError(error, stack);
          controller.close();
        }
        if (isPreview) {
          _clearPreviewListener();
        } else {
          _clearOriginalListener();
        }
      },
    );

    stream.addListener(listener);
    if (isPreview) {
      _previewStream = stream;
      _previewListener = listener;
      _previewController = controller;
    } else {
      _originalStream = stream;
      _originalListener = listener;
      _originalController = controller;
    }
    return controller.stream;
  }

  void _clearPreviewListener() {
    final stream = _previewStream;
    final listener = _previewListener;
    final controller = _previewController;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _previewStream = null;
    _previewListener = null;
    _previewController = null;
  }

  void _clearOriginalListener() {
    final stream = _originalStream;
    final listener = _originalListener;
    final controller = _originalController;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
    _originalStream = null;
    _originalListener = null;
    _originalController = null;
  }

  @override
  void cancel() {
    super.cancel();
    _clearPreviewListener();
    _clearOriginalListener();
    PaintingBinding.instance.imageCache.evict(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is RemoteFullImageProvider) {
      return assetId == other.assetId && thumbhash == other.thumbhash;
    }

    return false;
  }

  @override
  int get hashCode => assetId.hashCode ^ thumbhash.hashCode;
}
