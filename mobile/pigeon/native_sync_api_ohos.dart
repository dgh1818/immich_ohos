import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/native_sync_api_ohos.g.dart',
    arkTSOut: 'ohos/entry/src/main/ets/plugins/sync/Messages_ohos.g.ets',
    arkTSOptions: ArkTSOptions(),
    dartOptions: DartOptions(),
    dartPackageName: 'immich_mobile',
  ),
)
class PlatformAsset {
  final String id;
  final String name;
  // Follows AssetType enum from base_asset.model.dart
  final int type;
  // Seconds since epoch
  final int? createdAt;
  final int? updatedAt;
  final int? width;
  final int? height;
  final int durationInSeconds;
  final int orientation;
  final bool isFavorite;

  const PlatformAsset({
    required this.id,
    required this.name,
    required this.type,
    this.createdAt,
    this.updatedAt,
    this.width,
    this.height,
    this.durationInSeconds = 0,
    this.orientation = 0,
    this.isFavorite = false,
  });
}

class PlatformAlbum {
  final String id;
  final String name;
  // Seconds since epoch
  final int? updatedAt;
  final bool isCloud;
  final int assetCount;

  const PlatformAlbum({
    required this.id,
    required this.name,
    this.updatedAt,
    this.isCloud = false,
    this.assetCount = 0,
  });
}

class SyncDelta {
  final bool hasChanges;
  final List<PlatformAsset> updates;
  final List<String> deletes;
  // Asset -> Album mapping
  final Map<String, List<String>> assetAlbums;

  const SyncDelta({
    this.hasChanges = false,
    this.updates = const [],
    this.deletes = const [],
    this.assetAlbums = const {},
  });
}

@HostApi()
abstract class NativeSyncApiOhos {
  bool shouldFullSync();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  SyncDelta getMediaChanges();

  void checkpointSync();

  void clearSyncCheckpoint();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  List<String> getAssetIdsForAlbum(String albumId);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  List<PlatformAlbum> getAlbums();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  int getAssetsCountSince(String albumId, int timestamp);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  List<PlatformAsset> getAssetsForAlbum(String albumId, {int? updatedTimeCond});

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  List<Uint8List> hashPaths(List<String> paths);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  int startBackgroundTransfer();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  void updateBackgroundTransferProgress(
    double progress,
    String title,
    String fileName,
  );

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  void stopBackgroundTransfer();
}
