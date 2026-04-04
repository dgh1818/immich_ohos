import 'package:immich_mobile/constants/colors.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';

import 'package:flutter/material.dart';

enum AppSettingsEnum<T> {
  loadPreview<bool>(StoreKey.loadPreview, "loadPreview", false),
  loadOriginal<bool>(StoreKey.loadOriginal, "loadOriginal", true),
  themeMode<String>(StoreKey.themeMode, "themeMode", "system"), // "light","dark","system"
  primaryColor<String>(StoreKey.primaryColor, "primaryColor", defaultColorPresetName),
  dynamicTheme<bool>(StoreKey.dynamicTheme, "dynamicTheme", false),
  colorfulInterface<bool>(StoreKey.colorfulInterface, "colorfulInterface", true),
  tilesPerRow<int>(StoreKey.tilesPerRow, "tilesPerRow", 3),
  dynamicLayout<bool>(StoreKey.dynamicLayout, "dynamicLayout", false),
  groupAssetsBy<int>(StoreKey.groupAssetsBy, "groupBy", 0),
  uploadErrorNotificationGracePeriod<int>(
    StoreKey.uploadErrorNotificationGracePeriod,
    "uploadErrorNotificationGracePeriod",
    2,
  ),
  backgroundBackupTotalProgress<bool>(StoreKey.backgroundBackupTotalProgress, "backgroundBackupTotalProgress", true),
  backgroundBackupSingleProgress<bool>(
    StoreKey.backgroundBackupSingleProgress,
    "backgroundBackupSingleProgress",
    false,
  ),
  storageIndicator<bool>(StoreKey.storageIndicator, "storageIndicator", true),
  thumbnailCacheSize<int>(StoreKey.thumbnailCacheSize, "thumbnailCacheSize", 10000),
  imageCacheSize<int>(StoreKey.imageCacheSize, "imageCacheSize", 350),
  albumThumbnailCacheSize<int>(StoreKey.albumThumbnailCacheSize, "albumThumbnailCacheSize", 200),
  selectedAlbumSortOrder<int>(StoreKey.selectedAlbumSortOrder, "selectedAlbumSortOrder", 2),
  advancedTroubleshooting<bool>(StoreKey.advancedTroubleshooting, null, false),
  manageLocalMediaAndroid<bool>(StoreKey.manageLocalMediaAndroid, null, false),
  logLevel<int>(StoreKey.logLevel, null, 5), // Level.INFO = 5
  preferRemoteImage<bool>(StoreKey.preferRemoteImage, null, true),
  loopVideo<bool>(StoreKey.loopVideo, "loopVideo", true),
  loadOriginalVideo<bool>(StoreKey.loadOriginalVideo, "loadOriginalVideo", true),
  autoPlayVideo<bool>(StoreKey.autoPlayVideo, "autoPlayVideo", true),
  imageHdr<bool>(StoreKey.imageHdr, "imageHdr", true),
  videoHdr<bool>(StoreKey.videoHdr, "videoHdr", true),
  tapToNavigate<bool>(StoreKey.tapToNavigate, "tapToNavigate", false),
  mapThemeMode<int>(StoreKey.mapThemeMode, null, 0),
  mapShowFavoriteOnly<bool>(StoreKey.mapShowFavoriteOnly, null, false),
  mapIncludeArchived<bool>(StoreKey.mapIncludeArchived, null, false),
  mapwithPartners<bool>(StoreKey.mapwithPartners, null, false),
  mapRelativeDate<int>(StoreKey.mapRelativeDate, null, 0),
  allowSelfSignedSSLCert<bool>(StoreKey.selfSignedCert, null, false),
  ignoreIcloudAssets<bool>(StoreKey.ignoreIcloudAssets, null, true),
  selectedAlbumSortReverse<bool>(StoreKey.selectedAlbumSortReverse, null, true),
  enableHapticFeedback<bool>(StoreKey.enableHapticFeedback, null, false),
  syncAlbums<bool>(StoreKey.syncAlbums, null, false),
  autoEndpointSwitching<bool>(StoreKey.autoEndpointSwitching, null, false),
  photoManagerCustomFilter<bool>(StoreKey.photoManagerCustomFilter, null, true),
  betaTimeline<bool>(StoreKey.betaTimeline, null, true),
  enableBackup<bool>(StoreKey.enableBackup, null, false),
  useCellularForUploadVideos<bool>(StoreKey.useWifiForUploadVideos, null, false),
  useCellularForUploadPhotos<bool>(StoreKey.useWifiForUploadPhotos, null, false),
  readonlyModeEnabled<bool>(StoreKey.readonlyModeEnabled, "readonlyModeEnabled", false),
  albumGridView<bool>(StoreKey.albumGridView, "albumGridView", false),
  backupRequireCharging<bool>(StoreKey.backupRequireCharging, null, false),
  backupTriggerDelay<int>(StoreKey.backupTriggerDelay, null, 30),
  cleanupKeepFavorites<bool>(StoreKey.cleanupKeepFavorites, null, true),
  cleanupKeepMediaType<int>(StoreKey.cleanupKeepMediaType, null, 0),
  cleanupKeepAlbumIds<String>(StoreKey.cleanupKeepAlbumIds, null, ""),
  cleanupCutoffDaysAgo<int>(StoreKey.cleanupCutoffDaysAgo, null, -1),
  cleanupDefaultsInitialized<bool>(StoreKey.cleanupDefaultsInitialized, null, false),
  hybridArkuiPhotos<bool>(StoreKey.hybridArkuiPhotos, null, false);

  const AppSettingsEnum(this.storeKey, this.hiveKey, this.defaultValue);

  final StoreKey<T> storeKey;
  final String? hiveKey;
  final T defaultValue;
}

class AppSettingsService {
  const AppSettingsService();
  T getSetting<T>(AppSettingsEnum<T> setting, {BuildContext? context}) {
    if (setting == AppSettingsEnum.tilesPerRow) {
      final T runtimeDefault = _tilesPerRowDefault(context) as T;
      return Store.get(setting.storeKey, runtimeDefault);
    }

    return Store.get(setting.storeKey, setting.defaultValue);
  }

  Future<void> setSetting<T>(AppSettingsEnum<T> setting, T value) {
    return Store.put(setting.storeKey, value);
  }

  int _tilesPerRowDefault(BuildContext? context) {
    // 如果没有传 context，就退回 enum 中的默认值（保持原有行为）
    if (context == null) {
      return AppSettingsEnum.tilesPerRow.defaultValue;
    }

    try {
      final dynamic maybeIsMobile = (context as dynamic).isMobile;
      if (maybeIsMobile is bool) {
        return maybeIsMobile ? 3 : 6; // 手机 6，平板 8（可按需调整）
      }
    } catch (_) {
      // 忽略异常，继续使用 MediaQuery 回退检测
    }

    // 常用的平板检测：最短边 >= 600 认为是平板/大屏
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    final isMobile = shortestSide < 600;
    return isMobile ? 3 : 6;
  }
}
