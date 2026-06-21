import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart' hide AssetType;

final fileMediaRepositoryProvider = Provider((ref) => const FileMediaRepository());

class FileMediaRepository {
  const FileMediaRepository();

  Future<LocalAsset?> saveLocalAsset(Uint8List data, {required String title, String? relativePath}) async {
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      await ImageGallerySaver.saveImage(data, name: p.withoutExtension(title));
      return null;
    }

    final entity = await PhotoManager.editor.saveImage(data, filename: title, title: title, relativePath: relativePath);

    return LocalAsset(
      id: entity.id,
      name: title,
      type: AssetType.image,
      createdAt: entity.createDateTime,
      updatedAt: entity.modifiedDateTime,
      playbackStyle: AssetPlaybackStyle.image,
      isEdited: false,
    );
  }

  Future<AssetEntity?> saveImageWithFile(String filePath, {String? title, String? relativePath}) async {
    if (Platform.isOhos) {
      final entityTitle = title == null ? p.basenameWithoutExtension(filePath) : p.withoutExtension(title);
      final result = await ImageGallerySaver.saveFile(filePath, name: entityTitle, isReturnPathOfIOS: true);
      return _assetEntityFromGalleryResult(result, title: entityTitle, typeInt: 1);
    }

    final entity = await PhotoManager.editor.saveImageWithPath(filePath, title: title, relativePath: relativePath);
    return entity;
  }

  Future<AssetEntity?> saveLivePhoto({required File image, required File video, required String title}) async {
    if (Platform.isIOS) {
      final entity = await PhotoManager.editor.darwin.saveLivePhoto(imageFile: image, videoFile: video, title: title);
      return entity;
    } else if (Platform.isOhos) {
      final entity = await PhotoManager.editor.ohos.saveLivePhoto(imageFile: image, videoFile: video, title: title);
      return entity;
    } else {
      return null;
    }
  }

  Future<AssetEntity?> saveVideo(File file, {required String title, String? relativePath}) async {
    if (Platform.isOhos) {
      final entityTitle = p.withoutExtension(title);
      final result = await ImageGallerySaver.saveFile(file.path, name: entityTitle, isReturnPathOfIOS: true);
      return _assetEntityFromGalleryResult(result, title: entityTitle, typeInt: 2);
    }

    final entity = await PhotoManager.editor.saveVideo(file, title: title, relativePath: relativePath);
    return entity;
  }

  AssetEntity? _assetEntityFromGalleryResult(Object? result, {required String title, required int typeInt}) {
    if (result is! Map<Object?, Object?> || result['isSuccess'] != true) {
      return null;
    }

    final filePath = result['filePath'];
    return AssetEntity(
      id: filePath is String && filePath.isNotEmpty ? filePath : title,
      typeInt: typeInt,
      width: 1,
      height: 1,
      title: title,
    );
  }
}
