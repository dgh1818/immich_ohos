import 'dart:convert';
import 'dart:io';

import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:logging/logging.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

class HashService {
  final int batchSizeLimit;
  final int batchFileLimit;
  final DriftLocalAlbumRepository _localAlbumRepository;
  final DriftLocalAssetRepository _localAssetRepository;
  final StorageRepository _storageRepository;
  final NativeSyncApiOhos _nativeSyncApi;
  final bool Function()? _cancelChecker;
  final _log = Logger('HashService');

  HashService({
    required DriftLocalAlbumRepository localAlbumRepository,
    required DriftLocalAssetRepository localAssetRepository,
    required StorageRepository storageRepository,
    required NativeSyncApiOhos nativeSyncApi,
    bool Function()? cancelChecker,
    this.batchSizeLimit = kBatchHashSizeLimit,
    this.batchFileLimit = kBatchHashFileLimit,
  }) : _localAlbumRepository = localAlbumRepository,
       _localAssetRepository = localAssetRepository,
       _storageRepository = storageRepository,
       _cancelChecker = cancelChecker,
       _nativeSyncApi = nativeSyncApi;

  bool get isCancelled => _cancelChecker?.call() ?? false;
  int hashedCount = 0;
  int toHashCount = 0;

  Future<void> hashAssets() async {
    _log.info("Starting hashing of assets");
    WakelockPlus.enable();

    final Stopwatch stopwatch = Stopwatch()..start();
    // Sorted by backupSelection followed by isCloud
    final localAlbums = await _localAlbumRepository.getAll(
      sortBy: {SortLocalAlbumsBy.backupSelection, SortLocalAlbumsBy.isIosSharedAlbum},
    );

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
    int bytesProcessed = 0;
    int videosInBatch = 0;
    final toHash = <_AssetToPath>[];
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
        toHash.add(_AssetToPath(asset: asset, path: file.path, deleteAfterHash: true));
      } else {
        toHash.add(_AssetToPath(asset: asset, path: asset.id));
      }

      if (asset.isVideo) {
        videosInBatch++;
      }

      if (toHash.length >= batchFileLimit || videosInBatch >= 5) {
        await _processBatch(album, toHash);
        toHash.clear();
        bytesProcessed = 0;
        videosInBatch = 0;
      }
    }

    await _processBatch(album, toHash);
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
  Future<void> _processBatch(LocalAlbum album, List<_AssetToPath> toHash) async {
    if (toHash.isEmpty) {
      return;
    }

    _log.fine("Hashing ${toHash.length} files");

    final hashed = <LocalAsset>[];
    final tempPaths = toHash.where((e) => e.deleteAfterHash).map((e) => e.path).toList();

    final hashes = await _nativeSyncApi.hashPaths(toHash.map((e) => e.path).toList());
    assert(
      hashes.length == toHash.length,
      "Hashes length does not match toHash length: ${hashes.length} != ${toHash.length}",
    );

    for (int i = 0; i < hashes.length; i++) {
      if (isCancelled) {
        _log.warning("Hashing cancelled. Stopped processing batch.");
        return;
      }

      final hash = hashes[i];
      final asset = toHash[i].asset;
      if (hash?.length == 20) {
        hashed.add(asset.copyWith(checksum: base64.encode(hash!)));
      } else {
        _log.warning(
          "Failed to hash file for ${asset.id}: ${asset.name} created at ${asset.createdAt} from album: ${album.name}",
        );
      }

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
    //await _storageRepository.clearCache();

    for (final path in tempPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e, s) {
        _log.warning("Failed to delete temp file after hashing: $path", e, s);
      }
    }
  }
}

class _AssetToPath {
  final LocalAsset asset;
  final String path;

  /// Whether the file at [path] should be deleted after hashing (e.g., temp download).
  final bool deleteAfterHash;

  const _AssetToPath({required this.asset, required this.path, this.deleteAfterHash = false});
}
