part of 'image_request.dart';

class LocalImageRequest extends ImageRequest {
  final String localId;
  final int width;
  final int height;
  final AssetType assetType;

  LocalImageRequest({
    required this.localId,
    required ui.Size size,
    required this.assetType,
    ui.ImageDynamicRangePolicy? dynamicRangePolicy,
  }) : width = size.width.toInt(),
       height = size.height.toInt() {
    this.dynamicRangePolicy = dynamicRangePolicy;
  }

  @override
  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0}) async {
    if (_isCancelled) {
      return null;
    }

    final info = await localImageApi.requestImage(
      localId,
      requestId: requestId,
      width: width,
      height: height,
      isVideo: assetType == AssetType.video,
      preferEncoded: false,
    );
    final frame = await _firstFrame(await _codecFromResponse(info));
    return frame == null ? null : ImageInfo(image: frame.image, scale: scale);
  }

  @override
  Future<ui.Codec?> loadCodec() async {
    if (_isCancelled) {
      return null;
    }

    final info = await localImageApi.requestImage(
      localId,
      requestId: requestId,
      width: width,
      height: height,
      isVideo: assetType == AssetType.video,
      preferEncoded: true,
    );
    final result = await _codecFromResponse(info);
    return result == null ? null : _DescriptorBackedCodec(result.$1, result.$2);
  }

  @override
  Future<void> _onCancelled() {
    return localImageApi.cancelRequest(requestId);
  }
}
