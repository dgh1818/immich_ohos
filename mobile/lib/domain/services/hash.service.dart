import 'dart:async';

import 'package:flutter/services.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_asset.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/trashed_local_asset.repository.dart';
import 'package:logging/logging.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:background_downloader/background_downloader.dart';

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';

const String _kHashCancelledCode = "HASH_CANCELLED";

class HashService {
  final int _batchSize;
  final DriftLocalAlbumRepository _localAlbumRepository;
  final DriftLocalAssetRepository _localAssetRepository;
  final NativeSyncApiOhos _nativeSyncApi;
  final DriftTrashedLocalAssetRepository _trashedLocalAssetRepository;
  final bool Function()? _cancelChecker;
  final _log = Logger('HashService');

  HashService({
    required DriftLocalAlbumRepository localAlbumRepository,
    required DriftLocalAssetRepository localAssetRepository,
    required NativeSyncApiOhos nativeSyncApi,
    required DriftTrashedLocalAssetRepository trashedLocalAssetRepository,
    bool Function()? cancelChecker,
    int? batchSize,
  }) : _localAlbumRepository = localAlbumRepository,
       _localAssetRepository = localAssetRepository,
       _nativeSyncApi = nativeSyncApi,
       _trashedLocalAssetRepository = trashedLocalAssetRepository,
       _cancelChecker = cancelChecker,
       _batchSize = batchSize ?? kBatchHashFileLimit;

  bool get isCancelled => _cancelChecker?.call() ?? false;
  int hashedCount = 0;
  int toHashCount = 0;
  bool _startedBackgroundTransfer = false;

  Future<void> hashAssets() async {
    _log.info("Starting hashing of assets");

    //hash资产时避免息屏
    unawaited(WakelockPlus.enable());

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      // Migrate hashes from cloud ID to local ID so we don't have to re-hash them
      await _localAssetRepository.reconcileHashesFromCloudId();

      // Sorted by backupSelection followed by isCloud
      final localAlbums = await _localAlbumRepository.getBackupAlbums();

      for (final album in localAlbums) {
        if (isCancelled) {
          _log.warning("Hashing cancelled. Stopped processing albums.");
          break;
        }

        final assetsToHash = await _localAlbumRepository.getAssetsToHash(album.id);

        //开启后台保活
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
      if (CurrentPlatform.isAndroid && localAlbums.isNotEmpty) {
        final backupAlbumIds = localAlbums.map((e) => e.id);
        final trashedToHash = await _trashedLocalAssetRepository.getAssetsToHash(backupAlbumIds);
        if (trashedToHash.isNotEmpty) {
          final pseudoAlbum = LocalAlbum(id: '-pseudoAlbum', name: 'Trash', updatedAt: DateTime.now());
          await _hashAssets(pseudoAlbum, trashedToHash, isTrashed: true);
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
      unawaited(WakelockPlus.disable());
      stopwatch.stop();
      _log.info("Hashing took - ${stopwatch.elapsedMilliseconds}ms");

      if (_startedBackgroundTransfer && Platform.isOhos) {
        final backupEnabled = Store.get(StoreKey.enableBackup, false);
        if (!backupEnabled) {
          try {
            await _nativeSyncApi.stopBackgroundTransfer();
          } catch (_) {
            // ignore stop failures
          }
        } else {
          unawaited(() async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            try {
              final backupTasks = await FileDownloader().allTasks(group: kBackupGroup);
              final livePhotoTasks = await FileDownloader().allTasks(group: kBackupLivePhotoGroup);
              if (backupTasks.isEmpty && livePhotoTasks.isEmpty) {
                await _nativeSyncApi.stopBackgroundTransfer();
              }
            } catch (_) {
              // ignore stop failures
            }
          }());
        }
      }
    }

    stopwatch.stop();
    _log.info("Hashing took - ${stopwatch.elapsedMilliseconds}ms");
  }

  /// Processes a list of [LocalAsset]s, storing their hash and updating the assets in the DB
  /// with hash for those that were successfully hashed. Hashes are looked up in a table
  /// [LocalAssetHashEntity] by local id. Only missing entries are newly hashed and added to the DB.
  Future<void> _hashAssets(LocalAlbum album, List<LocalAsset> assetsToHash, {bool isTrashed = false}) async {
    final toHash = <String, LocalAsset>{};

    for (final asset in assetsToHash) {
      if (isCancelled) {
        _log.warning("Hashing cancelled. Stopped processing assets.");
        return;
      }

      toHash[asset.id] = asset;
      if (toHash.length == _batchSize) {
        await _processBatch(album, toHash, isTrashed);
        toHash.clear();
      }
    }

    await _processBatch(album, toHash, isTrashed);
  }

  /// Processes a batch of assets.
  Future<void> _processBatch(LocalAlbum album, Map<String, LocalAsset> toHash, bool isTrashed) async {
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
      //因hash过程中可能忽略云端资产，所以hash结果可能为空
      if (hashResult.hash != null && hashResult.hash!.isNotEmpty) {
        hashed[hashResult.assetId] = hashResult.hash!;
      } else {
        final asset = toHash[hashResult.assetId];
        _log.warning(
          "Failed to hash asset with id: ${hashResult.assetId}, name: ${asset?.name}, createdAt: ${asset?.createdAt}, from album: ${album.name}. Error: ${hashResult.error ?? "unknown"}",
        );
      }

      hashedCount++;
      //更新后台保活通知进度
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
    if (isTrashed) {
      await _trashedLocalAssetRepository.updateHashes(hashed);
    } else {
      await _localAssetRepository.updateHashes(hashed);
    }
  }
}
