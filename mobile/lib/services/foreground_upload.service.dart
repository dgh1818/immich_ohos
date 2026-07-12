import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/asset_metadata.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart' hide AssetVisibility;
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/network_capability_extensions.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/infrastructure/repositories/backup.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/platform/connectivity_api.g.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/infrastructure/storage.provider.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:logging/logging.dart';
import 'package:openapi/api.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart' show AssetEntity, PMProgressHandler;

/// Callbacks for upload progress and status updates
class UploadCallbacks {
  final void Function(String id, String filename, int bytes, int totalBytes)? onProgress;
  final void Function(String localId, String remoteId)? onSuccess;
  final void Function(String id, String errorMessage)? onError;
  final void Function(String id, double progress)? onICloudProgress;

  const UploadCallbacks({this.onProgress, this.onSuccess, this.onError, this.onICloudProgress});
}

final foregroundUploadServiceProvider = Provider((ref) {
  return ForegroundUploadService(
    ref.watch(uploadRepositoryProvider),
    ref.watch(storageRepositoryProvider),
    ref.watch(backupRepositoryProvider),
    ref.watch(connectivityApiProvider),
    ref.watch(assetMediaRepositoryProvider),
  );
});

/// Service for handling foreground HTTP uploads
///
/// This service handles synchronous uploads using HTTP client with
/// concurrent worker pools. Used for manual backups, auto backups
/// (foreground mode), and share intent uploads.
class ForegroundUploadService {
  ForegroundUploadService(
    this._uploadRepository,
    this._storageRepository,
    this._backupRepository,
    this._connectivityApi,
    this._assetMediaRepository,
  );

  final UploadRepository _uploadRepository;
  final StorageRepository _storageRepository;
  final DriftBackupRepository _backupRepository;
  final ConnectivityApi _connectivityApi;
  final AssetMediaRepository _assetMediaRepository;
  final Logger _logger = Logger('ForegroundUploadService');

  bool shouldAbortUpload = false;

  Future<({int total, int remainder, int processing})> getBackupCounts(String userId) {
    return _backupRepository.getAllCounts(userId);
  }

  Future<List<LocalAsset>> getBackupCandidates(String userId, {bool onlyHashed = true}) {
    return _backupRepository.getCandidates(userId, onlyHashed: onlyHashed);
  }

  /// Bulk upload of backup candidates from selected albums
  Future<void> uploadCandidates(
    String userId,
    Completer<void> cancelToken, {
    UploadCallbacks callbacks = const UploadCallbacks(),
    bool useSequentialUpload = false,
  }) async {
    final candidates = await _backupRepository.getCandidates(userId);
    if (candidates.isEmpty) {
      return;
    }

    final networkCapabilities = await _connectivityApi.getCapabilities();
    final hasWifi = networkCapabilities.isUnmetered;
    _logger.info('Network capabilities: $networkCapabilities, hasWifi/isUnmetered: $hasWifi');

    if (useSequentialUpload) {
      await _uploadSequentially(items: candidates, cancelToken: cancelToken, hasWifi: hasWifi, callbacks: callbacks);
    } else {
      await _executeWithWorkerPool<LocalAsset>(
        items: candidates,
        cancelToken: cancelToken,
        shouldSkip: (asset) {
          final requireWifi = _shouldRequireWiFi(asset);
          return requireWifi && !hasWifi;
        },
        processItem: (asset) => _uploadSingleAsset(asset, cancelToken, callbacks: callbacks),
      );
    }
  }

  /// Sequential upload - used for background isolate where concurrent HTTP clients may cause issues
  Future<void> _uploadSequentially({
    required List<LocalAsset> items,
    required Completer<void> cancelToken,
    required bool hasWifi,
    required UploadCallbacks callbacks,
  }) async {
    await _storageRepository.clearCache();
    shouldAbortUpload = false;

    for (final asset in items) {
      if (shouldAbortUpload || cancelToken.isCompleted) {
        break;
      }

      final requireWifi = _shouldRequireWiFi(asset);
      if (requireWifi && !hasWifi) {
        _logger.warning('Skipping upload for ${asset.id} because it requires WiFi');
        continue;
      }

      await _uploadSingleAsset(asset, cancelToken, callbacks: callbacks);
    }
  }

