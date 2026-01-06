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

class DownloadService {
  final DownloadRepository _downloadRepository;
  final FileMediaRepository _fileMediaRepository;
  final AssetService _assetService;
  final Logger _log = Logger("DownloadService");
  void Function(TaskStatusUpdate)? onImageDownloadStatus;
  void Function(TaskStatusUpdate)? onVideoDownloadStatus;
  void Function(TaskStatusUpdate)? onLivePhotoDownloadStatus;
  void Function(TaskProgressUpdate)? onTaskProgress;

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
    onLivePhotoDownloadStatus?.call(update);
  }

  Future<bool> saveImageWithPath(Task task) async {
    final filePath = await task.filePath();
    final title = _titleWithoutExtension(task.filename);
    final relativePath = Platform.isAndroid ? 'DCIM/Immich' : null;
    try {
      if (Platform.isOhos) {
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

  Future<bool> saveVideo(Task task) async {
    final filePath = await task.filePath();
    final title = _titleWithoutExtension(task.filename);
    final relativePath = Platform.isAndroid ? 'DCIM/Immich' : null;
    final file = File(filePath);
    try {
      if (Platform.isOhos) {
        final tempFile = File(filePath);
        final resultAsset = await ImageGallerySaver.saveFile(tempFile.path, name: title, isReturnPathOfIOS: true);
        unawaited(tempFile.delete());
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
    final records = await _downloadRepository.getLiveVideoTasks();
    if (records.length < 2) {
      return false;
    }

    final imageRecord = _findTaskRecord(records, livePhotosId, LivePhotosPart.image);
    final videoRecord = _findTaskRecord(records, livePhotosId, LivePhotosPart.video);
    final imageFilePath = await imageRecord.task.filePath();
    final videoFilePath = await videoRecord.task.filePath();
    final title = _titleWithoutExtension(task.filename);
    String actualVideoPath = videoFilePath;
    File? convertedVideoFile;

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

    try {
      final result = await _fileMediaRepository.saveLivePhoto(
        image: File(imageFilePath),
        video: File(actualVideoPath),
        title: title,
      );

      return result != null;
    } on PlatformException catch (error, stack) {
      _log.severe("Error saving live photo", error, stack);
      // Handle saving MotionPhotos on iOS
      //if (error.code == 'PHPhotosErrorDomain (-1)') {
      final result = await _fileMediaRepository.saveImageWithFile(imageFilePath, title: task.filename);
      return result != null;
      //}
      _log.severe("Error saving live photo", error, stack);
      return false;
    } catch (error, stack) {
      _log.severe("Error saving live photo", error, stack);
      return false;
    } finally {
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

      await _downloadRepository.deleteRecordsWithIds([imageRecord.task.taskId, videoRecord.task.taskId]);
    }
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
      return [
        _buildDownloadTask(
          asset.remoteId!,
          asset.fileName,
          group: kDownloadGroupLivePhoto,
          metadata: LivePhotosMetadata(part: LivePhotosPart.image, id: asset.remoteId!).toJson(),
        ),
        _buildDownloadTask(
          asset.livePhotoVideoId!,
          videoFileName,
          group: kDownloadGroupLivePhoto,
          metadata: LivePhotosMetadata(part: LivePhotosPart.video, id: asset.remoteId!).toJson(),
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

  DownloadTask _buildDownloadTask(String id, String filename, {String? group, String? metadata}) {
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
    );
  }
}

TaskRecord _findTaskRecord(List<TaskRecord> records, String livePhotosId, LivePhotosPart part) {
  return records.firstWhere((record) {
    final metadata = LivePhotosMetadata.fromJson(record.task.metaData);
    return metadata.id == livePhotosId && metadata.part == part;
  });
}
