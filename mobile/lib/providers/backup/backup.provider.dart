import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/string_extensions.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/sync_status.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/services/background_upload.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/utils/upload_speed_calculator.dart';
import 'package:logging/logging.dart';

part 'backup.provider.freezed.dart';

@freezed
abstract class EnqueueStatus with _$EnqueueStatus {
  const factory EnqueueStatus({required int enqueueCount, required int totalCount}) = _EnqueueStatus;
}

@freezed
abstract class UploadStatus with _$UploadStatus {
  const factory UploadStatus({
    required String taskId,
    required String filename,
    required double progress,
    required int fileSize,
    required String networkSpeedAsString,
    bool? isFailed,
    String? error,
  }) = _UploadStatus;
}

enum BackupError { none, syncFailed }

@freezed
abstract class BackupState with _$BackupState {
  const BackupState._();

  const factory BackupState({
    required int totalCount,
    required int backupCount,
    required int remainderCount,
    required int processingCount,
    required bool isSyncing,
    @Default(BackupError.none) BackupError error,
    required Map<String, UploadStatus> uploadItems,
    @Default({}) Map<String, double> iCloudDownloadProgress,
  }) = _BackupState;

  int get errorCount => uploadItems.values.where((item) => item.isFailed == true).length;
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier(
    ref.watch(foregroundUploadServiceProvider),
    ref.watch(backgroundUploadServiceProvider),
    UploadSpeedManager(),
    ref,
  );
});

class BackupNotifier extends StateNotifier<BackupState> {
  BackupNotifier(this._foregroundUploadService, this._backgroundUploadService, this._uploadSpeedManager, [this._ref])
    : _nativeSyncApi = _ref?.read(nativeSyncApiProvider) ?? NativeSyncApiOhos(),
      super(
        const BackupState(
          totalCount: 0,
          backupCount: 0,
          remainderCount: 0,
          processingCount: 0,
          isSyncing: false,
          uploadItems: {},
          error: BackupError.none,
        ),
      ) {
    _backgroundStatusSubscription = _backgroundUploadService.taskStatusStream.listen(_handleBackgroundTaskStatusUpdate);
    _backgroundProgressSubscription = _backgroundUploadService.taskProgressStream.listen(
      _handleBackgroundTaskProgressUpdate,
    );
  }

  final ForegroundUploadService _foregroundUploadService;
  final BackgroundUploadService _backgroundUploadService;
  final UploadSpeedManager _uploadSpeedManager;
  final Ref? _ref;
  final NativeSyncApiOhos _nativeSyncApi;
  Completer<void>? _cancelToken;
  StreamSubscription<TaskStatusUpdate>? _backgroundStatusSubscription;
  StreamSubscription<TaskProgressUpdate>? _backgroundProgressSubscription;
  bool _backgroundEnqueueCompleted = false;

  final _logger = Logger("BackupNotifier");
  static const String _ohosBackupTitle = '正在上传媒体';

  Future<void> _startOhosBackgroundTransfer() async {
    if (!Platform.isOhos) {
      return;
    }
    try {
      await _nativeSyncApi.startBackgroundTransfer();
    } catch (_) {
      // Keep the upload path alive if the OHOS long-running task cannot start.
    }
  }

  Future<void> _stopOhosBackgroundTransfer({bool checkActiveTasks = true}) async {
    if (!Platform.isOhos) {
      return;
    }
    // HashService owns the continuous task while hashing is active.
    if (_ref?.read(syncStatusProvider).isHashing == true) {
      return;
    }
    if (checkActiveTasks) {
      final backupTasks = await _backgroundUploadService.getActiveTasks(kBackupGroup);
      final livePhotoTasks = await _backgroundUploadService.getActiveTasks(kBackupLivePhotoGroup);
      if (backupTasks.isNotEmpty || livePhotoTasks.isNotEmpty) {
        return;
      }
    }
    try {
      await _nativeSyncApi.stopBackgroundTransfer();
    } catch (_) {
      // Ignore cleanup failures on OHOS.
    }
  }

  void _updateOhosBackgroundTransferProgress(double progressPercent, String filename) {
    if (!Platform.isOhos) {
      return;
    }
    try {
      unawaited(_nativeSyncApi.updateBackgroundTransferProgress(progressPercent, _ohosBackupTitle, filename));
    } catch (_) {
      // Ignore progress failures on OHOS.
    }
  }

