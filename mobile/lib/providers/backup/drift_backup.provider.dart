import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:cancellation_token_http/http.dart';
import 'package:collection/collection.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/string_extensions.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/utils/upload_speed_calculator.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/sync_status.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/services/background_upload.service.dart';

class EnqueueStatus {
  final int enqueueCount;
  final int totalCount;

  const EnqueueStatus({required this.enqueueCount, required this.totalCount});

  EnqueueStatus copyWith({int? enqueueCount, int? totalCount}) {
    return EnqueueStatus(enqueueCount: enqueueCount ?? this.enqueueCount, totalCount: totalCount ?? this.totalCount);
  }

  @override
  String toString() => 'EnqueueStatus(enqueueCount: $enqueueCount, totalCount: $totalCount)';
}

class DriftUploadStatus {
  final String taskId;
  final String filename;
  final double progress;
  final int fileSize;
  final String networkSpeedAsString;
  final bool? isFailed;
  final String? error;

  const DriftUploadStatus({
    required this.taskId,
    required this.filename,
    required this.progress,
    required this.fileSize,
    required this.networkSpeedAsString,
    this.isFailed,
    this.error,
  });

  DriftUploadStatus copyWith({
    String? taskId,
    String? filename,
    double? progress,
    int? fileSize,
    String? networkSpeedAsString,
    bool? isFailed,
    String? error,
  }) {
    return DriftUploadStatus(
      taskId: taskId ?? this.taskId,
      filename: filename ?? this.filename,
      progress: progress ?? this.progress,
      fileSize: fileSize ?? this.fileSize,
      networkSpeedAsString: networkSpeedAsString ?? this.networkSpeedAsString,
      isFailed: isFailed ?? this.isFailed,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'DriftUploadStatus(taskId: $taskId, filename: $filename, progress: $progress, fileSize: $fileSize, networkSpeedAsString: $networkSpeedAsString, isFailed: $isFailed, error: $error)';
  }

  @override
  bool operator ==(covariant DriftUploadStatus other) {
    if (identical(this, other)) return true;

    return other.taskId == taskId &&
        other.filename == filename &&
        other.progress == progress &&
        other.fileSize == fileSize &&
        other.networkSpeedAsString == networkSpeedAsString &&
        other.isFailed == isFailed &&
        other.error == error;
  }

  @override
  int get hashCode {
    return taskId.hashCode ^
        filename.hashCode ^
        progress.hashCode ^
        fileSize.hashCode ^
        networkSpeedAsString.hashCode ^
        isFailed.hashCode ^
        error.hashCode;
  }
}

enum BackupError { none, syncFailed }

class DriftBackupState {
  final int totalCount;
  final int backupCount;
  final int remainderCount;
  final int processingCount;

  final bool isSyncing;
  final BackupError error;

  final Map<String, DriftUploadStatus> uploadItems;
  final CancellationToken? cancelToken;

  final Map<String, double> iCloudDownloadProgress;

  const DriftBackupState({
    required this.totalCount,
    required this.backupCount,
    required this.remainderCount,
    required this.processingCount,
    required this.isSyncing,
    this.error = BackupError.none,
    required this.uploadItems,
    this.cancelToken,
    this.iCloudDownloadProgress = const {},
  });

  DriftBackupState copyWith({
    int? totalCount,
    int? backupCount,
    int? remainderCount,
    int? processingCount,
    bool? isSyncing,
    BackupError? error,
    Map<String, DriftUploadStatus>? uploadItems,
    CancellationToken? cancelToken,
    Map<String, double>? iCloudDownloadProgress,
  }) {
    return DriftBackupState(
      totalCount: totalCount ?? this.totalCount,
      backupCount: backupCount ?? this.backupCount,
      remainderCount: remainderCount ?? this.remainderCount,
      processingCount: processingCount ?? this.processingCount,
      isSyncing: isSyncing ?? this.isSyncing,
      error: error ?? this.error,
      uploadItems: uploadItems ?? this.uploadItems,
      cancelToken: cancelToken ?? this.cancelToken,
      iCloudDownloadProgress: iCloudDownloadProgress ?? this.iCloudDownloadProgress,
    );
  }

  int get errorCount => uploadItems.values.where((item) => item.isFailed == true).length;