  /// Manually upload picked local assets
  Future<void> uploadManual(
    List<LocalAsset> localAssets, {
    Completer<void>? cancelToken,
    UploadCallbacks callbacks = const UploadCallbacks(),
  }) async {
    if (localAssets.isEmpty) {
      return;
    }

    await _executeWithWorkerPool<LocalAsset>(
      items: localAssets,
      cancelToken: cancelToken,
      processItem: (asset) => _uploadSingleAsset(asset, cancelToken, callbacks: callbacks),
    );
  }

  /// Upload files from shared intent
  Future<void> uploadShareIntent(
    List<File> files, {
    Completer<void>? cancelToken,
    bool mergeOhosLivePhotos = false,
    void Function(String fileId, int bytes, int totalBytes)? onProgress,
    void Function(String fileId, String remoteAssetId)? onSuccess,
    void Function(String fileId, String errorMessage)? onError,
  }) async {
    if (files.isEmpty) {
      return;
    }

    final effectiveCancelToken = cancelToken ?? Completer<void>();

    final items = Platform.isOhos && mergeOhosLivePhotos
        ? _mergeOhosPickedLivePhotos(files)
        : files.map(_ShareIntentUploadItem.file).toList();

    await _executeWithWorkerPool<_ShareIntentUploadItem>(
      items: items,
      cancelToken: effectiveCancelToken,
      processItem: (item) async {
        final livePhotoPair = item.livePhotoPair;
        if (livePhotoPair != null) {
          await _uploadShareIntentLivePhotoPair(
            livePhotoPair,
            cancelToken: effectiveCancelToken,
            onProgress: onProgress,
            onSuccess: onSuccess,
            onError: onError,
          );
          return;
        }

        final file = item.file!;
        final originalPath = file.path;
        final fileId = p.hash(originalPath).toString();
        final resolvedFile = await _resolveShareIntentFile(file);
        if (resolvedFile == null) {
          onError?.call(fileId, "Unable to resolve shared file from URI");
          return;
        }

        final originalName = _fileNameFromUriOrPath(originalPath);
        try {
          final result = await _uploadSingleFile(
            resolvedFile,
            deviceAssetId: fileId,
            cancelToken: effectiveCancelToken,
            originalFileNameOverride: originalName,
            onProgress: (bytes, totalBytes) => onProgress?.call(fileId, bytes, totalBytes),
          );

          if (result.isSuccess) {
            onSuccess?.call(fileId, result.remoteAssetId!);
          } else if (!result.isCancelled && result.errorMessage != null) {
            onError?.call(fileId, result.errorMessage!);
          }
        } finally {
          await _cleanupShareIntentTempFile(originalPath, resolvedFile);
        }
      },
    );
  }

