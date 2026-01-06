import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/string_extensions.dart';
import 'package:immich_mobile/models/upload/share_intent_attachment.model.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/share_intent_service.dart';
import 'package:immich_mobile/services/upload.service.dart';
import 'package:logging/logging.dart';

import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'dart:convert';

final shareIntentUploadProvider = StateNotifierProvider<ShareIntentUploadStateNotifier, List<ShareIntentAttachment>>(
  ((ref) => ShareIntentUploadStateNotifier(
    ref.watch(appRouterProvider),
    ref.watch(uploadServiceProvider),
    ref.watch(shareIntentServiceProvider),
  )),
);

class ShareIntentUploadStateNotifier extends StateNotifier<List<ShareIntentAttachment>> {
  final AppRouter router;
  final UploadService _uploadService;
  final ShareIntentService _shareIntentService;
  final Logger _logger = Logger('ShareIntentUploadStateNotifier');

  ShareIntentUploadStateNotifier(this.router, this._uploadService, this._shareIntentService) : super([]) {
    _uploadService.taskStatusStream.listen(_updateUploadStatus);
    _uploadService.taskProgressStream.listen(_taskProgressCallback);
  }

  void init() {
    _shareIntentService.onSharedMedia = onSharedMedia;
    _shareIntentService.init();
  }

  void onSharedMedia(List<ShareIntentAttachment> attachments) {
    router.removeWhere((route) => route.name == "ShareIntentRoute");
    clearAttachments();
    addAttachments(attachments);
    router.push(ShareIntentRoute(attachments: attachments));
  }

  void addAttachments(List<ShareIntentAttachment> attachments) {
    if (attachments.isEmpty) {
      return;
    }
    state = [...state, ...attachments];
  }

  void removeAttachment(ShareIntentAttachment attachment) {
    final updatedState = state.where((element) => element != attachment).toList();
    if (updatedState.length != state.length) {
      state = updatedState;
    }
  }

  void clearAttachments() {
    if (state.isEmpty) {
      return;
    }

    state = [];
  }

  void _updateUploadStatus(TaskStatusUpdate task) async {
    if (task.status == TaskStatus.canceled) {
      return;
    }

    final taskId = task.task.taskId;

    if (task.status == TaskStatus.complete) {
      final handled = await _handleLivePhotoCompletion(task, taskId);
      if (handled) {
        return;
      }
    }

    final uploadStatus = switch (task.status) {
      TaskStatus.complete => UploadStatus.complete,
      TaskStatus.failed => UploadStatus.failed,
      TaskStatus.canceled => UploadStatus.canceled,
      TaskStatus.enqueued => UploadStatus.enqueued,
      TaskStatus.running => UploadStatus.running,
      TaskStatus.paused => UploadStatus.paused,
      TaskStatus.notFound => UploadStatus.notFound,
      TaskStatus.waitingToRetry => UploadStatus.waitingToRetry,
    };

    state = [
      for (final attachment in state)
        if (attachment.path == taskId) attachment.copyWith(status: uploadStatus) else attachment,
    ];

    if (task.status == TaskStatus.failed) {
      String? error;
      final exception = task.exception;
      if (exception != null && exception is TaskHttpException) {
        final message = tryJsonDecode(exception.description)?['message'] as String?;
        if (message != null) {
          final responseCode = exception.httpResponseCode;
          error = "${exception.exceptionType}, response code $responseCode: $message";
        }
      }
      error ??= task.exception?.toString();

      _logger.warning("Upload failed for asset: ${task.task.filename}, error: $error");
    }
  }

