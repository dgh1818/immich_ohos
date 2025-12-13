import 'package:flutter/services.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:logging/logging.dart';

const String _kHashCancelledCode = "HASH_CANCELLED";

import 'dart:io';
import 'package:openapi/api.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class HashService {
  final int _batchSize;
  final DriftLocalAlbumRepository _localAlbumRepository;
  final DriftLocalAssetRepository _localAssetRepository;
  final NativeSyncApiOhos _nativeSyncApi;
  final AssetsApi _assetsApi;
  final bool Function()? _cancelChecker;
  final _log = Logger('HashService');

  HashService({
    required DriftLocalAlbumRepository localAlbumRepository,
    required DriftLocalAssetRepository localAssetRepository,
    required NativeSyncApi nativeSyncApi,
    required NativeSyncApiOhos nativeSyncApi,
    bool Function()? cancelChecker,
    int? batchSize,
  }) : _localAlbumRepository = localAlbumRepository,
       _localAssetRepository = localAssetRepository,
       _cancelChecker = cancelChecker,
       _nativeSyncApi = nativeSyncApi,
       _batchSize = batchSize ?? kBatchHashFileLimit;

       _assetsApi = assetsApi;

  bool get isCancelled => _cancelChecker?.call() ?? false;
  int hashedCount = 0;
  int toHashCount = 0;

  Future<void> hashAssets() async {
    _log.info("Starting hashing of assets");
    WakelockPlus.enable();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      // Sorted by backupSelection followed by isCloud
      final localAlbums = await _localAlbumRepository.getBackupAlbums();

      if (Platform.isOhos) {
        try {
          await _nativeSyncApi.startBackgroundTransfer();
        } catch (_) {
          // ignore start failures
        }
      }

      for (final album in localAlbums) {
        if (isCancelled) {
          _log.warning("Hashing cancelled. Stopped processing albums.");
          break;
        }

        final assetsToHash = await _localAlbumRepository.getAssetsToHash(album.id);

        toHashCount = assetsToHash.length;
        hashedCount = 0;

        if (assetsToHash.isNotEmpty) {
          await _hashAssets(album, assetsToHash);
        }
      }
    } on PlatformException catch (e) {
      if (e.code == _kHashCancelledCode) {
        _log.warning("Hashing cancelled by platform");
        return;
      }
    } catch (e, s) {
      _log.severe("Error during hashing", e, s);
    }

    WakelockPlus.disable();

    stopwatch.stop();
    _log.info("Hashing took - ${stopwatch.elapsedMilliseconds}ms");

    if (Platform.isOhos) {
      try {
        await _nativeSyncApi.stopBackgroundTransfer();
      } catch (_) {
        // ignore stop failures
      }
    }
  }

  /// Processes a list of [LocalAsset]s, storing their hash and updating the assets in the DB
  /// with hash for those that were successfully hashed. Hashes are looked up in a table
  /// [LocalAssetHashEntity] by local id. Only missing entries are newly hashed and added to the DB.
  Future<void> _hashAssets(LocalAlbum album, List<LocalAsset> assetsToHash) async {
    final toHash = <String, LocalAsset>{};
    final cloudTempPaths = <String>[];

    int bytesProcessed = 0;
    int videosInBatch = 0;
    File? file;

    for (final asset in assetsToHash) {
      if (isCancelled) {
        _log.warning("Hashing cancelled. Stopped processing assets.");
        return;
      }

      final isIcloudAsset = await _isIcloudOnlyAsset(asset);

      if (isIcloudAsset) {
        file = await _storageRepository.getFileForAsset(asset.id);
        if (file == null) {
          _log.warning(
            "Cannot download iCloud asset ${asset.id} for hashing (album: ${album.name}, name: ${asset.name})",
          );
          continue;
        }
        cloudTempPaths.add(file.path);
        toHash[asset.id] = asset;
      } else {
        toHash[asset.id] = asset;
      }

      if (toHash.length == _batchSize) {
        await _processBatch(album, toHash);
        toHash.clear();
      }
    }

    await _processBatch(album, toHash);

    // 清理云端资产临时文件
    for (final path in cloudTempPaths) {
      try {
        await File(path).delete();
      } catch (_) {
        // ignore cleanup errors
      }
    }
  }

  Future<bool> _isIcloudOnlyAsset(LocalAsset asset) async {
    try {
      final entity = await _storageRepository.getAssetEntityForAsset(asset);
      if (entity == null) {
        return false;
      }
      return !(await entity.isLocallyAvailable(isOrigin: true));
    } catch (e, s) {
      _log.warning("Failed to check local availability for asset ${asset.id}", e, s);
      return false;
    }
  }

  /// Processes a batch of assets.
  Future<void> _processBatch(LocalAlbum album, Map<String, LocalAsset> toHash) async {
    if (toHash.isEmpty) {
      return;
    }

    _log.fine("Hashing ${toHash.length} files");

    final hashed = <String, String>{};
    final hashResults = await _nativeSyncApi.hashAssets(
      toHash.keys.toList(),
      allowNetworkAccess: album.backupSelection == BackupSelection.selected,
    );
    assert(
      hashResults.length == toHash.length,
      "Hashes length does not match toHash length: ${hashResults.length} != ${toHash.length}",
    );

    for (int i = 0; i < hashResults.length; i++) {
      if (isCancelled) {
        _log.warning("Hashing cancelled. Stopped processing batch.");
        return;
      }

      final hashResult = hashResults[i];
      final asset = toHash[hashResult.assetId];
      if (hashResult.hash != null) {
        hashed[hashResult.assetId] = hashResult.hash!;
      } else {
        final asset = toHash[hashResult.assetId];
        _log.warning(
          "Failed to hash asset with id: ${hashResult.assetId}, name: ${asset?.name}, createdAt: ${asset?.createdAt}, from album: ${album.name}. Error: ${hashResult.error ?? "unknown"}",
        );

      hashedCount++;

      if (Platform.isOhos && toHash.isNotEmpty && toHashCount > 0) {
        final progress = (hashedCount.toDouble() / toHashCount.toDouble()) * 100;
        final name = asset.name;
        try {
          await _nativeSyncApi.updateBackgroundTransferProgress(progress, "正在Hash ${album.name}", name);
        } catch (_) {
          // ignore progress failures
        }
      }
    }

    _log.fine("Hashed ${hashed.length}/${toHash.length} assets");

    await _localAssetRepository.updateHashes(hashed);
  }
}
