import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/thumbnail_api_ohos.g.dart',
    arkTSOut: 'ohos/entry/src/main/ets/plugins/Images/Messages_ohos.g.ets',
    arkTSOptions: ArkTSOptions(),
    dartOptions: DartOptions(),
    dartPackageName: 'immich_mobile',
  ),
)
@HostApi()
abstract class ThumbnailApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  Map<String, Object> requestImage(
    String assetId, {
    required int requestId,
    required int width,
    required int height,
    required bool isVideo,
  });

  void cancelImageRequest(int requestId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  Map<String, Object> getThumbhash(String thumbhash);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  Map<String, bool> getHdr(String assetId);
}
