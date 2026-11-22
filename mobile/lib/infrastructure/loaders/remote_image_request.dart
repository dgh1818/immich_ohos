part of 'image_request.dart';

class RemoteImageRequest extends ImageRequest {
  final String uri;

  /// Physical size to decode, or null for the source size.
  final ui.Size? decodeSize;

  RemoteImageRequest({required this.uri, this.decodeSize, ui.ImageDynamicRangePolicy? dynamicRangePolicy}) {
    this.dynamicRangePolicy = dynamicRangePolicy;
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
      // conversion on the client. OHOS currently returns encoded bytes for
      // both values, while other producers may return decoded pixels.
      preferEncoded: dynamicRangePolicy?.name == 'aiHdrAuto',
      width: decodeSize?.width.ceil(),
      height: decodeSize?.height.ceil(),
    );
    final frame = await _firstFrame(await _codecFromResponse(info, decodeSize: decodeSize));
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
    final result = await _codecFromResponse(info);
    return result == null ? null : _DescriptorBackedCodec(result.$1, result.$2);
  }

  @override
  Future<void> _onCancelled() {
    return remoteImageApi.cancelRequest(requestId);
  }
}
