<<<<<<< HEAD
import 'dart:convert';
import 'dart:io';

=======
import 'package:flutter/services.dart';
>>>>>>> v2.2.0
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
<<<<<<< HEAD
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
=======
import 'package:immich_mobile/platform/native_sync_api.g.dart';
>>>>>>> v2.2.0
import 'package:logging/logging.dart';

const String _kHashCancelledCode = "HASH_CANCELLED";

class HashService {
  final int _batchSize;
  final DriftLocalAlbumRepository _localAlbumRepository;
  final DriftLocalAssetRepository _localAssetRepository;
<<<<<<< HEAD
  final StorageRepository _storageRepository;
  final NativeSyncApiOhos _nativeSyncApi;
=======
  final NativeSyncApi _nativeSyncApi;
>>>>>>> v2.2.0
  final bool Function()? _cancelChecker;
  final _log = Logger('HashService');

  HashService({
    required DriftLocalAlbumRepository localAlbumRepository,
    required DriftLocalAssetRepository localAssetRepository,
<<<<<<< HEAD
    required StorageRepository storageRepository,
    required NativeSyncApiOhos nativeSyncApi,
=======
    required NativeSyncApi nativeSyncApi,
>>>>>>> v2.2.0
    bool Function()? cancelChecker,
    int? batchSize,
  }) : _localAlbumRepository = localAlbumRepository,
       _localAssetRepository = localAssetRepository,
       _cancelChecker = cancelChecker,
       _nativeSyncApi = nativeSyncApi,
       _batchSize = batchSize ?? kBatchHashFileLimit;

  bool get isCancelled => _cancelChecker?.call() ?? false;

  Future<void> hashAssets() async {
    _log.info("Starting hashing of assets");
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      // Sorted by backupSelection followed by isCloud
      final localAlbums = await _localAlbumRepository.getBackupAlbums();

      for (final album in localAlbums) {
        if (isCancelled) {
          _log.warning("Hashing cancelled. Stopped processing albums.");
          break;
        }

        final assetsToHash = await _localAlbumRepository.getAssetsToHash(album.id);
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

    stopwatch.stop();
    _log.info("Hashing took - ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Processes a list of [LocalAsset]s, storing their hash and updating the assets in the DB
  /// with hash for those that were successfully hashed. Hashes are looked up in a table
  /// [LocalAssetHashEntity] by local id. Only missing entries are newly hashed and added to the DB.
  Future<void> _hashAssets(LocalAlbum album, List<LocalAsset> assetsToHash) async {
<<<<<<< HEAD
    int bytesProcessed = 0;
    final toHash = <_AssetToPath>[];
    File? file;
=======
    final toHash = <String, LocalAsset>{};
>>>>>>> v2.2.0

    for (final asset in assetsToHash) {
      if (isCancelled) {
        _log.warning("Hashing cancelled. Stopped processing assets.");
        return;
      }

<<<<<<< HEAD
      // final file = await _storageRepository.getFileForAsset(asset.id);
      // if (file == null) {
      //   _log.warning(
      //     "Cannot get file for asset ${asset.id}, name: ${asset.name}, created on: ${asset.createdAt} from album: ${album.name}",
      //   );
      //   continue;
      // }

      //bytesProcessed += await file.length();
      toHash.add(_AssetToPath(asset: asset, path: asset.id));

      //if (toHash.length >= batchFileLimit || bytesProcessed >= batchSizeLimit) {
        await _processBatch(album, toHash);
        toHash.clear();
        bytesProcessed = 0;
      //}
=======
      toHash[asset.id] = asset;
      if (toHash.length == _batchSize) {
        await _processBatch(album, toHash);
        toHash.clear();
      }
>>>>>>> v2.2.0
    }

    await _processBatch(album, toHash);
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
      if (hashResult.hash != null) {
        hashed[hashResult.assetId] = hashResult.hash!;
      } else {
        final asset = toHash[hashResult.assetId];
        _log.warning(
          "Failed to hash asset with id: ${hashResult.assetId}, name: ${asset?.name}, createdAt: ${asset?.createdAt}, from album: ${album.name}. Error: ${hashResult.error ?? "unknown"}",
        );
      }
    }

    _log.fine("Hashed ${hashed.length}/${toHash.length} assets");

    await _localAssetRepository.updateHashes(hashed);
  }
}
