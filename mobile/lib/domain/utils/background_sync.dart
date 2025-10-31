import 'dart:async';

import 'package:immich_mobile/domain/utils/sync_linked_album.dart';
import 'package:immich_mobile/providers/infrastructure/sync.provider.dart';
import 'package:immich_mobile/utils/isolate.dart';
import 'package:worker_manager/worker_manager.dart';

typedef SyncCallback = void Function();
typedef SyncCallbackWithResult<T> = void Function(T result);
typedef SyncErrorCallback = void Function(String error);

class BackgroundSyncManager {
  final SyncCallback? onRemoteSyncStart;
  final SyncCallbackWithResult<bool?>? onRemoteSyncComplete;
  final SyncErrorCallback? onRemoteSyncError;

  final SyncCallback? onLocalSyncStart;
  final SyncCallback? onLocalSyncComplete;
  final SyncErrorCallback? onLocalSyncError;

  final SyncCallback? onHashingStart;
  final SyncCallback? onHashingComplete;
  final SyncErrorCallback? onHashingError;

  Cancelable<bool?>? _syncTask;
  Cancelable<void>? _syncWebsocketTask;
  Cancelable<void>? _deviceAlbumSyncTask;
  Cancelable<void>? _linkedAlbumSyncTask;
  Cancelable<void>? _hashTask;

  BackgroundSyncManager({
    this.onRemoteSyncStart,
    this.onRemoteSyncComplete,
    this.onRemoteSyncError,
    this.onLocalSyncStart,
    this.onLocalSyncComplete,
    this.onLocalSyncError,
    this.onHashingStart,
    this.onHashingComplete,
    this.onHashingError,
  });

  // Future<void> isolate() async {
  //   //Logger log = Logger("IsolateLogger");
  //   // BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  //   // DartPluginRegistrant.ensureInitialized();
  //   // log.info("finish ensureInitialized");

  //   // final db = await Bootstrap.initIsar();
  //   // final logDb = DriftLogger();
  //   // await Bootstrap.initDomain(db, logDb, shouldBufferLogs: false);
  //   // final ref = ProviderContainer(
  //   //   overrides: [
  //   //     // TODO: Remove once isar is removed
  //   //     dbProvider.overrideWithValue(db),
  //   //     isarProvider.overrideWithValue(db),
  //   //     cancellationProvider.overrideWithValue(cancelledChecker),
  //   //   ],
  //   // );

  //   //final drift_db = Drift();

  //   try {
  //     //HttpSSLOptions.apply(applyNative: false);
  //    await ref.read(localSyncServiceProvider).sync(full: true)
  //   } on CanceledError {
  //     log.warning("Computation cancelled ${debugLabel == null ? '' : ' for $debugLabel'}");
  //   } catch (error, stack) {
  //     log.severe("Error in runInIsolateGentle ${debugLabel == null ? '' : ' for $debugLabel'}", error, stack);
  //   } finally {
  //     try {
  //       await LogService.I.flush();
  //       await logDb.close();
  //       await ref.read(driftProvider).close();

  //       // Close Isar safely
  //       try {
  //         final isar = ref.read(isarProvider);
  //         if (isar.isOpen) {
  //           await isar.close();
  //         }
  //       } catch (e) {
  //         debugPrint("Error closing Isar: $e");
  //       }

  //       ref.dispose();
  //     } catch (error) {
  //       debugPrint("Error closing resources in isolate: $error");
  //     } finally {
  //       ref.dispose();
  //       // Delay to ensure all resources are released
  //       await Future.delayed(const Duration(seconds: 2));
  //     }
  //   }
  //   return null;
  // }

  Future<void> cancel() async {
    final futures = <Future>[];

    if (_syncTask != null) {
      futures.add(_syncTask!.future);
    }
    _syncTask?.cancel();
    _syncTask = null;

    if (_syncWebsocketTask != null) {
      futures.add(_syncWebsocketTask!.future);
    }
    _syncWebsocketTask?.cancel();
    _syncWebsocketTask = null;

    if (_linkedAlbumSyncTask != null) {
      futures.add(_linkedAlbumSyncTask!.future);
    }
    _linkedAlbumSyncTask?.cancel();
    _linkedAlbumSyncTask = null;

    try {
      await Future.wait(futures);
    } on CanceledError {
      // Ignore cancellation errors
    }
  }

