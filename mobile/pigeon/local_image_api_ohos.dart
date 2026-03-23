import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/local_image_api_ohos.g.dart',
    arkTSOut: 'ohos/entry/src/main/ets/plugins/images/LocalImages.g.ets',
    arkTSOptions: ArkTSOptions(),
    dartOptions: DartOptions(),
    dartPackageName: 'immich_mobile',
  ),
)
@HostApi()
abstract class LocalImageApiOhos {
  @async
  Map<String, Object>? requestImage(
    String assetId, {
    required int requestId,
    required int width,
    required int height,
    required bool isVideo,
    required bool preferEncoded,
  });

  void cancelRequest(int requestId);

  @async
  Map<String, Object> getThumbhash(String thumbhash);
}
