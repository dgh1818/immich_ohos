import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/album/local_album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/infrastructure/entities/local_asset.entity.drift.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/local_album.repository.dart';

import '../../test_utils/medium_factory.dart';

void main() {
  late Drift db;
  late MediumFactory mediumFactory;

  setUp(() {
    db = Drift(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    mediumFactory = MediumFactory(db);
  });

  group('getAll', () {
    test('sorts albums by backupSelection & isIosSharedAlbum', () async {
      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: '1', backupSelection: BackupSelection.none));
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: '2', backupSelection: BackupSelection.excluded));
      await localAlbumRepo.upsert(
        mediumFactory.localAlbum(id: '3', backupSelection: BackupSelection.selected, isIosSharedAlbum: true),
      );
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: '4', backupSelection: BackupSelection.selected));
      final albums = await localAlbumRepo.getAll(
        sortBy: {SortLocalAlbumsBy.backupSelection, SortLocalAlbumsBy.isIosSharedAlbum},
      );
      expect(albums.length, 4);
      expect(albums[0].id, '4'); // selected
      expect(albums[1].id, '3'); // selected & isIosSharedAlbum
      expect(albums[2].id, '1'); // none
      expect(albums[3].id, '2'); // excluded
    });
  });

  group('upsert', () {
    test('updates OHOS duration without clearing checksum when updatedAt is unchanged', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();
      final updatedAt = DateTime(2026);
      final album = mediumFactory.localAlbum(id: 'album', updatedAt: updatedAt, assetCount: 1);
      final asset = LocalAsset(
        id: 'video',
        name: 'video.mp4',
        type: AssetType.video,
        createdAt: DateTime(2026),
        updatedAt: updatedAt,
        durationMs: 0,
        playbackStyle: AssetPlaybackStyle.video,
        isEdited: false,
      );

      await localAlbumRepo.upsert(album, toUpsert: [asset]);
      await (db.update(
        db.localAssetEntity,
      )..where((row) => row.id.equals(asset.id))).write(const LocalAssetEntityCompanion(checksum: Value('checksum')));

      await localAlbumRepo.upsert(album, toUpsert: [asset.copyWith(durationMs: 123000)]);

      final assets = await localAlbumRepo.getAssets(album.id);
      expect(assets.single.durationMs, 123000);
      expect(assets.single.checksum, 'checksum');
    });
  });

  group('processDelta', () {
    // Regression for #22844: an asset moved (not copied) into a backup album on
    // Android was dropped. The delta reports only the asset's new album, and the
    // stale link to its old album made the per-album delete sweep wipe the asset.
    test('keeps an asset moved to another album that still holds other assets', () async {
      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();

      final moved = _localAsset('moved');
      final other = _localAsset('other');
      await localAlbumRepo.upsert(
        mediumFactory.localAlbum(id: 'src', backupSelection: BackupSelection.none),
        toUpsert: [moved, other],
      );
      final anchor = _localAsset('anchor');
      await localAlbumRepo.upsert(
        mediumFactory.localAlbum(id: 'dst', backupSelection: BackupSelection.selected),
        toUpsert: [anchor],
      );

      // Delta reports the moved asset now living only in the destination album.
      await localAlbumRepo.processDelta(
        updates: [moved],
        deletes: [],
        assetAlbums: {
          'moved': ['dst'],
        },
      );

      // Per-album delete sweep, as sync() runs on Android. src now physically
      // holds only `other`; dst holds `anchor` and the moved asset.
      await localAlbumRepo.syncDeletes('src', ['other']);
      await localAlbumRepo.syncDeletes('dst', ['anchor', 'moved']);

      final dstIds = (await localAlbumRepo.getAssets('dst')).map((a) => a.id).toSet();
      final srcIds = await localAlbumRepo.getAssetIds('src');

      expect(dstIds, contains('moved')); // survived and linked to the backed-up album
      expect(srcIds, isNot(contains('moved'))); // stale source link cleared
      expect(srcIds, contains('other')); // untouched asset stays put
    });

    test('replaces album membership with exactly what the delta reports', () async {
      final localAlbumRepo = mediumFactory.getRepository<DriftLocalAlbumRepository>();

      final moved = _localAsset('moved');
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'src'), toUpsert: [moved]);
      await localAlbumRepo.upsert(mediumFactory.localAlbum(id: 'dst'));

      await localAlbumRepo.processDelta(
        updates: [moved],
        deletes: [],
        assetAlbums: {
          'moved': ['dst'],
        },
      );

      expect(await localAlbumRepo.getAssetIds('src'), isEmpty);
      expect(await localAlbumRepo.getAssetIds('dst'), ['moved']);
    });
  });
}

LocalAsset _localAsset(String id) => LocalAsset(
  id: id,
  name: '$id.jpg',
  type: AssetType.image,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  playbackStyle: AssetPlaybackStyle.image,
  isEdited: false,
);
