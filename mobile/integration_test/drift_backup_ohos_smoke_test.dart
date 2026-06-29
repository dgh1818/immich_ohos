import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart' as immich;
import 'package:immich_mobile/domain/models/settings_key.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/entities/local_album.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/local_album_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/entities/local_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/settings.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/main.dart' as app;
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/providers/backup/drift_backup.provider.dart';
import 'package:immich_mobile/providers/infrastructure/db.provider.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';
import 'package:immich_mobile/providers/infrastructure/storage.provider.dart';
import 'package:immich_mobile/repositories/asset_media.repository.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:immich_mobile/utils/bootstrap.dart';
import 'package:integration_test/integration_test.dart';
import 'package:photo_manager/photo_manager.dart';

import 'test_utils/fake_immich_server.dart';

final _testUser = UserDto(
  id: 'integration-drift-backup-user',
  email: 'drift-backup@test.com',
  name: 'Drift Backup Test',
  profileChangedAt: DateTime.utc(2026),
);
const _testAlbumId = 'integration-drift-backup-album';
const _testAssetId = 'integration-drift-backup-asset';
const _testAssetName = 'drift-backup-smoke.jpg';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late Drift drift;
  late FakeImmichServer server;
  late File uploadFile;
  late StorageRepository storageRepository;
  late bool oldBackupEnabled;
  late bool oldBackupUseCellularForPhotos;
  UserDto? oldCurrentUser;
  String? oldAccessToken;
  String? oldDeviceId;
  String? oldServerEndpoint;
  ProviderContainer? container;

  setUpAll(() async {
    await app.initApp();
    (drift, _) = await Bootstrap.initDomain();
  });

  setUp(() async {
    oldCurrentUser = Store.tryGet(StoreKey.currentUser);
    oldAccessToken = Store.tryGet(StoreKey.accessToken);
    oldDeviceId = Store.tryGet(StoreKey.deviceId);
    oldServerEndpoint = Store.tryGet(StoreKey.serverEndpoint);
    oldBackupEnabled = SettingsRepository.instance.appConfig.backup.enabled;
    oldBackupUseCellularForPhotos = SettingsRepository.instance.appConfig.backup.useCellularForPhotos;

    await _resetBackupDownloaderState();
    await _deleteTestRows(drift);

    server = await FakeImmichServer.start();
    await ApiService().resolveAndSetEndpoint(server.endpoint);
    await Store.put(StoreKey.accessToken, 'integration-test-token');
    await Store.put(StoreKey.deviceId, 'integration-test-device');
    await Store.put(StoreKey.currentUser, _testUser);
    await SettingsRepository.instance.write(SettingsKey.backupEnabled, true);
    await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, true);

    uploadFile = await _createUploadFile();
    await _insertBackupCandidate(drift);
    storageRepository = _SmokeStorageRepository(uploadFile);

    container = ProviderContainer(
      overrides: [
        driftProvider.overrideWith(driftOverride(drift)),
        storageRepositoryProvider.overrideWithValue(storageRepository),
        assetMediaRepositoryProvider.overrideWithValue(_SmokeAssetMediaRepository(storageRepository)),
        nativeSyncApiProvider.overrideWithValue(_NoopNativeSyncApiOhos()),
      ],
    );
  });

  tearDown(() async {
    await container?.read(driftBackupProvider.notifier).stopForegroundBackup();
    container?.dispose();
    container = null;

    await _resetBackupDownloaderState();
    await _deleteTestRows(drift);

    if (await uploadFile.exists()) {
      await uploadFile.delete();
    }
    await server.close();

    await SettingsRepository.instance.write(SettingsKey.backupEnabled, oldBackupEnabled);
    await SettingsRepository.instance.write(SettingsKey.backupUseCellularForPhotos, oldBackupUseCellularForPhotos);
    await _restoreStore(StoreKey.currentUser, oldCurrentUser);
    await _restoreStore(StoreKey.accessToken, oldAccessToken);
    await _restoreStore(StoreKey.deviceId, oldDeviceId);
    await _restoreStore(StoreKey.serverEndpoint, oldServerEndpoint);
  });

  testWidgets('drift backup uploads one selected local asset through the background queue', (tester) async {
    final ref = container!;
    final notifier = ref.read(driftBackupProvider.notifier);

    await notifier.getBackupStatus(_testUser.id);
    expect(ref.read(driftBackupProvider).remainderCount, 1);

    await notifier
        .startBackupWithURLSession(_testUser.id)
        .timeout(const Duration(seconds: 30), onTimeout: () => fail('drift backup did not enqueue within 30s'));

    await server.assetUploadReceived.timeout(
      const Duration(seconds: 45),
      onTimeout: () => fail('fake server did not receive /api/assets upload'),
    );

    expect(server.assetUploadRequests, 1);
    expect(server.lastAssetUploadContentType, contains('multipart/form-data'));
    expect(server.lastAssetUploadBody, contains('assetData'));
    expect(server.lastAssetUploadBody, contains(_testAssetName));
    expect(server.lastAssetUploadBody, contains('drift backup smoke'));

    await _waitUntil(
      () => ref.read(driftBackupProvider).backupCount == 1,
      description: 'backup completion status callback',
    );
  });
}