  @override
  String toString() {
    return 'DriftBackupState(totalCount: $totalCount, backupCount: $backupCount, remainderCount: $remainderCount, processingCount: $processingCount, isSyncing: $isSyncing, error: $error, uploadItems: $uploadItems, cancelToken: $cancelToken, iCloudDownloadProgress: $iCloudDownloadProgress)';
  }

  @override
  bool operator ==(covariant DriftBackupState other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;

    return other.totalCount == totalCount &&
        other.backupCount == backupCount &&
        other.remainderCount == remainderCount &&
        other.processingCount == processingCount &&
        other.isSyncing == isSyncing &&
        other.error == error &&
        mapEquals(other.iCloudDownloadProgress, iCloudDownloadProgress) &&
        mapEquals(other.uploadItems, uploadItems) &&
        other.cancelToken == cancelToken;
  }

  @override
  int get hashCode {
    return totalCount.hashCode ^
        backupCount.hashCode ^
        remainderCount.hashCode ^
        processingCount.hashCode ^
        isSyncing.hashCode ^
        error.hashCode ^
        uploadItems.hashCode ^
        cancelToken.hashCode ^
        iCloudDownloadProgress.hashCode;
  }
}

final driftBackupProvider = StateNotifierProvider<DriftBackupNotifier, DriftBackupState>((ref) {
  return DriftBackupNotifier(
    ref.watch(foregroundUploadServiceProvider),
    ref.watch(backgroundUploadServiceProvider),
    UploadSpeedManager(),
    ref,
  );
});

class DriftBackupNotifier extends StateNotifier<DriftBackupState> {
  DriftBackupNotifier(this._foregroundUploadService, this._backgroundUploadService, this._uploadSpeedManager, this._ref)
    : _nativeSyncApi = _ref.read(nativeSyncApiProvider),
      super(
        const DriftBackupState(
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
  final Ref _ref;
  final NativeSyncApiOhos _nativeSyncApi;

  StreamSubscription<TaskStatusUpdate>? _backgroundStatusSubscription;
  StreamSubscription<TaskProgressUpdate>? _backgroundProgressSubscription;

  bool _backgroundEnqueueCompleted = false;

  final _logger = Logger("DriftBackupNotifier");
  static const String _ohosBackupTitle = '正在上传媒体';

  Future<void> _startOhosBackgroundTransfer() async {
    if (!Platform.isOhos) {
      return;
    }
    try {
      await _nativeSyncApi.startBackgroundTransfer();
    } catch (_) {
      // ignore start failures on OHOS
    }
  }

  Future<void> _stopOhosBackgroundTransfer({bool checkActiveTasks = true}) async {
    if (!Platform.isOhos) {
      return;
    }
    if (_ref.read(syncStatusProvider).isHashing) {
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
      // ignore stop failures on OHOS
    }
  }

  void _updateOhosBackgroundTransferProgress(double progressPercent, String filename) {
    if (!Platform.isOhos) {
      return;
    }
    try {
      _nativeSyncApi.updateBackgroundTransferProgress(progressPercent, _ohosBackupTitle, filename);
    } catch (_) {
      // ignore background progress errors on OHOS
    }
  }

  /// Remove upload item from state
  void _removeUploadItem(String taskId) {
    if (!mounted) {
      _logger.warning("Skip _removeUploadItem: notifier disposed");
      return;
    }
    if (state.uploadItems.containsKey(taskId)) {
      final updatedItems = Map<String, DriftUploadStatus>.from(state.uploadItems);
      updatedItems.remove(taskId);
      state = state.copyWith(uploadItems: updatedItems);
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
        if (update.task.group == kBackupGroup) {
          if (update.responseStatusCode == 201) {
            state = state.copyWith(backupCount: state.backupCount + 1, remainderCount: state.remainderCount - 1);
            final total = state.totalCount > 0 ? state.totalCount : state.backupCount + state.remainderCount;
            if (total > 0) {
              final progressPercent = ((state.backupCount / total) * 100).clamp(0.0, 100.0);
              final name = update.task.displayName.isNotEmpty ? update.task.displayName : update.task.filename;
              _updateOhosBackgroundTransferProgress(progressPercent, name);
            }
          }
        }

        if (state.uploadItems.containsKey(taskId)) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            _removeUploadItem(taskId);
          });
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
        if (exception != null && exception is TaskHttpException) {
          final message = tryJsonDecode(exception.description)?['message'] as String?;
          if (message != null) {
            final responseCode = exception.httpResponseCode;
            error = "${exception.exceptionType}, response code $responseCode: $message";
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
        _removeUploadItem(update.task.taskId);
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
      bool isLivePhotoVideo = false;
      if (update.status == TaskStatus.complete && update.task.metaData.isNotEmpty) {
        try {
          isLivePhotoVideo = UploadTaskMetadata.fromJson(update.task.metaData).isLivePhotos;
        } catch (_) {
          // ignore metadata parse errors
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
    final progress = update.progress;
    final currentItem = state.uploadItems[taskId];
    if (currentItem != null) {
      if (progress == kUploadStatusCanceled) {
        _removeUploadItem(update.task.taskId);
        return;
      }

      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          taskId: update.hasExpectedFileSize
              ? currentItem.copyWith(
                  progress: progress,
                  fileSize: update.expectedFileSize,
                  networkSpeedAsString: update.networkSpeedAsString,
                )
              : currentItem.copyWith(progress: progress),
        },
      );
    } else {
      state = state.copyWith(
        uploadItems: {
          ...state.uploadItems,
          taskId: DriftUploadStatus(
            taskId: taskId,
            filename: filename,
            progress: progress,
            fileSize: update.expectedFileSize,
            networkSpeedAsString: update.networkSpeedAsString,
          ),
        },
      );
    }

    if (Platform.isOhos &&
        (update.task.group == kBackupGroup || update.task.group == kBackupLivePhotoGroup) &&
        progress >= 0) {
      final total = state.totalCount > 0 ? state.totalCount : state.backupCount + state.remainderCount;
      if (total > 0) {
        final uploadProgress = progress.clamp(0.0, 1.0).toDouble();
        final overallProgress = (((state.backupCount + uploadProgress) / total) * 100).clamp(0.0, 100.0);
        final name = filename.isNotEmpty ? filename : update.task.filename;
        _updateOhosBackgroundTransferProgress(overallProgress, name);
      }
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

  void updateError(BackupError error) async {
    if (!mounted) {
      _logger.warning("Skip updateError: notifier disposed");
      return;
    }
    state = state.copyWith(error: error);
  }

  void updateSyncing(bool isSyncing) async {
    state = state.copyWith(isSyncing: isSyncing);
  }

  Future<void> startForegroundBackup(String userId) async {
    // Cancel any existing backup before starting a new one
    if (state.cancelToken != null) {
      await stopForegroundBackup();
    }

    state = state.copyWith(error: BackupError.none);

    await _startOhosBackgroundTransfer();

    final cancelToken = CancellationToken();
    state = state.copyWith(cancelToken: cancelToken);

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
      if (mounted) {
        unawaited(_stopOhosBackgroundTransfer(checkActiveTasks: false));
      }
    }
  }

  Future<void> stopForegroundBackup() async {
    state.cancelToken?.cancel();
    _uploadSpeedManager.clear();
    state = state.copyWith(cancelToken: null, uploadItems: {}, iCloudDownloadProgress: {});
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
    if (state.cancelToken == null) {
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
          localAssetId: DriftUploadStatus(
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
        final uploadProgress = progress.clamp(0.0, 1.0).toDouble();
        final overallProgress = (((state.backupCount + uploadProgress) / total) * 100).clamp(0.0, 100.0);
        final name = filename.isNotEmpty ? filename : localAssetId;
        _updateOhosBackgroundTransferProgress(overallProgress, name);
      }
    }
  }

  void _handleForegroundBackupSuccess(String localAssetId, String remoteAssetId) {
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
          localAssetId: DriftUploadStatus(
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
    return;
  }

  @override
  void dispose() {
    _backgroundStatusSubscription?.cancel();
    _backgroundProgressSubscription?.cancel();
    super.dispose();
  }
}

final driftBackupCandidateProvider = FutureProvider.autoDispose<List<LocalAsset>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  return ref.read(foregroundUploadServiceProvider).getBackupCandidates(user.id, onlyHashed: false);
});

final driftCandidateBackupAlbumInfoProvider = FutureProvider.autoDispose.family<List<LocalAlbum>, String>((
  ref,
  assetId,
) {
  return ref.read(localAssetRepository).getSourceAlbums(assetId, backupSelection: BackupSelection.selected);
});
