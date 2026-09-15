part of 'image_request.dart';

class RemoteImageRequest extends ImageRequest {
  final String uri;

  RemoteImageRequest({required this.uri, bool aiHdr = false}) {
    this.aiHdr = aiHdr;
  }

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    // AI HDR needs the encoded bytes so the engine can convert SDR -> HLG.
    final info = await remoteImageApi.requestImage(uri, requestId: requestId, preferEncoded: aiHdr);
    final frame = switch (info) {
      {'pointer': int pointer, 'length': int length} => await _fromEncodedPlatformImage(pointer, length, aiHdr: aiHdr),
      {
        'pointer': int pointer,
        'width': int width,
        'height': int height,
        'rowBytes': int rowBytes,
        'isHdr': bool isHdr,
      } =>
        await _fromDecodedPlatformImage(pointer, width, height, rowBytes, isHdr),
      {'pointer': int pointer, 'width': int width, 'height': int height, 'rowBytes': int rowBytes} =>
        await _fromDecodedPlatformImage(pointer, width, height, rowBytes),
      _ => null,
    };
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    final info = await remoteImageApi.requestImage(uri, requestId: requestId, preferEncoded: true);
    if (info == null) {
      return null;
    }

    final (codec, _) =
        await _codecFromEncodedPlatformImage(info['pointer']! as int, info['length']! as int) ?? (null, null);
    return codec;
  }

  @override
  Future<void> _onCancelled() {
    return remoteImageApi.cancelRequest(requestId);
  }
}