  Future<void> cancelLocal() async {
    final futures = <Future>[];

    if (_hashTask != null) {
      futures.add(_hashTask!.future);
    }
    _hashTask?.cancel();
    _hashTask = null;

    if (_deviceAlbumSyncTask != null) {
      futures.add(_deviceAlbumSyncTask!.future);
    }
    _deviceAlbumSyncTask?.cancel();
    _deviceAlbumSyncTask = null;

    try {
      await Future.wait(futures);
    } on CanceledError {
      // Ignore cancellation errors
    }
  }

  // No need to cancel the task, as it can also be run when the user logs out
  Future<void> syncLocal({bool full = false}) {
    if (_deviceAlbumSyncTask != null) {
      return _deviceAlbumSyncTask!.future;
    }

    onLocalSyncStart?.call();

    // We use a ternary operator to avoid [_deviceAlbumSyncTask] from being
    // captured by the closure passed to [runInIsolateGentle].
    _deviceAlbumSyncTask = full
        ? runInIsolateGentle(
            computation: (ref) => ref.read(localSyncServiceProvider).sync(full: true),
            debugLabel: 'local-sync-full-true',
          )
        : runInIsolateGentle(
            computation: (ref) => ref.read(localSyncServiceProvider).sync(full: false),
            debugLabel: 'local-sync-full-false',
          );

    return _deviceAlbumSyncTask!
        .whenComplete(() {
          _deviceAlbumSyncTask = null;
          onLocalSyncComplete?.call();
        })
        .catchError((error) {
          onLocalSyncError?.call(error.toString());
          _deviceAlbumSyncTask = null;
        });
  }

  // No need to cancel the task, as it can also be run when the user logs out
  Future<void> hashAssets() {
    if (_hashTask != null) {
      return _hashTask!.future;
    }

    onHashingStart?.call();

    _hashTask = runInIsolateGentle(
      computation: (ref) => ref.read(hashServiceProvider).hashAssets(),
      debugLabel: 'hash-assets',
    );

    return _hashTask!
        .whenComplete(() {
          onHashingComplete?.call();
          _hashTask = null;
        })
        .catchError((error) {
          onHashingError?.call(error.toString());
          _hashTask = null;
        });
  }

  Future<bool> syncRemote() {
    if (_syncTask != null) {
      return _syncTask!.future.then((result) => result ?? false).catchError((_) => false);
    }

    onRemoteSyncStart?.call();

    _syncTask = runInIsolateGentle(
      computation: (ref) => ref.read(syncStreamServiceProvider).sync(),
      debugLabel: 'remote-sync',
    );
    return _syncTask!
        .then((result) {
          final success = result ?? false;
          onRemoteSyncComplete?.call(success);
          return success;
        })
        .catchError((error) {
          onRemoteSyncError?.call(error.toString());
          _syncTask = null;
          return false;
        })
        .whenComplete(() {
          _syncTask = null;
        });
  }

  Future<void> syncWebsocketBatch(List<dynamic> batchData) {
    if (_syncWebsocketTask != null) {
      return _syncWebsocketTask!.future;
    }
    _syncWebsocketTask = _handleWsAssetUploadReadyV1Batch(batchData);
    return _syncWebsocketTask!.whenComplete(() {
      _syncWebsocketTask = null;
    });
  }

  Future<void> syncLinkedAlbum() {
    if (_linkedAlbumSyncTask != null) {
      return _linkedAlbumSyncTask!.future;
    }

    _linkedAlbumSyncTask = runInIsolateGentle(computation: syncLinkedAlbumsIsolated, debugLabel: 'linked-album-sync');
    return _linkedAlbumSyncTask!.whenComplete(() {
      _linkedAlbumSyncTask = null;
    });
  }
}

Cancelable<void> _handleWsAssetUploadReadyV1Batch(List<dynamic> batchData) => runInIsolateGentle(
  computation: (ref) => ref.read(syncStreamServiceProvider).handleWsAssetUploadReadyV1Batch(batchData),
  debugLabel: 'websocket-batch',
);