  void _handleBackgroundTaskStatusUpdate(TaskStatusUpdate update) {
    if (!mounted) {
      _logger.warning("Skip _handleBackgroundTaskStatusUpdate: notifier disposed");
      return;
    }
    final taskId = update.task.taskId;
    switch (update.status) {
      case TaskStatus.complete:
        if (update.task.group == kBackupGroup && update.responseStatusCode == 201) {
          state = state.copyWith(backupCount: state.backupCount + 1, remainderCount: state.remainderCount - 1);
          final total = state.totalCount > 0 ? state.totalCount : state.backupCount + state.remainderCount;
          if (total > 0) {
            final progressPercent = ((state.backupCount / total) * 100).clamp(0.0, 100.0);
            final name = update.task.displayName.isNotEmpty ? update.task.displayName : update.task.filename;
            _updateOhosBackgroundTransferProgress(progressPercent, name);
          }
        }
        if (state.uploadItems.containsKey(taskId)) {
          Future.delayed(const Duration(milliseconds: 1000), () => _removeUploadItem(taskId));
        }
        break;
      case TaskStatus.failed:
        if (update.exception?.description == 'Delayed or retried enqueue failed') {
          _removeUploadItem(taskId);
          return;
        }
        final currentItem = state.uploadItems[taskId];
        if (currentItem == null) {
          return;
        }
        String? error;
        final exception = update.exception;
        if (exception is TaskHttpException) {
          final message = tryJsonDecode(exception.description)?['message'] as String?;
          if (message != null) {
            error = "${exception.exceptionType}, response code ${exception.httpResponseCode}: $message";
          }
        }
        error ??= update.exception?.toString();
        state = state.copyWith(
          uploadItems: {
            ...state.uploadItems,
            taskId: currentItem.copyWith(isFailed: true, error: error),
          },
        );
        _logger.fine("Upload failed for taskId: $taskId, exception: ${update.exception}");
        break;
      case TaskStatus.canceled:
        _removeUploadItem(taskId);
        break;
      default:
        break;
    }

    if (Platform.isOhos &&
        _backgroundEnqueueCompleted &&
        (update.task.group == kBackupGroup || update.task.group == kBackupLivePhotoGroup) &&
        (update.status == TaskStatus.complete ||
            update.status == TaskStatus.failed ||
            update.status == TaskStatus.canceled)) {
      var isLivePhotoVideo = false;
      if (update.status == TaskStatus.complete && update.task.metaData.isNotEmpty) {
        try {
          isLivePhotoVideo = UploadTaskMetadata.fromJson(update.task.metaData).isLivePhotos;
        } catch (_) {
          // Ignore malformed task metadata.
        }
      }
      if (!isLivePhotoVideo) {
        unawaited(() async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await _stopOhosBackgroundTransfer();
        }());
      }
    }
  }

  void _handleBackgroundTaskProgressUpdate(TaskProgressUpdate update) {
    if (!mounted) {
      _logger.warning("Skip _handleBackgroundTaskProgressUpdate: notifier disposed");
      return;
    }
    final taskId = update.task.taskId;
    final filename = update.task.displayName;
    final currentItem = state.uploadItems[taskId];
    if (currentItem != null) {
      if (update.progress == progressCanceled) {
        _removeUploadItem(taskId);
        return;
      }
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          taskId: update.hasExpectedFileSize
              ? currentItem.copyWith(
                  progress: update.progress,
                  fileSize: update.expectedFileSize,
                  networkSpeedAsString: update.networkSpeedAsString,
                )
              : currentItem.copyWith(progress: update.progress),
        },
      );
    } else {
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          taskId: UploadStatus(
            taskId: taskId,
            filename: filename,
            progress: update.progress,
            fileSize: update.expectedFileSize,
            networkSpeedAsString: update.networkSpeedAsString,
          ),
        },
      );
    }

    if (Platform.isOhos &&
        (update.task.group == kBackupGroup || update.task.group == kBackupLivePhotoGroup) &&
        update.progress >= 0) {
      final total = state.totalCount > 0 ? state.totalCount : state.backupCount + state.remainderCount;
      if (total > 0) {
        final overallProgress = (((state.backupCount + update.progress.clamp(0.0, 1.0)) / total) * 100).clamp(
          0.0,
          100.0,
        );
        _updateOhosBackgroundTransferProgress(overallProgress, filename.isNotEmpty ? filename : update.task.filename);
      }
    }
  }

  /// Remove upload item from state
  void _removeUploadItem(String taskId) {
    if (!mounted) {
      _logger.warning("Skip _removeUploadItem: notifier disposed");
      return;
    }
    if (state.uploadItems.containsKey(taskId)) {
      final updatedItems = Map<String, UploadStatus>.from(state.uploadItems);
      updatedItems.remove(taskId);
      state = state.copyWith(uploadItems: updatedItems);
    }
  }

  Future<void> getBackupStatus(String userId) async {
    if (!mounted) {
      _logger.warning("Skip getBackupStatus (pre-call): notifier disposed");
      return;
    }
    final counts = await _foregroundUploadService.getBackupCounts(userId);
    if (!mounted) {
      _logger.warning("Skip getBackupStatus (post-call): notifier disposed");
      return;
    }

    state = state.copyWith(
      totalCount: counts.total,
      backupCount: counts.total - counts.remainder,
      remainderCount: counts.remainder,
      processingCount: counts.processing,
    );
  }

  void updateError(BackupError error) {
    if (!mounted) {
      _logger.warning("Skip updateError: notifier disposed");
      return;
    }
    state = state.copyWith(error: error);
  }

  void updateSyncing(bool isSyncing) {
    state = state.copyWith(isSyncing: isSyncing);
  }

  Future<void> startForegroundBackup(String userId) async {
    if (_cancelToken != null && !_cancelToken!.isCompleted) {
      _logger.info("Skip startForegroundBackup: backup is already starting or running");
      return;
    }

    _backgroundEnqueueCompleted = false;
    state = state.copyWith(error: BackupError.none);

    // Re-baseline the counters against the same DB read that feeds this run's candidate list,
    // otherwise a resume counts duplicate successes against the old baseline (#26215).
    await getBackupStatus(userId);
    if (Platform.isOhos || Platform.isIOS) {
      final backupTasks = await _backgroundUploadService.getActiveTasks(kBackupGroup);
      final livePhotoTasks = await _backgroundUploadService.getActiveTasks(kBackupLivePhotoGroup);
      if (backupTasks.isNotEmpty || livePhotoTasks.isNotEmpty) {
        _backgroundEnqueueCompleted = true;
        await _startOhosBackgroundTransfer();
        await _backgroundUploadService.resume();
        _logger.info("Skip startForegroundBackup: resumed existing background upload tasks");
        return;
      }
    }

    final cancelToken = Completer<void>();
    _cancelToken = cancelToken;
    await _startOhosBackgroundTransfer();

    try {
      await _foregroundUploadService.uploadCandidates(
        userId,
        cancelToken,
        callbacks: UploadCallbacks(
          onProgress: _handleForegroundBackupProgress,
          onSuccess: _handleForegroundBackupSuccess,
          onError: _handleForegroundBackupError,
          onICloudProgress: _handleICloudProgress,
        ),
      );
    } finally {
      _cancelToken = null;
      if (mounted) {
        unawaited(_stopOhosBackgroundTransfer(checkActiveTasks: false));
      }
    }
  }

  Future<void> stopForegroundBackup({String reason = "backup stopped"}) async {
    if (_cancelToken != null) {
      _logger.info("Foreground backup cancelled: $reason");
    }
    if (_cancelToken != null && !_cancelToken!.isCompleted) {
      _cancelToken!.complete();
    }
    _cancelToken = null;
    _backgroundEnqueueCompleted = false;
    _uploadSpeedManager.clear();
    state = state.copyWith(uploadItems: {}, iCloudDownloadProgress: {});
    unawaited(_stopOhosBackgroundTransfer(checkActiveTasks: false));
  }

  void _handleICloudProgress(String localAssetId, double progress) {
    state = state.copyWith(iCloudDownloadProgress: {...state.iCloudDownloadProgress, localAssetId: progress});

    if (progress >= 1.0) {
      Future.delayed(const Duration(milliseconds: 250), () {
        final updatedProgress = Map<String, double>.from(state.iCloudDownloadProgress);
        updatedProgress.remove(localAssetId);
        state = state.copyWith(iCloudDownloadProgress: updatedProgress);
      });
    }
  }

  void _handleForegroundBackupProgress(String localAssetId, String filename, int bytes, int totalBytes) {
    if (_cancelToken == null) {
      return;
    }

    final progress = totalBytes > 0 ? bytes / totalBytes : 0.0;
    final networkSpeedAsString = _uploadSpeedManager.updateProgress(localAssetId, bytes, totalBytes);
    final currentItem = state.uploadItems[localAssetId];
    if (currentItem != null) {
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          localAssetId: currentItem.copyWith(
            filename: filename,
            progress: progress,
            fileSize: totalBytes,
            networkSpeedAsString: networkSpeedAsString,
          ),
        },
      );
    } else {
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          localAssetId: UploadStatus(
            taskId: localAssetId,
            filename: filename,
            progress: progress,
            fileSize: totalBytes,
            networkSpeedAsString: networkSpeedAsString,
          ),
        },
      );
    }

    if (Platform.isOhos && totalBytes > 0) {
      final total = state.totalCount > 0 ? state.totalCount : state.backupCount + state.remainderCount;
      if (total > 0) {
        final overallProgress = (((state.backupCount + progress.clamp(0.0, 1.0)) / total) * 100).clamp(0.0, 100.0);
        _updateOhosBackgroundTransferProgress(overallProgress, filename.isNotEmpty ? filename : localAssetId);
      }
    }
  }

  void _handleForegroundBackupSuccess(String localAssetId, String remoteAssetId) {
    if (!mounted) {
      _logger.warning("Skip _handleForegroundBackupSuccess: notifier disposed");
      return;
    }
    state = state.copyWith(backupCount: state.backupCount + 1, remainderCount: state.remainderCount - 1);
    _uploadSpeedManager.removeTask(localAssetId);

    Future.delayed(const Duration(milliseconds: 1000), () {
      _removeUploadItem(localAssetId);
    });
  }

  void _handleForegroundBackupError(String localAssetId, String errorMessage) {
    _logger.severe("Upload failed for $localAssetId: $errorMessage");

    final currentItem = state.uploadItems[localAssetId];
    if (currentItem != null) {
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          localAssetId: currentItem.copyWith(isFailed: true, error: errorMessage),
        },
      );
    } else {
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          localAssetId: UploadStatus(
            taskId: localAssetId,
            filename: 'Unknown',
            progress: 0,
            fileSize: 0,
            networkSpeedAsString: '',
            isFailed: true,
            error: errorMessage,
          ),
        },
      );
    }

    _uploadSpeedManager.removeTask(localAssetId);
  }

  Future<void> startBackupWithURLSession(String userId) async {
    if (!mounted) {
      _logger.warning("Skip handleBackupResume (pre-call): notifier disposed");
      return;
    }
    _backgroundEnqueueCompleted = false;
    _logger.info("Start background backup sequence");
    state = state.copyWith(error: BackupError.none);
    await _startOhosBackgroundTransfer();
    await getBackupStatus(userId);
    final tasks = await _backgroundUploadService.getActiveTasks(kBackupGroup);
    if (!mounted) {
      _logger.warning("Skip handleBackupResume (post-call): notifier disposed");
      return;
    }
    _logger.info("Found ${tasks.length} pending tasks");

    if (tasks.isEmpty) {
      _logger.info("No pending tasks, starting new upload");
      await _backgroundUploadService.uploadBackupCandidates(userId);
      _backgroundEnqueueCompleted = true;
      unawaited(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await _stopOhosBackgroundTransfer();
      }());
      return;
    }

    _logger.info("Resuming upload ${tasks.length} assets");
    await _backgroundUploadService.resume();
    _backgroundEnqueueCompleted = true;
  }

  @override
  void dispose() {
    _backgroundStatusSubscription?.cancel();
    _backgroundProgressSubscription?.cancel();
    super.dispose();
  }
}

final backupCandidateProvider = FutureProvider.autoDispose<List<LocalAsset>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  return ref.read(foregroundUploadServiceProvider).getBackupCandidates(user.id, onlyHashed: false);
});

final candidateBackupAlbumInfoProvider = FutureProvider.autoDispose.family<List<LocalAlbum>, String>((ref, assetId) {
  return ref
      .read(driftProvider)
      .localAssetRepository
      .getSourceAlbums(assetId, backupSelection: BackupSelection.selected);
});