  Future<void> _uploadShareIntentLivePhotoPair(
    _OhosPickedLivePhotoPair pair, {
    required Completer<void> cancelToken,
    void Function(String fileId, int bytes, int totalBytes)? onProgress,
    void Function(String fileId, String remoteAssetId)? onSuccess,
    void Function(String fileId, String errorMessage)? onError,
  }) async {
    final imageOriginalPath = pair.image.path;
    final videoOriginalPath = pair.video.path;
    final imageFileId = p.hash(imageOriginalPath).toString();
    final videoFileId = p.hash(videoOriginalPath).toString();

    final imageFile = await _resolveShareIntentFile(pair.image);
    final videoFile = await _resolveShareIntentFile(pair.video);
    if (imageFile == null || videoFile == null) {
      onError?.call(imageFileId, "Unable to resolve live photo files from URI");
      onError?.call(videoFileId, "Unable to resolve live photo files from URI");
      return;
    }

    try {
      final imageStats = await imageFile.stat();
      final imageName = _fileNameFromUriOrPath(imageOriginalPath);
      final videoName = p.setExtension(imageName, p.extension(_fileNameFromUriOrPath(videoOriginalPath)));
      final fields = {
        // deviceAssetId/deviceId required by server v2.7.5 and below (drop in v4.0 per #27818).
        'deviceAssetId': imageFileId,
        'deviceId': Store.get(StoreKey.deviceId),
        'fileCreatedAt': imageStats.changed.toUtc().toIso8601String(),
        'fileModifiedAt': imageStats.modified.toUtc().toIso8601String(),
        'isFavorite': 'false',
        'duration': '0',
      };

      final videoResult = await _uploadRepository.uploadFile(
        file: videoFile,
        originalFileName: videoName,
        fields: fields,
        cancelToken: cancelToken,
        onProgress: (bytes, totalBytes) => onProgress?.call(videoFileId, bytes, totalBytes),
        logContext: 'shareLivePhotoVideo[$imageFileId]',
      );

      if (!videoResult.isSuccess || videoResult.remoteAssetId == null) {
        if (!videoResult.isCancelled && videoResult.errorMessage != null) {
          onError?.call(imageFileId, videoResult.errorMessage!);
          onError?.call(videoFileId, videoResult.errorMessage!);
        }
        return;
      }

      final imageResult = await _uploadRepository.uploadFile(
        file: imageFile,
        originalFileName: imageName,
        fields: {...fields, 'livePhotoVideoId': videoResult.remoteAssetId!},
        cancelToken: cancelToken,
        onProgress: (bytes, totalBytes) => onProgress?.call(imageFileId, bytes, totalBytes),
        logContext: 'shareLivePhotoImage[$imageFileId]',
      );

      if (imageResult.isSuccess && imageResult.remoteAssetId != null) {
        onSuccess?.call(videoFileId, videoResult.remoteAssetId!);
        onSuccess?.call(imageFileId, imageResult.remoteAssetId!);
      } else if (!imageResult.isCancelled && imageResult.errorMessage != null) {
        onError?.call(imageFileId, imageResult.errorMessage!);
        onError?.call(videoFileId, imageResult.errorMessage!);
      }
    } catch (e) {
      onError?.call(imageFileId, e.toString());
      onError?.call(videoFileId, e.toString());
    } finally {
      await _cleanupShareIntentTempFile(imageOriginalPath, imageFile);
      await _cleanupShareIntentTempFile(videoOriginalPath, videoFile);
    }
  }

  void cancel() {
    shouldAbortUpload = true;
  }

  /// Generic worker pool for concurrent uploads
  ///
  /// [items] - List of items to process
  /// [cancelToken] - Token to cancel the operation
  /// [processItem] - Function to process each item with an HTTP client
  /// [shouldSkip] - Optional function to skip items (e.g., WiFi requirement check)
  /// [concurrentWorkers] - Number of concurrent workers (default: 3)
  Future<void> _executeWithWorkerPool<T>({
    required List<T> items,
    required Completer<void>? cancelToken,
    required Future<void> Function(T item) processItem,
    bool Function(T item)? shouldSkip,
    int concurrentWorkers = 3,
  }) async {
    await _storageRepository.clearCache();
    shouldAbortUpload = false;

    int currentIndex = 0;

    Future<void> worker() async {
      while (true) {
        if (shouldAbortUpload || (cancelToken != null && cancelToken.isCompleted)) {
          break;
        }

        final index = currentIndex;
        if (index >= items.length) {
          break;
        }
        currentIndex++;

        final item = items[index];

        if (shouldSkip?.call(item) ?? false) {
          continue;
        }

        await processItem(item);
      }
    }

    final workerFutures = <Future<void>>[];
    for (int i = 0; i < concurrentWorkers; i++) {
      workerFutures.add(worker());
    }

    await Future.wait(workerFutures);
  }

