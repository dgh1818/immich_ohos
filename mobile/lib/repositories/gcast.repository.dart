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

  FutureOr<dynamic> setMetadata(String contentUrl, String mediaImage, String title, int duration) async {
    return await _huaweiCast.setMetadata(contentUrl, mediaImage, title, duration);
  }

  FutureOr<dynamic> setCurrentPosition(int position, bool isPlaying) async {
    return await _huaweiCast.setCurrentPosition(position, isPlaying);
  }

  FutureOr<dynamic> clearSession() async {
    return await _huaweiCast.clearSession();
  }

  FutureOr<dynamic> play() async {
    return await _huaweiCast.play();
  }

  FutureOr<dynamic> pause() async {
    return await _huaweiCast.pause();
  }

  FutureOr<dynamic> seekTo(int position) async {
    return await _huaweiCast.seekTo(position);
  }

  Future<void> disconnect() async {
    await _huaweiCast.stopCast();
  }

  FutureOr<dynamic> stopCast() async {
    return await _huaweiCast.stopCast();
  }

  /*
   * The upstream Google Cast repository also used getSessionId() and
   * sendMessage() helpers backed by Chromecast namespaces such as
   * kNamespaceReceiver and the CC1AD845 default receiver app.
   *
   * We intentionally keep those functions disabled on OHOS because the
   * AVCastPicker/AVSession backend does not expose a Chromecast-compatible
   * namespace transport channel to Flutter.
   */
  /*
  String? getSessionId() {
    return null;
  }

  void sendMessage(String namespace, Map<String, dynamic> message) {}
  */

  void dispose() {
    _statusSubscription.cancel();
  }
}
