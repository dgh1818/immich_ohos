import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/data/data_controller.dart';
import 'package:immich_mobile/data/store.dart';
import 'package:immich_mobile/domain/services/hash.service.dart';
import 'package:immich_mobile/domain/services/local_sync.service.dart';
import 'package:immich_mobile/domain/services/log.service.dart';
import 'package:immich_mobile/domain/services/sync_stream.service.dart';
// ignore: library_prefixes
import 'package:immich_mobile/entities/store.entity.dart' as dbStore;
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/platform/background_worker_api.g.dart';
import 'package:immich_mobile/platform/background_worker_lock_api.g.dart';
import 'package:immich_mobile/providers/backup/backup.provider.dart';
import 'package:immich_mobile/providers/infrastructure/cancel.provider.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/infrastructure/sync.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/services/auth.service.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/services/localization.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:immich_mobile/wm_executor.dart';
import 'package:logging/logging.dart';

Future<dynamic> _recordNativeDiagnostic(Logger logger, MethodCall call) async {
  if (call.method != 'log') {
    throw MissingPluginException('Unknown native background diagnostic method: ${call.method}');
  }
  final args = call.arguments as Map<Object?, Object?>?;
  final level = args?['level'] as String? ?? 'info';
  final timestamp = args?['timestamp'] as String? ?? 'unknown-time';
  final message = args?['message'] as String? ?? '<empty native message>';
  final formatted = 'OHOS ArkTS background [$timestamp] $message';
  switch (level) {
    case 'warning':
      logger.warning(formatted);
    case 'severe':
      logger.severe(formatted);
    default:
      logger.info(formatted);
  }
  return null;
}

class BackgroundWorkerFgService {
  final BackgroundWorkerFgHostApi _foregroundHostApi;
  final Logger _logger = Logger('BackgroundWorkerFgService');
  bool _nativeLogBridgeInitialized = false;

  BackgroundWorkerFgService(this._foregroundHostApi);

  Future<void> _initializeNativeLogBridge() async {
    if (_nativeLogBridgeInitialized) {
      return;
    }
    if (Logger.root.level.value > Level.INFO.value) {
      Logger.root.level = Level.INFO;
      _logger.info('Background diagnostics lowered the foreground log threshold to INFO for this process');
    }
    _nativeDiagnosticChannel.setMethodCallHandler((call) => _recordNativeDiagnostic(_logger, call));
    try {
      final ready = await _nativeDiagnosticChannel.invokeMethod<bool>('ready');
      _nativeLogBridgeInitialized = ready == true;
      _logger.info('Foreground native log bridge handshake completed: ready=$ready');
    } catch (error, stack) {
      _logger.warning('Foreground native log bridge handshake failed; native details remain in HiLog', error, stack);
    }
  }

  static const _nativeDiagnosticChannel = MethodChannel('immich/background_worker_diagnostics');

  // TODO: Move this call to native side once old timeline is removed
  Future<void> enable() async {
    await _initializeNativeLogBridge();
    _logger.info('Requesting native background worker registration');
    try {
      await _foregroundHostApi.enable();
      _logger.info('Native background worker registration call completed');
    } catch (error, stack) {
      _logger.severe('Native background worker registration failed', error, stack);
      rethrow;
    }
  }

  Future<void> saveNotificationMessage(String title, String body) async {
    await _initializeNativeLogBridge();
    await _foregroundHostApi.saveNotificationMessage(title, body);
  }

  Future<void> configure({int? minimumDelaySeconds, bool? requireCharging}) async {
    await _initializeNativeLogBridge();
    final backup = SettingsRepository.instance.appConfig.backup;
    final settings = BackgroundWorkerSettings(
      minimumDelaySeconds: minimumDelaySeconds ?? backup.triggerDelay,
      requiresCharging: requireCharging ?? backup.requireCharging,
    );
    _logger.info(
      'Configuring native background worker: minimumDelaySeconds=${settings.minimumDelaySeconds}, '
      'requiresCharging=${settings.requiresCharging}',
    );
    try {
      await _foregroundHostApi.configure(settings);
      _logger.info('Native background worker configuration call completed');
    } catch (error, stack) {
      _logger.severe('Native background worker configuration failed', error, stack);
      rethrow;
    }
  }