  Future<void> _uploadSingleAsset(
    LocalAsset asset,
    Completer<void>? cancelToken, {
    required UploadCallbacks callbacks,
  }) async {
    File? file;
    File? livePhotoFile;

    try {
      final entity = await _storageRepository.getAssetEntityForAsset(asset);
      if (entity == null) {
        callbacks.onError?.call(
          asset.localId!,
          CurrentPlatform.isAndroid ? "asset_not_found_on_device_android".t() : "asset_not_found_on_device_ios".t(),
        );
        return;
      }

      final isAvailableLocally = await _storageRepository.isAssetAvailableLocally(asset.id);

      if (!isAvailableLocally && (CurrentPlatform.isIOS || Platform.isOhos)) {
        _logger.info("Loading iCloud asset ${asset.id} - ${asset.name}");

        // Create progress handler for iCloud download
        PMProgressHandler? progressHandler;
        StreamSubscription? progressSubscription;

        progressHandler = PMProgressHandler();
        progressSubscription = progressHandler.stream.listen((event) {
          callbacks.onICloudProgress?.call(asset.localId!, event.progress);
        });

        try {
          file = await _storageRepository.loadFileFromCloud(asset.id, progressHandler: progressHandler);
          if (entity.isLivePhoto) {
            livePhotoFile = await _storageRepository.loadMotionFileFromCloud(
              asset.id,
              progressHandler: progressHandler,
            );
          }
        } finally {
          await progressSubscription.cancel();
        }
      } else {
        // Get files locally
        file = await _storageRepository.getFileForAsset(asset.id);
        if (file == null) {
          _logger.warning("Failed to get file ${asset.id} - ${asset.name}");
          callbacks.onError?.call(
            asset.localId!,
            CurrentPlatform.isAndroid ? "asset_not_found_on_device_android".t() : "asset_not_found_on_device_ios".t(),
          );
          return;
        }

        // For live photos, get the motion video file
        if (entity.isLivePhoto) {
          livePhotoFile = await _storageRepository.getMotionFileForAsset(asset);
          if (livePhotoFile == null) {
            _logger.warning("Failed to obtain motion part of the livePhoto - ${asset.name}");
            callbacks.onError?.call(
              asset.localId!,
              CurrentPlatform.isAndroid ? "asset_not_found_on_device_android".t() : "asset_not_found_on_device_ios".t(),
            );
          }
        }
      }

      if (file == null) {
        _logger.warning("Failed to obtain file from iCloud for asset ${asset.id} - ${asset.name}");
        callbacks.onError?.call(asset.localId!, "asset_not_found_on_icloud".t());
        return;
      }

      String fileName = await _assetMediaRepository.getOriginalFilename(asset.id) ?? asset.name;
      /// Handle special file name from DJI or Fusion app
      /// If the file name has no extension, likely due to special renaming template by specific apps
      /// we append the original extension from the asset name
      final hasExtension = p.extension(fileName).isNotEmpty;
      if (!hasExtension) {
        fileName = p.setExtension(fileName, p.extension(asset.name));
      }

      final originalFileName = entity.isLivePhoto ? p.setExtension(fileName, p.extension(file.path)) : fileName;
      final deviceId = Store.get(StoreKey.deviceId);

      final fields = {
        // deviceAssetId/deviceId required by server v2.7.5 and below (drop in v4.0 per #27818).
        'deviceAssetId': asset.localId!,
        'deviceId': deviceId,
        'fileCreatedAt': asset.createdAt.toUtc().toIso8601String(),
        'fileModifiedAt': asset.updatedAt.toUtc().toIso8601String(),
        'isFavorite': asset.isFavorite.toString(),
        'duration': (asset.durationMs ?? 0).toString(),
      };

      // Upload live photo video first if available
      String? livePhotoVideoId;
      if (entity.isLivePhoto && livePhotoFile != null) {
        final livePhotoTitle = p.setExtension(originalFileName, p.extension(livePhotoFile.path));

        final onProgress = callbacks.onProgress;
        final livePhotoResult = await _uploadRepository.uploadFile(
          file: livePhotoFile,
          originalFileName: livePhotoTitle,
          // Visibility hidden on upload to prevent the server from running regular jobs on the live photo asset
          fields: {...fields, 'visibility': AssetVisibility.hidden.value},
          cancelToken: cancelToken,
          onProgress: onProgress != null
              ? (bytes, totalBytes) => onProgress(asset.localId!, livePhotoTitle, bytes, totalBytes)
              : null,
          logContext: 'livePhotoVideo[${asset.localId}]',
        );

        if (livePhotoResult.isSuccess && livePhotoResult.remoteAssetId != null) {
          livePhotoVideoId = livePhotoResult.remoteAssetId;
        }
      }

      if (livePhotoVideoId != null) {
        fields['livePhotoVideoId'] = livePhotoVideoId;
      }

      // Add cloudId metadata only to the still image, not the motion video, becasue when the sync id happens, the motion video can get associated with the wrong still image.
      if ((CurrentPlatform.isIOS || Platform.isOhos) && asset.cloudId != null) {
        fields['metadata'] = jsonEncode([
          RemoteAssetMetadataItem(
            key: RemoteAssetMetadataKey.mobileApp,
            value: RemoteAssetMobileAppMetadata(
              cloudId: asset.cloudId,
              createdAt: asset.createdAt.toIso8601String(),
              adjustmentTime: asset.adjustmentTime?.toIso8601String(),
              latitude: asset.latitude?.toString(),
              longitude: asset.longitude?.toString(),
            ),
          ),
        ]);
      }

      final onProgress = callbacks.onProgress;
      final result = await _uploadRepository.uploadFile(
        file: file,
        originalFileName: originalFileName,
        fields: fields,
        cancelToken: cancelToken,
        onProgress: onProgress != null
            ? (bytes, totalBytes) => onProgress(asset.localId!, originalFileName, bytes, totalBytes)
            : null,
        logContext: 'asset[${asset.localId}]',
      );

      if (result.isSuccess && result.remoteAssetId != null) {
        callbacks.onSuccess?.call(asset.localId!, result.remoteAssetId!);
      } else if (result.isCancelled) {
        _logger.warning(() => "Backup was cancelled by the user");
        shouldAbortUpload = true;
      } else if (result.errorMessage != null) {
        _logger.severe(
          () =>
              "Error(${result.statusCode}) uploading ${asset.localId} | $originalFileName | Created on ${asset.createdAt} | ${result.errorMessage}",
        );

        callbacks.onError?.call(asset.localId!, result.errorMessage!);

        if (result.errorMessage == "Quota has been exceeded!") {
          shouldAbortUpload = true;
        }
      }
    } catch (error, stackTrace) {
      _logger.severe(() => "Error backup asset: ${error.toString()}", stackTrace);
      callbacks.onError?.call(asset.localId!, error.toString());
    } finally {
      if (Platform.isIOS) {
        try {
          await file?.delete();
          await livePhotoFile?.delete();
        } catch (error, stackTrace) {
          _logger.severe(() => "ERROR deleting file: ${error.toString()}", stackTrace);
        }
      }
      // On OHOS the file path points to the media library and is not accessible
      // from Dart's dart:io. The media library manages its own lifecycle, so
      // there is nothing to clean up here.
      if (Platform.isOhos) {
        try {
          await livePhotoFile?.delete();
        } catch (error, stackTrace) {
          _logger.severe(() => "ERROR deleting file: ${error.toString()}", stackTrace);
        }
      }
    }
  }

