import 'package:immich_mobile/domain/models/store.model.dart';

enum Setting<T> {
  tilesPerRow<int>(StoreKey.tilesPerRow, 4),
  groupAssetsBy<int>(StoreKey.groupAssetsBy, 0),
  showStorageIndicator<bool>(StoreKey.storageIndicator, true),
  loadOriginal<bool>(StoreKey.loadOriginal, true),
  loadOriginalVideo<bool>(StoreKey.loadOriginalVideo, true),
  autoPlayVideo<bool>(StoreKey.autoPlayVideo, true),
  imageHdr<bool>(StoreKey.imageHdr, true),
  videoHdr<bool>(StoreKey.videoHdr, true),
  preferRemoteImage<bool>(StoreKey.preferRemoteImage, true),
  advancedTroubleshooting<bool>(StoreKey.advancedTroubleshooting, false),
  enableBackup<bool>(StoreKey.enableBackup, false);

  const Setting(this.storeKey, this.defaultValue);

  final StoreKey<T> storeKey;
  final T defaultValue;
}
