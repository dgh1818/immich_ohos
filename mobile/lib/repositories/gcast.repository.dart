import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:huawei_cast/huawei_cast.dart';

final gCastRepositoryProvider = Provider((_) {
  return GCastRepository();
});

class GCastRepository {
  final HuaweiCast _huaweiCast = HuaweiCast();
  late final StreamSubscription<HuaweiCastStatus> _statusSubscription;

  void Function(CastSessionState)? onCastStatus;
  void Function(Map<String, dynamic>)? onCastMessage;

  GCastRepository() {
    _statusSubscription = _huaweiCast.statusStream.listen(_handleCastStatus);
  }

  String get receiverName => _huaweiCast.receiverName;

  void _handleCastStatus(HuaweiCastStatus status) {
    onCastStatus?.call(status.state);
    onCastMessage?.call({
      'type': 'RECEIVER_STATUS',
      'status': status.state == CastSessionState.connected ? {'receiverName': status.receiverName} : null,
    });
  }

  Future<void> connect(String assetId) async {
    await _huaweiCast.startCast(assetId);
  }

  Future<void> loadMedia(String assetId) async {
    await _huaweiCast.startCast(assetId);
  }

  FutureOr<dynamic> setMetadata(
    String contentUrl,
    String mediaImage,
    String title,
    int duration, {
    AVSessionType sessionType = AVSessionType.video,
  }) => _huaweiCast.setMetadata(contentUrl, mediaImage, title, duration, sessionType: sessionType);

  FutureOr<dynamic> setCurrentPosition(int position, bool isPlaying) =>
      _huaweiCast.setCurrentPosition(position, isPlaying);

  FutureOr<dynamic> clearSession() => _huaweiCast.clearSession();

  FutureOr<dynamic> play() => _huaweiCast.play();

  FutureOr<dynamic> pause() => _huaweiCast.pause();

  FutureOr<dynamic> seekTo(int position) => _huaweiCast.seekTo(position);

  Future<void> disconnect() async {
    await _huaweiCast.stopCast();
  }

  FutureOr<dynamic> stopCast() => _huaweiCast.stopCast();

  void dispose() {
    _statusSubscription.cancel();
  }
}
