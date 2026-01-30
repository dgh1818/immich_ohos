import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/domain/services/setting.service.dart';
import 'package:immich_mobile/infrastructure/loaders/image_request.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/presentation/widgets/images/one_frame_multi_image_stream_completer.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:openapi/api.dart';

class RemoteThumbProvider extends CancellableImageProvider<RemoteThumbProvider>
    with CancellableImageProviderMixin<RemoteThumbProvider> {
  final String assetId;
  final String thumbhash;
  ImageStream? _networkStream;
  ImageStreamListener? _networkListener;

  RemoteThumbProvider({required this.assetId, required this.thumbhash});

  @override
  Future<RemoteThumbProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteThumbProvider key, ImageDecoderCallback decode) {
    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Asset Id', key.assetId),
      ],
      onDispose: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteThumbProvider key, ImageDecoderCallback decode) {
    final url = getThumbnailUrlForRemoteId(key.assetId, thumbhash: key.thumbhash);
    final headers = ApiService.getRequestHeaders();
    final provider = NetworkImage(url, headers: headers);
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
    if (other is RemoteThumbProvider) {
      return assetId == other.assetId && thumbhash == other.thumbhash;
    }

    return false;
  }

  @override
  int get hashCode => assetId.hashCode ^ thumbhash.hashCode;
}

class RemoteFullImageProvider extends CancellableImageProvider<RemoteFullImageProvider>
    with CancellableImageProviderMixin<RemoteFullImageProvider> {
  final String assetId;
  final String thumbhash;
  final AssetType assetType;

  RemoteFullImageProvider({required this.assetId, required this.thumbhash, required this.assetType});

  @override
  Future<RemoteFullImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  ImageStreamCompleter loadImage(RemoteFullImageProvider key, ImageDecoderCallback decode) {
    return OneFramePlaceholderImageStreamCompleter(
      _codec(key, decode),
      initialImage: getInitialImage(RemoteThumbProvider(assetId: key.assetId, thumbhash: key.thumbhash)),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Asset Id', key.assetId),
      ],
      onDispose: cancel,
    );
  }

  Stream<ImageInfo> _codec(RemoteFullImageProvider key, ImageDecoderCallback decode) async* {
    yield* initialImageStream();

    if (isCancelled) {
      PaintingBinding.instance.imageCache.evict(this);
      return;
    }

    final headers = ApiService.getRequestHeaders();
    final previewRequest = RemoteImageRequest(
      uri: getThumbnailUrlForRemoteId(key.assetId, type: AssetMediaSize.preview, thumbhash: key.thumbhash),
      headers: headers,
    );
    final previewStream = loadRequest(previewRequest, decode);

    if (assetType != AssetType.image || !AppSetting.get(Setting.loadOriginal)) {
      yield* previewStream;
      return;
    }

    if (isCancelled) {
      PaintingBinding.instance.imageCache.evict(this);
      return;
    }

    final request = RemoteImageRequest(uri: getOriginalUrlForRemoteId(key.assetId), headers: headers);
    final originalStream = loadRequest(request, decode).map((image) {
      previewRequest.cancel();
      return image;
    });
    yield* StreamGroup.merge([previewStream, originalStream]);
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
