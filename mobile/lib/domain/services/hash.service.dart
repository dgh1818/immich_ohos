import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:logging/logging.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const String _kHashCancelledCode = "HASH_CANCELLED";

/// Hashes local assets (OHOS), deferring cloud/download handling to the native side.
class HashService {
  final int _batchSize;
  final DriftLocalAlbumRepository _localAlbumRepository;
  final DriftLocalAssetRepository _localAssetRepository;
  final NativeSyncApiOhos _nativeSyncApi;
  final bool Function()? _cancelChecker;
  final _log = Logger('HashService');

  HashService({
    required DriftLocalAlbumRepository localAlbumRepository,
    required DriftLocalAssetRepository localAssetRepository,
    required NativeSyncApiOhos nativeSyncApi,
    bool Function()? cancelChecker,
    int? batchSize,
  }) : _localAlbumRepository = localAlbumRepository,
       _localAssetRepository = localAssetRepository,
       _nativeSyncApi = nativeSyncApi,
       _cancelChecker = cancelChecker,
       _batchSize = batchSize ?? kBatchHashFileLimit;

  bool get isCancelled => _cancelChecker?.call() ?? false;
  int hashedCount = 0;
  int toHashCount = 0;
  bool _startedBackgroundTransfer = false;

  Future<void> hashAssets() async {
    _log.info("Starting hashing of assets");
    WakelockPlus.enable();

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final localAlbums = await _localAlbumRepository.getBackupAlbums();

      for (final album in localAlbums) {
        if (isCancelled) {
          _log.warning("Hashing cancelled. Stopped processing albums.");
          break;
        }

        final assetsToHash = await _localAlbumRepository.getAssetsToHash(album.id);

        if (assetsToHash.isNotEmpty && !_startedBackgroundTransfer && Platform.isOhos) {
          try {
            await _nativeSyncApi.startBackgroundTransfer();
            _startedBackgroundTransfer = true;
          } catch (_) {
            // ignore start failures
          }
        }

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
    } finally {
      WakelockPlus.disable();
      stopwatch.stop();
      _log.info("Hashing took - ${stopwatch.elapsedMilliseconds}ms");

      if (_startedBackgroundTransfer && Platform.isOhos) {
        try {
          await _nativeSyncApi.stopBackgroundTransfer();
        } catch (_) {
          // ignore stop failures
        }
      }
    }
  }

  Future<void> _hashAssets(LocalAlbum album, List<LocalAsset> assetsToHash) async {
    final toHash = <String, LocalAsset>{};

    for (final asset in assetsToHash) {
      if (isCancelled) {
        _log.warning("Hashing cancelled. Stopped processing assets.");
        return;
      }

      debugPrint("Hashing ${asset.name} from album ${album.name}");

      toHash[asset.id] = asset;
      if (toHash.length == _batchSize) {
        debugPrint("Hashing batch of ${toHash.length} assets");
        await _processBatch(album, toHash);
        toHash.clear();
      }
    }

    await _processBatch(album, toHash);
  }

  /// Processes a batch of assets.
  Future<void> _processBatch(LocalAlbum album, Map<String, LocalAsset> toHash) async {
    if (toHash.isEmpty) {
      return;
    }

    debugPrint("Processing batch of ${toHash.length} assets");

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
          "Failed to hash asset with id: ${hashResult.assetId}, name: ${asset?.name}, createdAt: ${asset?.createdAt}, from album: ${album.name}. Error: ${hashResult.error ?? 'unknown'}",
        );
      }

      hashedCount++;

      if (Platform.isOhos && toHashCount > 0) {
        final progress = (hashedCount.toDouble() / toHashCount.toDouble()) * 100;
        final name = asset?.name ?? "";
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
