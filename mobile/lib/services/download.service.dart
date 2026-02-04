import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/models/download/livephotos_medatada.model.dart';
import 'package:immich_mobile/repositories/download.repository.dart';
import 'package:immich_mobile/repositories/file_media.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:logging/logging.dart';

import 'package:path/path.dart' as p;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:immich_mobile/services/asset.service.dart';
import 'package:video_compress/video_compress.dart';

final downloadServiceProvider = Provider(
  (ref) => DownloadService(
    ref.watch(fileMediaRepositoryProvider),
    ref.watch(downloadRepositoryProvider),
    ref.watch(assetServiceProvider),
  ),
);

class _LiveParts {
  String? imagePath;
  String? videoPath;
  String? imageTaskId; // = liveId
  String? videoTaskId; // = livePhotoVideoId
  String? videoRemoteId;
  int imageAttempts = 0;
  int saveAttempts = 0;
}

final Map<String, _LiveParts> _livePartsById = {}; // key=liveId(照片 remoteId)
final Set<String> _savingLiveIds = {}; // 防止重复保存

class DownloadService {
  final DownloadRepository _downloadRepository;
  final FileMediaRepository _fileMediaRepository;
  final AssetService _assetService;
  final Logger _log = Logger("DownloadService");
  void Function(TaskStatusUpdate)? onImageDownloadStatus;
  void Function(TaskStatusUpdate)? onVideoDownloadStatus;
  void Function(TaskStatusUpdate)? onLivePhotoDownloadStatus;
  void Function(TaskProgressUpdate)? onTaskProgress;

  final Map<String, DownloadTask> pendingLiveVideoTaskByRemoteId = {}; //暂存视频任务
  final Set<String> videoEnqueuedLiveIds = {}; //已入队视频任务

  DownloadService(this._fileMediaRepository, this._downloadRepository, this._assetService) {
    _downloadRepository.onImageDownloadStatus = _onImageDownloadCallback;
    _downloadRepository.onVideoDownloadStatus = _onVideoDownloadCallback;
    _downloadRepository.onLivePhotoDownloadStatus = _onLivePhotoDownloadCallback;
    _downloadRepository.onTaskProgress = _onTaskProgressCallback;
  }

  void _onTaskProgressCallback(TaskProgressUpdate update) {
    onTaskProgress?.call(update);
  }

  void _onImageDownloadCallback(TaskStatusUpdate update) {
    onImageDownloadStatus?.call(update);
  }

  void _onVideoDownloadCallback(TaskStatusUpdate update) {
    onVideoDownloadStatus?.call(update);
  }

  void _onLivePhotoDownloadCallback(TaskStatusUpdate update) {
    unawaited(handleLivePhotoDependency(update));
    onLivePhotoDownloadStatus?.call(update);
  }

  Future<bool> saveImageWithPath(Task task) async {
    final filePath = await task.filePath();
    final title = _titleWithoutExtension(task.filename);
    final relativePath = Platform.isAndroid ? 'DCIM/Immich' : null;
    try {
      if (false) {
        //To do
        //if (Platform.isOhos) {
        final tempFile = File(filePath);
        if (tempFile.existsSync() == false) {
          return false;
        }
        final resultAsset = await ImageGallerySaver.saveFile(filePath, name: title, isReturnPathOfIOS: true);
        return resultAsset != null;
      } else {
        final Asset? resultAsset = await _fileMediaRepository.saveImageWithFile(
          //
          filePath,
          title: title,
          relativePath: relativePath,
        );
        return resultAsset != null;
      }
    } catch (error, stack) {
      _log.severe("Error saving image", error, stack);
      return false;
    } finally {
      if (await File(filePath).exists()) {
        await File(filePath).delete();
      }
    }
  }

