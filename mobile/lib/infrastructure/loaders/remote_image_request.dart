part of 'image_request.dart';

class RemoteImageRequest extends ImageRequest {
  final String uri;

  /// Physical size to decode, or null for the source size.
  final ui.Size? decodeSize;

  RemoteImageRequest({required this.uri, this.decodeSize, bool aiHdr = false}) {
    this.aiHdr = aiHdr;
  }

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    final info = await remoteImageApi.requestImage(
      uri,
      requestId: requestId,
      // AI HDR needs encoded bytes so the engine can perform the SDR -> HLG
      // conversion on the client.
      preferEncoded: aiHdr,
      width: decodeSize?.width.ceil(),
      height: decodeSize?.height.ceil(),
    );
    // Android falls back to encoded data if native decoding fails, so check for both shapes of the response.
    final frame = switch (info) {
      {'pointer': final int pointer, 'length': final int length} => await _fromEncodedPlatformImage(
        pointer,
        length,
        decodeSize: decodeSize,
        aiHdr: aiHdr,
      ),
      {
        'pointer': final int pointer,
        'width': final int width,
        'height': final int height,
        'rowBytes': final int rowBytes,
        'isHdr': final bool isHdr,
      } =>
        await _fromDecodedPlatformImage(pointer, width, height, rowBytes, isHdr),
      _ => null,
    };
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    final info = await remoteImageApi.requestImage(
      uri,
      requestId: requestId,
      preferEncoded: true,
      width: null,
      height: null,
    );
    if (info == null) {
      return null;
    }

    final (codec, _) =
        await _codecFromEncodedPlatformImage(info['pointer']! as int, info['length']! as int, aiHdr: aiHdr) ??
        (null, null);
    return codec;
  }

  @override
  Future<void> _onCancelled() {
    return remoteImageApi.cancelRequest(requestId);
  }
}