  Future<UploadResult> _uploadSingleFile(
    File file, {
    required String deviceAssetId,
    required Completer<void>? cancelToken,
    String? originalFileNameOverride,
    void Function(int bytes, int totalBytes)? onProgress,
  }) async {
    try {
      final stats = await file.stat();
      final fileCreatedAt = stats.changed;
      final fileModifiedAt = stats.modified;
      final filename = (originalFileNameOverride?.isNotEmpty ?? false)
          ? originalFileNameOverride!
          : p.basename(file.path);

      final fields = {
        // deviceAssetId/deviceId required by server v2.7.5 and below (drop in v4.0 per #27818).
        'deviceAssetId': deviceAssetId,
        'deviceId': Store.get(StoreKey.deviceId),
        'fileCreatedAt': fileCreatedAt.toUtc().toIso8601String(),
        'fileModifiedAt': fileModifiedAt.toUtc().toIso8601String(),
        'isFavorite': 'false',
        'duration': '0',
      };

      return await _uploadRepository.uploadFile(
        file: file,
        originalFileName: filename,
        fields: fields,
        cancelToken: cancelToken,
        onProgress: onProgress,
        logContext: 'shareIntent[$deviceAssetId]',
      );
    } catch (e) {
      return UploadResult.error(errorMessage: e.toString());
    }
  }

  bool _shouldRequireWiFi(LocalAsset asset) {
    final backup = SettingsRepository.instance.appConfig.backup;
    if (asset.isVideo && backup.useCellularForVideos) {
      return false;
    }
    if (!asset.isVideo && backup.useCellularForPhotos) {
      return false;
    }
    return true;
  }