  Future<void> handleLivePhotoDependency(TaskStatusUpdate update) async {
    LivePhotosMetadata md;
    const int kLivePhotoVideoMinBytes = 1024 * 1024;
    const int kLivePhotoImageMinBytes = 1024 * 1024;
    try {
      md = LivePhotosMetadata.fromJson(update.task.metaData);
    } catch (_) {
      return;
    }

    final liveId = md.id;

    if (update.status == TaskStatus.failed || update.status == TaskStatus.canceled) {
      _livePartsById.remove(liveId);
      pendingLiveVideoTaskByRemoteId.remove(liveId);
      videoEnqueuedLiveIds.remove(liveId);
      _savingLiveIds.remove(liveId);
      return;
    }

    if (update.status != TaskStatus.complete) return;

    final parts = _livePartsById.putIfAbsent(liveId, () => _LiveParts());
    if (md.part == LivePhotosPart.image) {
      parts.imageTaskId = update.task.taskId; // = liveId
      parts.imagePath = await update.task.filePath();

      int imageBytes = 0;
      try {
        imageBytes = await File(parts.imagePath!).length();
      } catch (_) {
        imageBytes = 0;
      }
      if (imageBytes < kLivePhotoImageMinBytes) {
        parts.imageAttempts += 1;
        final attempt = parts.imageAttempts;
        _log.warning(
          "Live photo image too small (${imageBytes} bytes), retrying download for $liveId (attempt $attempt)",
        );

        try {
          await File(parts.imagePath!).delete();
        } catch (_) {}

        if (parts.imageTaskId != null) {
          await _downloadRepository.deleteRecordsWithIds([parts.imageTaskId!]);
        }
        parts.imagePath = null;
        parts.imageTaskId = null;

        if (attempt < 2) {
          final imageTask = _buildDownloadTask(
            liveId,
            update.task.filename,
            group: kDownloadGroupLivePhoto,
            metadata: LivePhotosMetadata(part: LivePhotosPart.image, id: liveId).toJson(),
            priority: 0,
          );
          await _downloadRepository.downloadAll([imageTask]);
          return;
        }

        _livePartsById.remove(liveId);
        pendingLiveVideoTaskByRemoteId.remove(liveId);
        videoEnqueuedLiveIds.remove(liveId);
        _savingLiveIds.remove(liveId);
        return;
      }

      // image 完成 -> enqueue video
      if (!videoEnqueuedLiveIds.contains(liveId)) {
        final videoTask = pendingLiveVideoTaskByRemoteId[liveId];
        if (videoTask != null) {
          videoEnqueuedLiveIds.add(liveId);
          await _downloadRepository.downloadAll([videoTask]);
        }
      }
    } else if (md.part == LivePhotosPart.video) {
      parts.videoTaskId = update.task.taskId; // = livePhotoVideoId
      parts.videoPath = await update.task.filePath();
      parts.videoRemoteId = update.task.taskId;

      int videoBytes = 0;
      try {
        videoBytes = await File(parts.videoPath!).length();
      } catch (_) {
        videoBytes = 0;
      }
      if (videoBytes < kLivePhotoVideoMinBytes) {
        parts.saveAttempts += 1;
        final attempt = parts.saveAttempts;
        _log.warning(
          "Live photo video too small (${videoBytes} bytes), retrying download for $liveId (attempt $attempt)",
        );

        try {
          await File(parts.videoPath!).delete();
        } catch (_) {}

        if (parts.videoTaskId != null) {
          await _downloadRepository.deleteRecordsWithIds([parts.videoTaskId!]);
        }
        parts.videoPath = null;
        parts.videoTaskId = null;
        videoEnqueuedLiveIds.remove(liveId);

        if (attempt < 2) {
          final videoRemoteId = parts.videoRemoteId ?? pendingLiveVideoTaskByRemoteId[liveId]?.taskId;
          if (videoRemoteId != null && videoRemoteId.isNotEmpty) {
            final videoFilename = pendingLiveVideoTaskByRemoteId[liveId]?.filename ?? update.task.filename;

            final videoTask = _buildDownloadTask(
              videoRemoteId,
              videoFilename,
              group: kDownloadGroupLivePhoto,
              metadata: LivePhotosMetadata(part: LivePhotosPart.video, id: liveId).toJson(),
              priority: 1,
            );
            pendingLiveVideoTaskByRemoteId[liveId] = videoTask;
            videoEnqueuedLiveIds.add(liveId);
            await _downloadRepository.downloadAll([videoTask]);
            return;
          }
        }

        if (parts.imagePath != null) {
          await _fileMediaRepository.saveImageWithFile(
            parts.imagePath!,
            title: _titleWithoutExtension(parts.imagePath!),
          );
          try {
            await File(parts.imagePath!).delete();
          } catch (_) {}
        }
        if (parts.imageTaskId != null) {
          await _downloadRepository.deleteRecordsWithIds([parts.imageTaskId!]);
        }

        _livePartsById.remove(liveId);
        pendingLiveVideoTaskByRemoteId.remove(liveId);
        _savingLiveIds.remove(liveId);
        return;
      }
    }

    // 两段齐了：调用同名接口（签名不变）
    if (parts.imagePath != null && parts.videoPath != null) {
      unawaited(saveLivePhotos(update.task, liveId));
    }
  }