  // ignore: unused-code
  Future<void> disable() async {
    await _initializeNativeLogBridge();
    _logger.info('Disabling native background worker registration');
    try {
      await _foregroundHostApi.disable();
      _logger.info('Native background worker disable call completed');
    } catch (error, stack) {
      _logger.severe('Native background worker disable call failed', error, stack);
      rethrow;
    }
  }

  Future<bool> wasLaunchedInBackground() async {
    await _initializeNativeLogBridge();
    return _foregroundHostApi.wasLaunchedInBackground();
  }
}

class BackgroundWorkerBgService extends BackgroundWorkerFlutterApi {
  static const _nativeDiagnosticChannel = MethodChannel('immich/background_worker_diagnostics');
  ProviderContainer? _ref;
  final DataController _dataController;
  final BackgroundWorkerBgHostApi _backgroundHostApi;
  final _cancellationToken = Completer<void>();
  final Logger _logger = Logger('BackgroundWorkerBgService');
  late LocalSyncService _localSyncService;
  late SyncStreamService _remoteSyncService;
  late HashService _hashService;

  bool _isCleanedUp = false;

  BackgroundWorkerBgService({
    required this._dataController,
    required ApiService apiService,
    List<Override> overrides = const [],
  }) : _backgroundHostApi = BackgroundWorkerBgHostApi() {
    final ref = ProviderContainer(
      overrides: [
        cancellationProvider.overrideWithValue(_cancellationToken),
        ...Store.overrideWith(dataController: _dataController, apiService: apiService),
        ...overrides,
      ],
    );
    _ref = ref;
    _localSyncService = ref.read(localSyncServiceProvider);
    _remoteSyncService = ref.read(syncStreamServiceProvider);
    _hashService = ref.read(hashServiceProvider);
    _nativeDiagnosticChannel.setMethodCallHandler((call) => _recordNativeDiagnostic(_logger, call));
    BackgroundWorkerFlutterApi.setUp(this);
  }

  Future<void> initializeNativeLogBridge() async {
    try {
      final ready = await _nativeDiagnosticChannel.invokeMethod<bool>('ready');
      _logger.info('Native background log bridge handshake completed: ready=$ready');
    } catch (error, stack) {
      _logger.warning('Native background log bridge handshake failed; native details remain in HiLog', error, stack);
    }
  }

  bool get _isBackupEnabled => SettingsRepository.instance.appConfig.backup.enabled;

  Future<void> init() async {
    try {
      _logger.info('Background worker Dart service initialization started');
      final initSteps = <Future<void>>[
        _runStage('loadTranslations', loadTranslations),
        _runStage('workerManagerPatch.init', () => workerManagerPatch.init(dynamicSpawning: true)),
        // Initialize the file downloader.
        _runStage(
          'FileDownloader.configure',
          () => FileDownloader().configure(
            globalConfig: [
              // maxConcurrent: 6, maxConcurrentByHost(server):6, maxConcurrentByGroup: 3
              (Config.holdingQueue, (6, 6, 3)),
              // On Android, if files are larger than 256MB, run in foreground service
              (Config.runInForegroundIfFileLargerThan, 256),
            ],
          ),
        ),
        _runStage(
          'trackTasksInGroup(live photo downloads)',
          () => FileDownloader().trackTasksInGroup(kDownloadGroupLivePhoto, markDownloadedComplete: false),
        ),
        _runStage('trackTasks', () => FileDownloader().trackTasks()),
      ];
      final authService = _ref?.read(authServiceProvider);
      if (authService != null) {
        initSteps.add(_runStage('setOpenApiServiceEndpoint', authService.setOpenApiServiceEndpoint));
      }
      await Future.wait(initSteps);

      _logger.info('Configuring background downloader notifications');
      configureFileDownloaderNotifications();
      _logger.info('Background downloader notifications configured');

      // Notify the host that the background worker service has been initialized and is ready to use
      await _runStage('native onInitialized handshake', _backgroundHostApi.onInitialized);
    } catch (error, stack) {
      _logger.severe("Failed to initialize background worker", error, stack);
      try {
        await _runStage('native close after initialization failure', _backgroundHostApi.close);
      } catch (closeError, closeStack) {
        _logger.severe('Failed to close native background worker after initialization failure', closeError, closeStack);
      }
    }
  }

