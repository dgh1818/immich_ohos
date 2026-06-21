import 'dart:async';
import 'dart:io';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/models/upload/share_intent_attachment.model.dart';
import 'package:immich_mobile/repositories/upload.repository.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/services/share_intent_service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';

final shareIntentUploadProvider = StateNotifierProvider<ShareIntentUploadStateNotifier, List<ShareIntentAttachment>>(
  ((ref) => ShareIntentUploadStateNotifier(
    ref.watch(appRouterProvider),
    ref.read(foregroundUploadServiceProvider),
    ref.read(shareIntentServiceProvider),
    ref.read(uploadRepositoryProvider),
  )),
);

class ShareIntentUploadStateNotifier extends StateNotifier<List<ShareIntentAttachment>> {
  final AppRouter router;
  final ForegroundUploadService _foregroundUploadService;
  final ShareIntentService _shareIntentService;
  final UploadRepository _uploadRepository;
  final Logger _logger = Logger('ShareIntentUploadStateNotifier');

  ShareIntentUploadStateNotifier(
    this.router,
    this._foregroundUploadService,
    this._shareIntentService,
    this._uploadRepository,
  ) : super([]);

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

  Future<void> uploadAll(List<File> files) async {
    if (state.isEmpty) {
      return;
    }

    final selectedPaths = files.map((file) => file.path).toSet();
    final attachments = state.where((attachment) => selectedPaths.contains(attachment.path)).toList();
    if (attachments.isEmpty) {
      return;
    }

    for (final attachment in attachments) {
      _updateStatus(_attachmentFileId(attachment), UploadStatus.running);
    }

    final normalFiles = <File>[];
    for (final attachment in attachments) {
      if (attachment.isImage) {
        final handled = await _tryUploadLivePhoto(attachment);
        if (handled) {
          continue;
        }
      }
      normalFiles.add(attachment.file);
    }

    if (normalFiles.isEmpty) {
      return;
    }

    await _foregroundUploadService.uploadShareIntent(
      normalFiles,
      mergeOhosLivePhotos: Platform.isOhos,
      onProgress: (fileId, bytes, totalBytes) {
        final progress = totalBytes > 0 ? bytes / totalBytes : 0.0;
        _updateProgress(fileId, progress);
      },
      onSuccess: (fileId, _) {
        _updateStatus(fileId, UploadStatus.complete, progress: 1.0);
      },
      onError: (fileId, errorMessage) {
        _logger.warning("Upload failed for file: $fileId, error: $errorMessage");
        _updateStatus(fileId, UploadStatus.failed);
      },
    );
  }

  void _updateStatus(String fileId, UploadStatus status, {double? progress}) {
    final id = int.parse(fileId);
    state = [
      for (final attachment in state)
        if (attachment.id == id)
          attachment.copyWith(status: status, uploadProgress: progress ?? attachment.uploadProgress)
        else
          attachment,
    ];
  }

  void _updateProgress(String fileId, double progress) {
    final id = int.parse(fileId);
    state = [
      for (final attachment in state)
        if (attachment.id == id) attachment.copyWith(uploadProgress: progress) else attachment,
    ];
  }

  String _attachmentFileId(ShareIntentAttachment attachment) => p.hash(attachment.path).toString();

  Future<bool> _tryUploadLivePhoto(ShareIntentAttachment attachment) async {
    AssetEntity? entity;
    try {
      entity = await AssetEntity.fromId(attachment.path);
    } catch (_) {
      entity = null;
    }

    if (entity == null || !entity.isLivePhoto) {
      return false;
    }

    File? imageFile;
    File? videoFile;
    try {
      imageFile = await entity.originFile;
      videoFile = await entity.originFileWithSubtype;
    } catch (_) {
      imageFile = null;
      videoFile = null;
    }

    if (imageFile == null || videoFile == null) {
      return false;
    }

    final fileId = _attachmentFileId(attachment);
    final deviceId = Store.get(StoreKey.deviceId);
    final createdAt = entity.createDateTime;
    final modifiedAt = entity.modifiedDateTime;
    final duration = entity.duration;
    final baseFields = <String, String>{
      'deviceAssetId': fileId,
      'deviceId': deviceId,
      'fileCreatedAt': createdAt.toUtc().toIso8601String(),
      'fileModifiedAt': modifiedAt.toUtc().toIso8601String(),
      'isFavorite': entity.isFavorite.toString(),
      'duration': duration.toString(),
    };

    final imageName = p.basename(imageFile.path);
    final videoName = p.setExtension(imageName, p.extension(videoFile.path));

    final cancelToken = Completer<void>();

    try {
      final videoResult = await _uploadRepository.uploadFile(
        file: videoFile,
        originalFileName: videoName,
        fields: baseFields,
        cancelToken: cancelToken,
        onProgress: (bytes, totalBytes) {
          final progress = totalBytes > 0 ? bytes / totalBytes : 0.0;
          _updateProgress(fileId, progress);
        },
        logContext: 'shareLivePhotoVideo[$fileId]',
      );

      if (!videoResult.isSuccess || videoResult.remoteAssetId == null) {
        _updateStatus(fileId, UploadStatus.failed);
        return true;
      }

      final imageFields = {...baseFields, 'livePhotoVideoId': videoResult.remoteAssetId!};

      final imageResult = await _uploadRepository.uploadFile(
        file: imageFile,
        originalFileName: imageName,
        fields: imageFields,
        cancelToken: cancelToken,
        onProgress: (bytes, totalBytes) {
          final progress = totalBytes > 0 ? bytes / totalBytes : 0.0;
          _updateProgress(fileId, progress);
        },
        logContext: 'shareLivePhotoImage[$fileId]',
      );

      if (imageResult.isSuccess) {
        _updateStatus(fileId, UploadStatus.complete, progress: 1.0);
      } else {
        _updateStatus(fileId, UploadStatus.failed);
      }
    } catch (error) {
      _logger.warning("Live photo upload failed for ${attachment.path}: $error");
      _updateStatus(fileId, UploadStatus.failed);
    }

    return true;
  }
}
