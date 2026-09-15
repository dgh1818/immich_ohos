import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/remote_image_api_ohos.g.dart',
    arkTSOut: 'ohos/entry/src/main/ets/plugins/Images/RemoteImages.g.ets',
    arkTSOptions: ArkTSOptions(),
    dartOptions: DartOptions(),
    dartPackageName: 'immich_mobile',
  ),
)
@HostApi()
abstract class RemoteImageApiOhos {
  /// Width and height are the physical decode size, or null for the source size.
  @async
  Map<String, Object>? requestImage(
    String url, {
    required int requestId,
    required bool preferEncoded,
    int? width,
    int? height,
  });

  void cancelRequest(int requestId);

  @async
  int clearCache();
}