  Future<T> _runStage<T>(String name, Future<T> Function() action) async {
    _logger.info('Background stage started: $name');
    try {
      final result = await action();
      _logger.info('Background stage completed: $name');
      return result;
    } catch (error, stack) {
      _logger.severe('Background stage failed: $name', error, stack);
      rethrow;
    }
  }

  @override
  Future<bool> onAndroidUpload(int? maxMinutes) async {
    _logger.info('Native background upload callback received: maxMinutes=$maxMinutes');
    final hashTimeout = Duration(minutes: _isBackupEnabled ? 3 : 6);
    final backupTimeout = maxMinutes != null ? Duration(minutes: maxMinutes - 1) : null;
    await _optimizeDB();
    return _backgroundLoop(
      hashTimeout: hashTimeout,
      backupTimeout: backupTimeout,
      debugLabel: 'Android background upload',
    );
  }

  @override
  Future<void> onIosUpload(bool isRefresh, int? maxSeconds) async {
    _logger.info('iOS background upload started with maxSeconds: ${maxSeconds}s');
    final sw = Stopwatch()..start();
    try {
      final budget = maxSeconds != null ? Duration(seconds: maxSeconds - 1) : null;

      // Only for Background Processing tasks
      if (maxSeconds == null) {
        await _optimizeDB();
      }

      // Run sync local, sync remote, hash and backup concurrently so the bg
      // refresh task (20s budget) can make progress on all four instead of
      // racing them sequentially. Hash tolerates stale reads, but a new backup
      // batch waits for the remote sync. The single budget caps the
      // whole batch; no phase needs its own timeout.
      final remoteSync = _remoteSyncService.sync();
      final all = Future.wait<dynamic>([
        _localSyncService.sync(),
        remoteSync,
        _hashService.hashAssets(),
        _handleBackup(
          remoteSync: remoteSync.then((ok) => ok && !_cancellationToken.isCompleted).catchError((_) => false),
        ),
      ]);
      if (budget != null) {
        await all.timeout(
          budget,
          onTimeout: () {
            if (!_cancellationToken.isCompleted) {
              _logger.warning("iOS background upload timed out after ${budget.inSeconds}s, cancelling tasks");
              _cancellationToken.complete();
            }
            return <dynamic>[];
          },
        );
      } else {
        await all;
      }
    } catch (error, stack) {
      _logger.severe("Failed to complete iOS background upload", error, stack);
    } finally {
      sw.stop();
      _logger.info("iOS background upload completed in ${sw.elapsed.inSeconds}s");
      await _cleanup();
    }
  }

  Future<bool> _backgroundLoop({
    required Duration hashTimeout,
    required Duration? backupTimeout,
    required String debugLabel,
  }) async {
    _logger.info(
      '$debugLabel started hashTimeout: ${hashTimeout.inSeconds}s, backupTimeout: ${backupTimeout?.inMinutes ?? '~'}m',
    );
    final sw = Stopwatch()..start();
    try {
      if (!await _runStage('local sync, remote sync, and hashing', () => _syncAssets(hashTimeout: hashTimeout))) {
        _logger.warning("Remote sync did not complete successfully, skipping backup");
        return true;
      }

      _logger.info('Synchronization and hashing completed; preparing backup upload');
      final backupFuture = _runStage(
        'background backup enqueue and upload',
        () => _handleBackup(remoteSync: Future.value(true)),
      );
      Timer? cancelTimer;
      if (backupTimeout != null) {
        cancelTimer = Timer(backupTimeout, () {
          if (!_cancellationToken.isCompleted) {
            _logger.warning("$debugLabel timed out after ${backupTimeout.inMinutes}m, cancelling backup");
            _cancellationToken.complete();
          }
        });
      }
      try {
        return await backupFuture;
      } finally {
        cancelTimer?.cancel();
      }
    } catch (error, stack) {
      _logger.severe("Failed to complete $debugLabel", error, stack);
      return true;
    } finally {
      sw.stop();
      _logger.info("$debugLabel completed in ${sw.elapsed.inSeconds}s");
      await _cleanup();
    }
  }

