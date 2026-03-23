part of 'image_request.dart';

class RemoteImageRequest extends ImageRequest {
  final String uri;

  RemoteImageRequest({required this.uri});

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    final info = await remoteImageApi.requestImage(uri, requestId: requestId, preferEncoded: false);
    if (info == null) {
      return null;
    }

    final frame = await _fromPlatformImage(info);
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    final info = await remoteImageApi.requestImage(uri, requestId: requestId, preferEncoded: true);
    if (info == null) return null;

    final pointer = info['pointer'] as int?;
    final length = info['length'] as int?;
    if (pointer == null || length == null) {
      return null;
    }

    final (codec, _) = await _codecFromEncodedPlatformImage(pointer, length) ?? (null, null);
    return codec;
  }

  @override
  Future<void> _onCancelled() {
    return remoteImageApi.cancelRequest(requestId);
  }
}