  Future<bool> _handleLivePhotoCompletion(TaskStatusUpdate task, String taskId) async {
    try {
      final metaData = task.task.metaData;
      String? photoUri;
      if (metaData.isNotEmpty) {
        final map = json.decode(metaData) as Map<String, dynamic>;
        if (map['shareLivePhoto'] == true) {
          photoUri = map['sharePhotoUri'] as String?;
          final filename = task.task.filename;
          if (filename.isNotEmpty) {
            final directory = task.task.directory;
            final separator = directory.isEmpty || directory.endsWith('/') ? '' : '/';
            final tempVideoPath = '$directory$separator$filename';
            try {
              final file = File(tempVideoPath);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (error) {
              _logger.warning('Failed to delete live photo temp file: $tempVideoPath, error: $error');
            }
          }
        }
      }
      if (photoUri == null) {
        return false;
      }

      final response = tryJsonDecode(task.responseBody);
      final livePhotoVideoId = response?['id']?.toString();
      if (livePhotoVideoId == null || livePhotoVideoId.isEmpty) {
        state = [
          for (final attachment in state)
            if (attachment.path == taskId) attachment.copyWith(status: UploadStatus.failed) else attachment,
        ];
        return true;
      }

      final entity = await AssetEntity.fromId(photoUri);
      final photoFile = File(photoUri);

      final now = DateTime.now();
      final fileCreatedAt = entity?.createDateTime ?? now;
      final fileModifiedAt = entity?.modifiedDateTime ?? fileCreatedAt;
      final photoTask = await _buildUploadTask(
        taskId,
        photoFile,
        fileCreatedAt: fileCreatedAt,
        fileModifiedAt: fileModifiedAt,
        fields: {'livePhotoVideoId': livePhotoVideoId},
        group: kManualLivePhotoGroup,
        priority: 0,
      );

      state = [
        for (final attachment in state)
          if (attachment.path == taskId)
            attachment.copyWith(status: UploadStatus.running, uploadProgress: 0.0)
          else
            attachment,
      ];
      await _uploadService.enqueueTasks([photoTask]);
      return true;
    } catch (error) {
      _logger.warning("Live photo follow-up failed for asset: ${task.task.filename}, error: $error");
      state = [
        for (final attachment in state)
          if (attachment.path == taskId) attachment.copyWith(status: UploadStatus.failed) else attachment,
      ];
      return true;
    }
  }

  void _taskProgressCallback(TaskProgressUpdate update) {
    // Ignore if the task is canceled or completed
    if (update.progress == downloadFailed || update.progress == downloadCompleted) {
      return;
    }

    final taskId = update.task.taskId;
    state = [
      for (final attachment in state)
        if (attachment.path == taskId) attachment.copyWith(uploadProgress: update.progress) else attachment,
    ];
  }

  Future<void> upload(File file) async {
    final uri = file.path;
    ShareIntentAttachment? attachment;
    for (final item in state) {
      if (item.path == uri) {
        attachment = item;
        break;
      }
    }
    if (attachment == null) {
      return;
    }

    AssetEntity? entity;
    try {
      entity = await AssetEntity.fromId(uri);
    } catch (_) {
      entity = null;
    }

    if (entity != null && attachment.isImage && entity.isLivePhoto) {
      await _uploadLiveVideo(attachment, entity);
      return;
    }

    final now = DateTime.now();
    final fileCreatedAt = entity?.createDateTime ?? now;
    final fileModifiedAt = entity?.modifiedDateTime ?? fileCreatedAt;
    final task = await _buildUploadTask(uri, file, fileCreatedAt: fileCreatedAt, fileModifiedAt: fileModifiedAt);
    await _uploadService.enqueueTasks([task]);
  }

  Future<UploadTask> _buildUploadTask(
    String id,
    File file, {
    DateTime? fileCreatedAt,
    DateTime? fileModifiedAt,
    Map<String, String>? fields,
    String? metaData,
    String group = kManualUploadGroup,
    int priority = 5,
  }) async {
    final serverEndpoint = Store.get(StoreKey.serverEndpoint);
    final url = Uri.parse('$serverEndpoint/assets').toString();
    final headers = ApiService.getRequestHeaders();
    final deviceId = Store.get(StoreKey.deviceId);

    final resolvedFilename = p.basename(file.path);
    final resolvedDirectory = p.dirname(file.path);
    final resolvedCreatedAt = fileCreatedAt ?? DateTime.now();
    final resolvedModifiedAt = fileModifiedAt ?? resolvedCreatedAt;

    final fieldsMap = {
      'filename': resolvedFilename,
      'deviceAssetId': id,
      'deviceId': deviceId,
      'fileCreatedAt': resolvedCreatedAt.toUtc().toIso8601String(),
      'fileModifiedAt': resolvedModifiedAt.toUtc().toIso8601String(),
      'isFavorite': 'false',
      'duration': '0',
      if (fields != null) ...fields,
    };

    return UploadTask(
      taskId: id,
      httpRequestMethod: 'POST',
      url: url,
      headers: headers,
      filename: resolvedFilename,
      fields: fieldsMap,
      fileField: 'assetData',
      baseDirectory: BaseDirectory.root,
      directory: resolvedDirectory,
      group: group,
      metaData: metaData ?? '',
      priority: priority,
      updates: Updates.statusAndProgress,
    );
  }

  Future<void> _uploadLiveVideo(ShareIntentAttachment attachment, AssetEntity entity) async {
    File? videoFile;
    try {
      videoFile = await entity.originFileWithSubtype;
    } catch (_) {
      videoFile = null;
    }

    final photoUriString = attachment.path;
    final photoFile = File(photoUriString);

    final now = DateTime.now();
    final fileCreatedAt = entity?.createDateTime ?? now;
    final fileModifiedAt = entity?.modifiedDateTime ?? fileCreatedAt;
    if (videoFile == null) {
      final task = await _buildUploadTask(
        attachment.path,
        photoFile,
        fileCreatedAt: fileCreatedAt,
        fileModifiedAt: fileModifiedAt,
      );
      await _uploadService.enqueueTasks([task]);
      return;
    }

    final metadata = _buildLivePhotoMetadata(attachment.path, attachment.path);
    final task = await _buildUploadTask(
      attachment.path,
      videoFile,
      fileCreatedAt: fileCreatedAt,
      fileModifiedAt: fileModifiedAt,
      metaData: metadata,
    );
    await _uploadService.enqueueTasks([task]);
  }

  String _buildLivePhotoMetadata(String attachmentUri, String photoUri) {
    return json.encode({
      'localAssetId': attachmentUri,
      'isLivePhotos': false,
      'livePhotoVideoId': '',
      'shareLivePhoto': true,
      'sharePhotoUri': photoUri,
    });
  }
}
