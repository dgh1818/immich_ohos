import 'package:immich_mobile/domain/models/user.model.dart';

/// Key for each possible value in the `Store`.
/// Defines the data type for each value
enum StoreKey<T> {
  version<int>._(0),
  assetETag<String>._(1),
  currentUser<UserDto>._(2),
  deviceIdHash<int>._(3),
  deviceId<String>._(4),
  backupFailedSince<DateTime>._(5),
  backupRequireWifi<bool>._(6),
  backupRequireCharging<bool>._(7),
  backupTriggerDelay<int>._(8),
  serverUrl<String>._(10),
  accessToken<String>._(11),
  serverEndpoint<String>._(12),
  autoBackup<bool>._(13),
  backgroundBackup<bool>._(14),
  sslClientCertData<String>._(15),
  sslClientPasswd<String>._(16),
  // user settings from [AppSettingsEnum] below:
  loadPreview<bool>._(100),
  loadOriginal<bool>._(101),
  themeMode<String>._(102),
  tilesPerRow<int>._(103),
  dynamicLayout<bool>._(104),
  groupAssetsBy<int>._(105),
  uploadErrorNotificationGracePeriod<int>._(106),
  backgroundBackupTotalProgress<bool>._(107),
  backgroundBackupSingleProgress<bool>._(108),
  storageIndicator<bool>._(109),
  thumbnailCacheSize<int>._(110),
  imageCacheSize<int>._(111),
  albumThumbnailCacheSize<int>._(112),
  selectedAlbumSortOrder<int>._(113),
  advancedTroubleshooting<bool>._(114),
  logLevel<int>._(115),
  preferRemoteImage<bool>._(116),
  loopVideo<bool>._(117),
  // map related settings
  mapShowFavoriteOnly<bool>._(118),
  mapRelativeDate<int>._(119),
  // 120 was used by the removed OHOS self-signed certificate bypass setting.
  mapIncludeArchived<bool>._(121),
  ignoreIcloudAssets<bool>._(122),
  selectedAlbumSortReverse<bool>._(123),
  mapThemeMode<int>._(124),
  mapwithPartners<bool>._(125),
  enableHapticFeedback<bool>._(126),
  customHeaders<String>._(127),

  // theme settings
  primaryColor<String>._(128),
  dynamicTheme<bool>._(129),
  colorfulInterface<bool>._(130),

  syncAlbums<bool>._(131),

  // Auto endpoint switching
  autoEndpointSwitching<bool>._(132),
  preferredWifiName<String>._(133),
  localEndpoint<String>._(134),
  externalEndpointList<String>._(135),

  // Video settings
  loadOriginalVideo<bool>._(136),
  manageLocalMediaAndroid<bool>._(137),

  // Read-only Mode settings
  readonlyModeEnabled<bool>._(138),

  autoPlayVideo<bool>._(139),
  albumGridView<bool>._(140),

  // Image viewer navigation settings
  tapToNavigate<bool>._(141),

  // Experimental stuff
  photoManagerCustomFilter<bool>._(1000),
  betaPromptShown<bool>._(1001),
  betaTimeline<bool>._(1002),
  enableBackup<bool>._(1003),
  useWifiForUploadVideos<bool>._(1004),
  useWifiForUploadPhotos<bool>._(1005),
  needBetaMigration<bool>._(1006),
  // TODO: Remove this after patching open-api
  shouldResetSync<bool>._(1007),

  // Free up space
  cleanupKeepFavorites<bool>._(1008),
  cleanupKeepMediaType<int>._(1009),
  cleanupKeepAlbumIds<String>._(1010),
  cleanupCutoffDaysAgo<int>._(1011),
  cleanupDefaultsInitialized<bool>._(1012),
  syncMigrationStatus<String>._(1013),
  imageHdr<bool>._(1014),
  videoHdr<bool>._(1015),
  ohosLocalAssetOrientationBackfill<bool>._(1016),

  // Legacy keys that have been migrated to the new metadata store
  legacyBackupRequireCharging<bool>._(7),
  legacyBackupTriggerDelay<int>._(8),
  legacySyncAlbums<bool>._(131),
  legacyEnableBackup<bool>._(1003),
  legacyUseWifiForUploadVideos<bool>._(1004),
  legacyUseWifiForUploadPhotos<bool>._(1005),
  legacySelectedAlbumSortOrder<int>._(113),
  legacySelectedAlbumSortReverse<bool>._(123),
  legacyAlbumGridView<bool>._(140),
  legacyAutoEndpointSwitching<bool>._(132),
  legacyPreferredWifiName<String>._(133),
  legacyLocalEndpoint<String>._(134),
  legacyExternalEndpointList<String>._(135),
  legacyCustomHeaders<String>._(127),
  legacyLoopVideo<bool>._(117),
  legacyLoadOriginalVideo<bool>._(136),
  legacyAutoPlayVideo<bool>._(139),
  legacyTapToNavigate<bool>._(141),
  legacyPreferRemoteImage<bool>._(116),
  legacyLoadOriginal<bool>._(101),
  legacyPrimaryColor<String>._(128),
  legacyDynamicTheme<bool>._(129),
  legacyColorfulInterface<bool>._(130),
  legacyThemeMode<String>._(102),
  legacyCleanupKeepFavorites<bool>._(1008),
  legacyCleanupKeepMediaType<int>._(1009),
  legacyCleanupKeepAlbumIds<String>._(1010),
  legacyCleanupCutoffDaysAgo<int>._(1011),
  legacyCleanupDefaultsInitialized<bool>._(1012),
  legacyTilesPerRow<int>._(103),
  legacyGroupAssetsBy<int>._(105),
  legacyStorageIndicator<bool>._(109),
  legacyMapRelativeDate<int>._(119),
  legacyMapShowFavoriteOnly<bool>._(118),
  legacyMapIncludeArchived<bool>._(121),
  legacyMapThemeMode<int>._(124),
  legacyMapwithPartners<bool>._(125),
  legacyLogLevel<int>._(115);

  const StoreKey._(this.id);
  final int id;
  Type get type => T;
}

class StoreDto<T> {
  final StoreKey<T> key;
  final T? value;

  const StoreDto(this.key, this.value);

  @override
  String toString() {
    return '''
StoreDto: {
  key: $key,
  value: ${value ?? '<NA>'},
}''';
  }

  @override
  bool operator ==(covariant StoreDto<T> other) {
    if (identical(this, other)) {
      return true;
    }

    return other.key == key && other.value == value;
  }

  @override
  int get hashCode => key.hashCode ^ value.hashCode;
}
