part of 'image_request.dart';

class RemoteImageRequest extends ImageRequest {
  final String uri;
  final Map<String, String> headers;

  RemoteImageRequest({required this.uri, required this.headers});

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    final info = await remoteImageApi.requestImage(uri, headers: headers, requestId: requestId);
    if (info == null) {
      return null;
    }

    final frame = await _fromPlatformImage(info);
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<void> _onCancelled() {
    return remoteImageApi.cancelRequest(requestId);
  }
}
