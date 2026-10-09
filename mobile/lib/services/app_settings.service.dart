import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';

import 'package:flutter/material.dart';

enum AppSettingsEnum<T> {
  loadPreview<bool>(StoreKey.loadPreview, false),
  loadOriginal<bool>(StoreKey.loadOriginal, true),
  themeMode<String>(StoreKey.themeMode, "system"), // "light","dark","system"
  primaryColor<String>(StoreKey.primaryColor, "indigo"),
  dynamicTheme<bool>(StoreKey.dynamicTheme, false),
  colorfulInterface<bool>(StoreKey.colorfulInterface, true),
  tilesPerRow<int>(StoreKey.tilesPerRow, 3),
  dynamicLayout<bool>(StoreKey.dynamicLayout, false),
  groupAssetsBy<int>(StoreKey.groupAssetsBy, 0),
  uploadErrorNotificationGracePeriod<int>(StoreKey.uploadErrorNotificationGracePeriod, 2),
  backgroundBackupTotalProgress<bool>(StoreKey.backgroundBackupTotalProgress, true),
  backgroundBackupSingleProgress<bool>(StoreKey.backgroundBackupSingleProgress, false),
  storageIndicator<bool>(StoreKey.storageIndicator, true),
  thumbnailCacheSize<int>(StoreKey.thumbnailCacheSize, 10000),
  imageCacheSize<int>(StoreKey.imageCacheSize, 350),
  albumThumbnailCacheSize<int>(StoreKey.albumThumbnailCacheSize, 200),
  selectedAlbumSortOrder<int>(StoreKey.selectedAlbumSortOrder, 2),
  advancedTroubleshooting<bool>(StoreKey.advancedTroubleshooting, false),
  manageLocalMediaAndroid<bool>(StoreKey.manageLocalMediaAndroid, false),
  logLevel<int>(StoreKey.logLevel, 5), // Level.INFO = 5
  preferRemoteImage<bool>(StoreKey.preferRemoteImage, true),
  loopVideo<bool>(StoreKey.loopVideo, true),
  loadOriginalVideo<bool>(StoreKey.loadOriginalVideo, true),
  autoPlayVideo<bool>(StoreKey.autoPlayVideo, true),
  imageHdr<bool>(StoreKey.imageHdr, true),
  videoHdr<bool>(StoreKey.videoHdr, true),
  aiHdr<bool>(StoreKey.aiHdr, true),
  tapToNavigate<bool>(StoreKey.tapToNavigate, false),
  mapThemeMode<int>(StoreKey.mapThemeMode, 0),
  mapShowFavoriteOnly<bool>(StoreKey.mapShowFavoriteOnly, false),
  mapIncludeArchived<bool>(StoreKey.mapIncludeArchived, false),
  mapwithPartners<bool>(StoreKey.mapwithPartners, false),
  mapRelativeDate<int>(StoreKey.mapRelativeDate, 0),
  ignoreIcloudAssets<bool>(StoreKey.ignoreIcloudAssets, true),
  selectedAlbumSortReverse<bool>(StoreKey.selectedAlbumSortReverse, true),
  enableHapticFeedback<bool>(StoreKey.enableHapticFeedback, true),
  syncAlbums<bool>(StoreKey.syncAlbums, true),
  autoEndpointSwitching<bool>(StoreKey.autoEndpointSwitching, false),
  photoManagerCustomFilter<bool>(StoreKey.photoManagerCustomFilter, true),
  betaTimeline<bool>(StoreKey.betaTimeline, true),
  enableBackup<bool>(StoreKey.enableBackup, false),
  useCellularForUploadVideos<bool>(StoreKey.useWifiForUploadVideos, false),
  useCellularForUploadPhotos<bool>(StoreKey.useWifiForUploadPhotos, false),
  readonlyModeEnabled<bool>(StoreKey.readonlyModeEnabled, false),
  albumGridView<bool>(StoreKey.albumGridView, false),
  backupRequireCharging<bool>(StoreKey.backupRequireCharging, false),
  backupTriggerDelay<int>(StoreKey.backupTriggerDelay, 30),
  cleanupKeepFavorites<bool>(StoreKey.cleanupKeepFavorites, true),
  cleanupKeepMediaType<int>(StoreKey.cleanupKeepMediaType, 0),
  cleanupKeepAlbumIds<String>(StoreKey.cleanupKeepAlbumIds, ""),
  cleanupCutoffDaysAgo<int>(StoreKey.cleanupCutoffDaysAgo, -1),
  cleanupDefaultsInitialized<bool>(StoreKey.cleanupDefaultsInitialized, false);

  const AppSettingsEnum(this.storeKey, this.defaultValue);

  final StoreKey<T> storeKey;
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