  Future<File?> _resolveShareIntentFile(File file) async {
    try {
      if (await file.exists()) {
        return file;
      }
    } catch (_) {}

    final rawPath = file.path;
    final uri = Uri.tryParse(rawPath);
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'content' || uri.scheme == 'file') {
      final entity = await AssetEntity.fromId(rawPath);
      final resolved = await entity?.originFile;
      if (resolved != null) {
        return resolved;
      }
    }

    if (uri.scheme == 'file') {
      final realPath = uri.toFilePath(windows: false);
      final realFile = File(realPath);
      if (await realFile.exists()) {
        return realFile;
      }
    }

    return null;
  }

  String _fileNameFromUriOrPath(String rawPath) {
    final uri = Uri.tryParse(rawPath);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return p.basename(rawPath);
  }

  Future<void> _cleanupShareIntentTempFile(String originalPath, File resolvedFile) async {
    try {
      if (resolvedFile.path == originalPath) {
        return;
      }

      final uri = Uri.tryParse(originalPath);
      if (uri == null || (uri.scheme != 'content' && uri.scheme != 'file')) {
        return;
      }

      final normalizedPath = resolvedFile.path.replaceAll('\\', '/');
      if (!normalizedPath.contains('/photo_manager/')) {
        return;
      }

      if (await resolvedFile.exists()) {
        await resolvedFile.delete();
      }

      final parent = resolvedFile.parent;
      if (await parent.exists() && await parent.list().isEmpty) {
        await parent.delete();
      }
    } catch (_) {}
  }

  List<_ShareIntentUploadItem> _mergeOhosPickedLivePhotos(List<File> files) {
    final candidates = <String, List<File>>{};
    for (final file in files) {
      final key = _ohosPickedLivePhotoKey(file);
      if (key == null) {
        continue;
      }
      candidates.putIfAbsent(key, () => []).add(file);
    }

    final pairs = <String, _OhosPickedLivePhotoPair>{};
    for (final entry in candidates.entries) {
      final images = entry.value.where(_isOhosPickedImage).toList();
      final videos = entry.value.where(_isOhosPickedLivePhotoVideo).toList();
      if (images.length == 1 && videos.length == 1) {
        pairs[entry.key] = _OhosPickedLivePhotoPair(image: images.single, video: videos.single);
      }
    }

    final items = <_ShareIntentUploadItem>[];
    final emittedPairs = <String>{};
    for (final file in files) {
      final key = _ohosPickedLivePhotoKey(file);
      final pair = key == null ? null : pairs[key];
      if (pair == null) {
        items.add(_ShareIntentUploadItem.file(file));
      } else if (emittedPairs.add(key!)) {
        items.add(_ShareIntentUploadItem.livePhotoPair(pair));
      }
    }
    return items;
  }

  String? _ohosPickedLivePhotoKey(File file) {
    final name = _fileNameFromUriOrPath(file.path);
    final extension = p.extension(name).toLowerCase();
    if (!_ohosPickedImageExtensions.contains(extension) && extension != '.mp4') {
      return null;
    }
    return p.basenameWithoutExtension(name).toLowerCase();
  }

  bool _isOhosPickedImage(File file) {
    return _ohosPickedImageExtensions.contains(p.extension(_fileNameFromUriOrPath(file.path)).toLowerCase());
  }

  bool _isOhosPickedLivePhotoVideo(File file) {
    return p.extension(_fileNameFromUriOrPath(file.path)).toLowerCase() == '.mp4';
  }
}

const _ohosPickedImageExtensions = {'.jpg', '.jpeg', '.heic', '.heif', '.png', '.webp'};

class _ShareIntentUploadItem {
  final File? file;
  final _OhosPickedLivePhotoPair? livePhotoPair;

  const _ShareIntentUploadItem.file(this.file) : livePhotoPair = null;
  const _ShareIntentUploadItem.livePhotoPair(this.livePhotoPair) : file = null;
}

class _OhosPickedLivePhotoPair {
  final File image;
  final File video;

  const _OhosPickedLivePhotoPair({required this.image, required this.video});
}
