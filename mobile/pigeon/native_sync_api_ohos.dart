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
class HashResult {
  final String assetId;
  final String? error;
  final String? hash;

  const HashResult({required this.assetId, this.error, this.hash});
}

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

  final int? adjustmentTime;
  final double? latitude;
  final double? longitude;

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

    this.adjustmentTime,
    this.latitude,
    this.longitude,
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

class CloudIdResult {
  final String assetId;
  final String? error;
  final String? cloudId;

  const CloudIdResult({required this.assetId, this.error, this.cloudId});
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
  List<HashResult> hashAssets(List<String> assetIds, {bool allowNetworkAccess = false});

  void cancelHashing();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  int startBackgroundTransfer();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  void updateBackgroundTransferProgress(double progress, String title, String fileName);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  void stopBackgroundTransfer();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  Map<String, List<PlatformAsset>> getTrashedAssets();

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  String getPathFromUri(String uri);

  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @async
  List<CloudIdResult> getCloudIdForAssetIds(List<String> assetIds);
}