  Future<bool> saveVideo(Task task) async {
    final filePath = await task.filePath();
    final title = _titleWithoutExtension(task.filename);
    final relativePath = Platform.isAndroid ? 'DCIM/Immich' : null;
    final file = File(filePath);
    try {
      if (false) {
        //To do
        //if (Platform.isOhos) {
        final tempFile = File(filePath);
        final resultAsset = await ImageGallerySaver.saveFile(tempFile.path, name: title, isReturnPathOfIOS: true);
        return resultAsset != null;
      } else {
        final Asset? resultAsset = await _fileMediaRepository.saveVideo(file, title: title, relativePath: relativePath);
        return resultAsset != null;
      }
    } catch (error, stack) {
      _log.severe("Error saving video", error, stack);
      return false;
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<bool> saveLivePhotos(Task task, String livePhotosId) async {
    final parts = _livePartsById[livePhotosId];
    if (parts == null || parts.imagePath == null || parts.videoPath == null) {
      return false;
    }

    if (!_savingLiveIds.add(livePhotosId)) {
      return true;
    }

    final imageFilePath = parts.imagePath!;
    final videoFilePath = parts.videoPath!;
    final imageTaskId = parts.imageTaskId ?? livePhotosId;
    final videoTaskId = parts.videoTaskId ?? task.taskId;

    final title = _titleWithoutExtension(imageFilePath);
    String actualVideoPath = videoFilePath;
    File? convertedVideoFile;

    bool saved = false;

    if (videoFilePath.toLowerCase().endsWith('.mov')) {
      try {
        final info = await VideoCompress.compressVideo(
          videoFilePath,
          quality: VideoQuality.HighestQuality,
          includeAudio: true,
          deleteOrigin: false,
        );
        if (info != null && info.path != null && info.path!.isNotEmpty) {
          actualVideoPath = info.path!;
          convertedVideoFile = File(actualVideoPath);
          _log.fine("Converted live photo video to MP4: $actualVideoPath");
        } else {
          _log.warning("MOV to MP4 conversion returned null for live photo video $videoFilePath");
        }
      } catch (e, s) {
        _log.warning("Failed to convert live photo video $videoFilePath to MP4", e, s);
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    try {
      final result = await _fileMediaRepository.saveLivePhoto(
        image: File(imageFilePath),
        video: File(actualVideoPath),
        title: title,
      );

      saved = result != null;
    } on PlatformException catch (error, stack) {
      _log.severe("Error saving live photo", error, stack);
    } catch (error, stack) {
      _log.severe("Error saving live photo", error, stack);
    }

    if (!saved) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final result = await _fileMediaRepository.saveLivePhoto(
          image: File(imageFilePath),
          video: File(actualVideoPath),
          title: title,
        );
        saved = result != null;
      } on PlatformException catch (error, stack) {
        _log.severe("Error saving live photo", error, stack);
      } catch (error, stack) {
        _log.severe("Error saving live photo", error, stack);
      }
    }

    if (!saved) {
      final result = await _fileMediaRepository.saveImageWithFile(imageFilePath, title: title);
      saved = result != null;
    }

    try {
      final imageFile = File(imageFilePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      final videoFile = File(videoFilePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }
      if (convertedVideoFile != null && convertedVideoFile.path != videoFilePath && await convertedVideoFile.exists()) {
        await convertedVideoFile.delete();
      }

      await _downloadRepository.deleteRecordsWithIds([imageTaskId, videoTaskId]);
    } finally {
      _livePartsById.remove(livePhotosId);
      pendingLiveVideoTaskByRemoteId.remove(livePhotosId);
      videoEnqueuedLiveIds.remove(livePhotosId);
      _savingLiveIds.remove(livePhotosId);
    }

    return saved;
  }

  String _titleWithoutExtension(String name) => p.basenameWithoutExtension(name);

  Future<bool> cancelDownload(String id) async {
    return await FileDownloader().cancelTaskWithId(id);
  }

  Future<List<bool>> downloadAll(List<Asset> assets) async {
    final tasks = <DownloadTask>[];
    for (final asset in assets) {
      tasks.addAll(await _createDownloadTasks(asset));
    }
    return await _downloadRepository.downloadAll(tasks);
  }

  Future<void> download(Asset asset) async {
    final tasks = await _createDownloadTasks(asset);
    await _downloadRepository.downloadAll(tasks);
  }

  Future<List<DownloadTask>> _createDownloadTasks(Asset asset) async {
    if (asset.isImage && asset.livePhotoVideoId != null && (Platform.isIOS || Platform.isOhos)) {
      String videoFileName;
      final videoAsset = await _assetService.getAssetByRemoteId(asset.livePhotoVideoId!);
      if (videoAsset != null && videoAsset.fileName.isNotEmpty) {
        final videoExt = p.extension(videoAsset.fileName);
        if (videoExt.isNotEmpty) {
          videoFileName = asset.fileName.toUpperCase().replaceAll(RegExp(r"\.(JPG|HEIC)$"), videoExt.toUpperCase());
        } else {
          videoFileName = videoAsset.fileName.toUpperCase();
        }
      } else {
        videoFileName = asset.fileName.toUpperCase().replaceAll(RegExp(r"\.(JPG|HEIC)$"), '.MP4');
      }

      pendingLiveVideoTaskByRemoteId[asset.remoteId!] = _buildDownloadTask(
        asset.livePhotoVideoId!,
        videoFileName,
        group: kDownloadGroupLivePhoto,
        metadata: LivePhotosMetadata(part: LivePhotosPart.video, id: asset.remoteId!).toJson(),
        priority: 1,
      );

      return [
        _buildDownloadTask(
          asset.remoteId!, //
          asset.fileName,
          group: kDownloadGroupLivePhoto,
          metadata: LivePhotosMetadata(part: LivePhotosPart.image, id: asset.remoteId!).toJson(),
          priority: 0,
        ),
      ];
    }

    if (asset.remoteId == null) {
      return [];
    }

    return [
      _buildDownloadTask(
        asset.remoteId!,
        asset.fileName,
        group: asset.isImage ? kDownloadGroupImage : kDownloadGroupVideo,
      ),
    ];
  }

  DownloadTask _buildDownloadTask(String id, String filename, {String? group, String? metadata, int? priority}) {
    final path = r'/assets/{id}/original'.replaceAll('{id}', id);
    final serverEndpoint = Store.get(StoreKey.serverEndpoint);
    final headers = ApiService.getRequestHeaders();

    return DownloadTask(
      taskId: id,
      url: serverEndpoint + path,
      headers: headers,
      filename: filename,
      updates: Updates.statusAndProgress,
      group: group ?? '',
      metaData: metadata ?? '',
      priority: priority ?? 5,
    );
  }
}

TaskRecord _findTaskRecord(List<TaskRecord> records, String livePhotosId, LivePhotosPart part) {
  return records.firstWhere((record) {
    final metadata = LivePhotosMetadata.fromJson(record.task.metaData);
    return metadata.id == livePhotosId && metadata.part == part;
  });
}
