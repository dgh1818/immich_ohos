part of 'image_request.dart';

class ThumbhashImageRequest extends ImageRequest {
  final String thumbhash;

  ThumbhashImageRequest({required this.thumbhash});

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    final Map<String, Object> info = await localImageApi.getThumbhash(thumbhash);
    final frame = await _fromDecodedPlatformImage(
      info["pointer"]! as int,
      info["width"]! as int,
      info["height"]! as int,
      info["rowBytes"]! as int,
      info["isHdr"] as bool? ?? false,
    );
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() => throw UnsupportedError('Thumbhash does not support codec loading');

  @override
  void _onCancelled() {}
}