  @override
  Future<void> cancel() async {
    _logger.warning("Background worker cancelled");
    try {
      await _cleanup();
    } catch (error, stack) {
      _logger.severe('Failed to cleanup background worker after cancellation', error, stack);
    }
  }

  Future<void> _optimizeDB() async {
    _logger.info('Optimizing background worker databases');
    try {
      await (_dataController.db.optimize(allTables: true), _dataController.logDb.optimize()).wait;
      _logger.info('Background worker database optimization completed');
    } catch (error, stack) {
      _logger.warning('Background worker database optimization failed', error, stack);
    }
  }

  Future<void> _cleanup() async {
    await runZonedGuarded(_handleCleanup, (error, stack) {
      _logger.severe('Unhandled error during background worker cleanup', error, stack);
    });
  }

  Future<void> _handleCleanup() async {
    // If ref is null, it means the service was never initialized properly
    if (_isCleanedUp || _ref == null) {
      return;
    }

    try {
      _isCleanedUp = true;
      _logger.info('Background worker cleanup started');
      final nativeSyncApi = _ref?.read(nativeSyncApiProvider);

      _logger.info("Cleaning up background worker");
      if (!_cancellationToken.isCompleted) {
        _cancellationToken.complete();
      }

      // Workers share one sqlite connection, so DB teardown must wait until every worker has stopped using it.
      await Future.wait([if (nativeSyncApi != null) nativeSyncApi.cancelHashing()]);
      _logger.info('Native hashing cancellation completed');
      await workerManagerPatch.dispose().catchError((_) async {});
      _logger.info('Worker manager disposed');
      _nativeDiagnosticChannel.setMethodCallHandler(null);
      _logger.info('Native diagnostic channel detached');
      await Future.wait([LogService.I.dispose(), dbStore.Store.dispose()]);
      await _dataController.close();

      _ref?.dispose();
      _ref = null;
    } catch (error, stack) {
      _logger.severe('Failed to cleanup background worker', error, stack);
    }
  }

  Future<bool> _handleBackup({required Future<bool> remoteSync}) async {
    _logger.info('Background backup handler entered');
    final needsRetry = await runZonedGuarded(() async {
      if (_isCleanedUp) {
        return false;
      }

      if (!_isBackupEnabled) {
        _logger.info("Backup is disabled. Skipping backup routine");
        return false;
      }

      final currentUser = _ref?.read(currentUserProvider);
      if (currentUser == null) {
        _logger.warning("No current user found. Skipping backup from background");
        return false;
      }

      if (CurrentPlatform.isIOS || CurrentPlatform.isOhos) {
        _logger.info('Starting URLSession-style background backup path for OHOS/iOS');
        await _ref?.read(backupProvider.notifier).startBackupWithURLSession(currentUser.id, remoteSync);
        _logger.info('URLSession-style background backup call returned');
        return false;
      }

      final uploadService = _ref?.read(foregroundUploadServiceProvider);
      var failed = 0;
      _logger.info('Starting foregroundUploadService background candidate upload path');
      await uploadService?.uploadCandidates(
        currentUser.id,
        _cancellationToken,
        callbacks: UploadCallbacks(onError: (_, _) => failed++),
        useSequentialUpload: true,
      );
      _logger.info("Background backup finished, $failed uploads failed");
      // Retry when at least one upload failed
      return failed > 0;
    }, (error, stack) => _logger.severe('Unhandled error in background backup handler', error, stack));
    _logger.info('Background backup handler finished; needsRetry=${needsRetry ?? true}');
    return needsRetry ?? true;
  }

