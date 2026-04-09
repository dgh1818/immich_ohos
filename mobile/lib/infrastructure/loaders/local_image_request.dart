part of 'image_request.dart';

class LocalImageRequest extends ImageRequest {
  final String localId;
  final int width;
  final int height;
  final AssetType assetType;

  LocalImageRequest({required this.localId, required ui.Size size, required this.assetType})
    : width = size.width.toInt(),
      height = size.height.toInt();

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
    if (info == null) {
      return null;
    }

    final pointer = info["pointer"] as int?;
    final imgWidth = info["width"] as int?;
    final imgHeight = info["height"] as int?;
    final rowBytes = info["rowBytes"] as int?;
    if (pointer == null || imgWidth == null || imgHeight == null || rowBytes == null) {
      return null;
    }

    final frame = await _fromDecodedPlatformImage(
      pointer,
      imgWidth,
      imgHeight,
      rowBytes,
      info["isHdr"] as bool? ?? false,
    );
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
    if (info == null) return null;

    final pointer = info['pointer'] as int?;
    final length = info['length'] as int?;
    if (pointer == null || length == null) return null;

    final (codec, _) = await _codecFromEncodedPlatformImage(pointer, length) ?? (null, null);
    return codec;
  }

  @override
  Future<void> _onCancelled() {
    return localImageApi.cancelRequest(requestId);
  }
}
