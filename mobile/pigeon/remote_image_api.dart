import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/remote_image_api.g.dart',
    swiftOut: 'ios/Runner/Images/RemoteImages.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
    kotlinOut: 'android/app/src/main/kotlin/app/alextran/immich/images/RemoteImages.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.alextran.immich.images', includeErrorClass: false),
    arkTSOut: 'ohos/entry/src/main/ets/plugins/Images/RemoteImages.g.ets',
    arkTSOptions: ArkTSOptions(),
    dartOptions: DartOptions(),
    dartPackageName: 'immich_mobile',
  ),
)
@HostApi()
abstract class RemoteImageApi {
  @async
  Map<String, int>? requestImage(String url, {required Map<String, String> headers, required int requestId});

  void cancelRequest(int requestId);

  @async
  int clearCache();
}