  Future<bool> _syncAssets({Duration? hashTimeout}) async {
    await _runStage('local media synchronization', _localSyncService.sync);
    if (_isCleanedUp) {
      _logger.warning('Background worker was cleaned up after local synchronization');
      return false;
    }

    final isSuccess = await _runStage('server synchronization', _remoteSyncService.sync);
    if (_isCleanedUp) {
      _logger.warning('Background worker was cleaned up after server synchronization');
      return isSuccess;
    }

    var hashFuture = _hashService.hashAssets();
    if (hashTimeout != null) {
      hashFuture = hashFuture.timeout(
        hashTimeout,
        onTimeout: () {
          // Consume cancellation errors as we want to continue processing
        },
      );
    }

    await _runStage('asset hashing', () => hashFuture);
    return isSuccess;
  }
}

class BackgroundWorkerLockService {
  final BackgroundWorkerLockApi _hostApi;
  const BackgroundWorkerLockService(this._hostApi);

  Future<void> lock() async {
    if (CurrentPlatform.isAndroid) {
      return _hostApi.lock();
    }
  }

  Future<void> unlock() async {
    if (CurrentPlatform.isAndroid) {
      return _hostApi.unlock();
    }
  }
}

/// Native entry invoked from the background worker. If renaming or moving this to a different
/// library, make sure to update the entry points and URI in native workers as well
@pragma('vm:entry-point')
Future<void> backgroundSyncNativeEntrypoint() async {
  final logger = Logger('BackgroundWorkerBgService');
  try {
    developer.log('Background Dart entrypoint entered', name: 'BackgroundWorkerBgService', level: 800);
    WidgetsFlutterBinding.ensureInitialized();
    developer.log('WidgetsFlutterBinding initialized', name: 'BackgroundWorkerBgService', level: 800);
    DartPluginRegistrant.ensureInitialized();
    developer.log('Dart plugin registrant initialized', name: 'BackgroundWorkerBgService', level: 800);

    developer.log('Starting Bootstrap.initDomain', name: 'BackgroundWorkerBgService', level: 800);
    final (dataController, apiService) = await Bootstrap.initDomain(
      shouldBufferLogs: false,
      disableStoreWatching: true,
    );
    logger.info('Bootstrap.initDomain completed; Immich logging is ready');
    if (Logger.root.level.value > Level.INFO.value) {
      Logger.root.level = Level.INFO;
      logger.info('Background diagnostic log level lowered to INFO for this worker isolate');
    }
    logger.info('Creating background worker service');
    final service = BackgroundWorkerBgService(dataController: dataController, apiService: apiService);
    await service.initializeNativeLogBridge();
    await service.init();
  } catch (error, stack) {
    logger.severe('Failed to bootstrap background worker', error, stack);
    // LogService is installed partway through Bootstrap.initDomain. Keep an OS log
    // fallback for failures that happen before its Immich-log subscription exists.
    developer.log(
      'Background worker startup/bootstrap failed; inspect error and stack for the last completed stage',
      name: 'BackgroundWorkerBgService',
      error: error,
      stackTrace: stack,
      level: 1000,
    );
    try {
      // Bootstrap can fail before BackgroundWorkerBgService installs its Dart API.
      // Notify the native worker so it can cancel/complete instead of hanging.
      await BackgroundWorkerBgHostApi().close();
    } catch (closeError, closeStack) {
      logger.severe('Failed to notify native host about background bootstrap failure', closeError, closeStack);
      developer.log(
        'Failed to notify native host about background bootstrap failure',
        name: 'BackgroundWorkerBgService',
        error: closeError,
        stackTrace: closeStack,
        level: 1000,
      );
    }
  }
}