Future<File> _createUploadFile() async {
  final dir = await Directory.systemTemp.createTemp('immich_drift_backup_smoke_');
  final file = File('${dir.path}/$_testAssetName');
  await file.writeAsString('drift backup smoke');
  return file;
}

Future<void> _insertBackupCandidate(Drift drift) async {
  final now = DateTime.utc(2026, 1, 1);
  await drift
      .into(drift.localAlbumEntity)
      .insertOnConflictUpdate(
        LocalAlbumEntityCompanion(
          id: const Value(_testAlbumId),
          name: const Value('Drift Backup Smoke'),
          updatedAt: Value(now),
          backupSelection: const Value(BackupSelection.selected),
        ),
      );
  await drift
      .into(drift.localAssetEntity)
      .insertOnConflictUpdate(
        LocalAssetEntityCompanion(
          id: const Value(_testAssetId),
          name: const Value(_testAssetName),
          checksum: const Value('integration-drift-backup-checksum'),
          type: const Value(immich.AssetType.image),
          createdAt: Value(now),
          updatedAt: Value(now),
          width: const Value(1),
          height: const Value(1),
          durationMs: const Value(0),
          orientation: const Value(0),
          playbackStyle: const Value(immich.AssetPlaybackStyle.image),
          isFavorite: const Value(false),
        ),
      );
  await drift
      .into(drift.localAlbumAssetEntity)
      .insertOnConflictUpdate(
        const LocalAlbumAssetEntityCompanion(albumId: Value(_testAlbumId), assetId: Value(_testAssetId)),
      );
}

Future<void> _deleteTestRows(Drift drift) async {
  await (drift.delete(drift.localAlbumAssetEntity)..where((row) => row.assetId.equals(_testAssetId))).go();
  await (drift.delete(drift.localAssetEntity)..where((row) => row.id.equals(_testAssetId))).go();
  await (drift.delete(drift.localAlbumEntity)..where((row) => row.id.equals(_testAlbumId))).go();
}

Future<void> _resetBackupDownloaderState() async {
  final downloader = FileDownloader();
  await downloader.reset(group: kBackupGroup);
  await downloader.reset(group: kBackupLivePhotoGroup);
  await downloader.database.deleteAllRecords(group: kBackupGroup);
  await downloader.database.deleteAllRecords(group: kBackupLivePhotoGroup);
}

Future<void> _restoreStore<T>(StoreKey<T> key, T? value) async {
  if (value == null) {
    await Store.delete(key);
  } else {
    await Store.put(key, value);
  }
}

Future<void> _waitUntil(
  FutureOr<bool> Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('Timed out waiting for $description');
}

class _SmokeStorageRepository extends StorageRepository {
  _SmokeStorageRepository(this._file);

  final File _file;

  @override
  Future<void> clearCache() async {}

  @override
  Future<AssetEntity?> getAssetEntityForAsset(immich.LocalAsset asset) async {
    return AssetEntity(id: asset.id, typeInt: 1, width: asset.width ?? 1, height: asset.height ?? 1, title: asset.name);
  }

  @override
  Future<File?> getFileForAsset(String assetId) async => _file;
}

class _SmokeAssetMediaRepository extends AssetMediaRepository {
  _SmokeAssetMediaRepository(StorageRepository storageRepository) : super(_NoopNativeSyncApiOhos(), storageRepository);

  @override
  Future<String?> getOriginalFilename(String id) async => _testAssetName;
}

class _NoopNativeSyncApiOhos extends NativeSyncApiOhos {
  @override
  Future<int> startBackgroundTransfer() async => 0;

  @override
  Future<void> updateBackgroundTransferProgress(double progress, String title, String fileName) async {}

  @override
  Future<void> stopBackgroundTransfer() async {}
}
