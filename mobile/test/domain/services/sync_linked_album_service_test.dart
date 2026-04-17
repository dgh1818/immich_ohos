import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/sync_linked_album.service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/album.stub.dart';
import '../../infrastructure/repository.mock.dart';

void main() {
  late SyncLinkedAlbumService sut;
  late MockLocalAlbumRepository mockLocalAlbumRepo;
  late MockRemoteAlbumRepository mockRemoteAlbumRepo;
  late MockDriftAlbumApiRepository mockAlbumApiRepo;

  setUp(() {
    mockLocalAlbumRepo = MockLocalAlbumRepository();
    mockRemoteAlbumRepo = MockRemoteAlbumRepository();
    mockAlbumApiRepo = MockDriftAlbumApiRepository();

    sut = SyncLinkedAlbumService(mockLocalAlbumRepo, mockRemoteAlbumRepo, mockAlbumApiRepo);

    when(() => mockLocalAlbumRepo.unlinkRemoteAlbum(any())).thenAnswer((_) async {});
  });

  test('unlinks a local album when its linked remote album no longer exists', () async {
    final linkedAlbum = LocalAlbumStub.recent.copyWith(linkedRemoteAlbumId: 'missing-remote-id');

    when(() => mockLocalAlbumRepo.getBackupAlbums()).thenAnswer((_) async => [linkedAlbum]);
    when(() => mockRemoteAlbumRepo.get('missing-remote-id')).thenAnswer((_) async => null);

    await sut.syncLinkedAlbums('user-id');

    verify(() => mockLocalAlbumRepo.unlinkRemoteAlbum(linkedAlbum.id)).called(1);
    verifyNever(() => mockRemoteAlbumRepo.getLinkedAssetIds(any(), any(), any()));
    verifyNever(() => mockAlbumApiRepo.addAssets(any(), any()));
  });
}
