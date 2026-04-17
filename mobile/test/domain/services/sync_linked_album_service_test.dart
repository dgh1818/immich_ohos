import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/services/sync_linked_album.service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/album.stub.dart';
import '../../infrastructure/repository.mock.dart';

void main() {
  late SyncLinkedAlbumService sut;
  late MockLocalAlbumRepository mockLocalAlbumRepository;
  late MockRemoteAlbumRepository mockRemoteAlbumRepository;
  late MockDriftAlbumApiRepository mockAlbumApiRepository;

  setUp(() {
    mockLocalAlbumRepository = MockLocalAlbumRepository();
    mockRemoteAlbumRepository = MockRemoteAlbumRepository();
    mockAlbumApiRepository = MockDriftAlbumApiRepository();

    sut = SyncLinkedAlbumService(mockLocalAlbumRepository, mockRemoteAlbumRepository, mockAlbumApiRepository);
  });

  test('unlinks local album when linked remote album no longer exists', () async {
    const remoteAlbumId = 'missing-remote-id';
    final localAlbum = LocalAlbumStub.recent.copyWith(linkedRemoteAlbumId: remoteAlbumId);

    when(() => mockLocalAlbumRepository.getBackupAlbums()).thenAnswer((_) async => [localAlbum]);
    when(() => mockRemoteAlbumRepository.get(remoteAlbumId)).thenAnswer((_) async => null);
    when(() => mockLocalAlbumRepository.unlinkRemoteAlbum(localAlbum.id)).thenAnswer((_) async {});

    await sut.syncLinkedAlbums('user-id');

    verify(() => mockLocalAlbumRepository.unlinkRemoteAlbum(localAlbum.id)).called(1);
    verifyNever(() => mockAlbumApiRepository.addAssets(any(), any()));
  });
}
