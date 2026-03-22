import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:huawei_cast/huawei_cast.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/models/sessions/session_create_response.model.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_value_provider.dart';
import 'package:immich_mobile/repositories/gcast.repository.dart';
import 'package:immich_mobile/repositories/sessions_api.repository.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';

final gCastServiceProvider = Provider<GCastService>((ref) {
  return GCastService(ref.watch(gCastRepositoryProvider), ref.watch(sessionsAPIRepositoryProvider));
});

class HuaweiCastPickerDestination {
  const HuaweiCastPickerDestination();
}

const _pickerDestination = HuaweiCastPickerDestination();

class GCastService {
  static const String _pickerLabel = 'Open system cast picker';
  static const String _switchDeviceLabel = 'Choose another device';

  final GCastRepository _gCastRepository;
  final SessionsAPIRepository _sessionsApiService;

  SessionCreateResponse? sessionKey;
  String? currentAssetId;
  bool isConnected = false;
  String _receiverName = '';
  BaseAsset? _currentPlaybackAsset;
  String? _preparedPlaybackAssetKey;
  String? _currentPlaybackAssetKey;

  void Function(bool)? onConnectionState;
  void Function(Duration)? onCurrentTime;
  void Function(Duration)? onDuration;
  void Function(String)? onReceiverName;
  void Function(CastState)? onCastState;

  GCastService(this._gCastRepository, this._sessionsApiService) {
    _gCastRepository.onCastStatus = _onCastStatusCallback;
    _gCastRepository.onCastMessage = _onCastMessageCallback;
  }

  void _onCastStatusCallback(CastSessionState state) {
    if (state == CastSessionState.connected) {
      isConnected = true;
      onConnectionState?.call(true);
      onCastState?.call(CastState.idle);
      return;
    }

    _resetState();
  }

  void _onCastMessageCallback(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'RECEIVER_STATUS':
        final status = message['status'];
        final receiverName = status is Map ? status['receiverName'] as String? ?? '' : '';
        _receiverName = receiverName;
        onReceiverName?.call(receiverName);
        break;
      default:
        break;
    }
  }

  void _resetState() {
    currentAssetId = null;
    isConnected = false;
    _receiverName = '';
    onConnectionState?.call(false);
    onCurrentTime?.call(Duration.zero);
    onDuration?.call(Duration.zero);
    onReceiverName?.call('');
    onCastState?.call(CastState.idle);
  }

  CastState _mapPlaybackState(VideoPlaybackState state) {
    return switch (state) {
      VideoPlaybackState.playing => CastState.playing,
      VideoPlaybackState.paused => CastState.paused,
      VideoPlaybackState.buffering || VideoPlaybackState.initializing => CastState.buffering,
      VideoPlaybackState.completed => CastState.idle,
    };
  }

  bool isSessionValid() {
    if (sessionKey?.expiresAt == null) {
      return false;
    }

    final tokenExpiration = DateTime.parse(sessionKey!.expiresAt!);
    final bufferedExpiration = tokenExpiration.subtract(const Duration(seconds: 10));
    return bufferedExpiration.isAfter(DateTime.now());
  }

  String? _currentRemoteVideoId(BaseAsset? asset) {
    if (asset == null || !asset.isVideo) {
      return null;
    }

    return switch (asset) {
      RemoteAsset remoteAsset => remoteAsset.id,
      LocalAsset localAsset => localAsset.remoteId,
    };
  }

  String? _playbackAssetKey({required bool isVideo, required String? assetId, String? mediaId}) {
    if (!isVideo || assetId == null) {
      return null;
    }

    return '$assetId:${mediaId ?? assetId}';
  }

  Future<void> _setMetadata({
    required String assetId,
    String? mediaId,
    required String title,
    required int durationMs,
  }) async {
    if (!isSessionValid()) {
      sessionKey = await _sessionsApiService.createSession(
        'Cast',
        'Google Cast',
        duration: const Duration(minutes: 15).inSeconds,
      );
    }

    final token = sessionKey!.token;
    final resolvedMediaId = mediaId ?? assetId;
    final authenticatedThumbUrl = '${getThumbnailUrlForRemoteId(assetId)}&sessionKey=$token';
    final authenticatedVideoUrl = '${getPlaybackUrlForRemoteId(resolvedMediaId)}sessionKey=$token';

    await _gCastRepository.setMetadata(authenticatedVideoUrl, authenticatedThumbUrl, title, durationMs);
  }

  void setCurrentPlaybackAsset(BaseAsset? asset) {
    _currentPlaybackAsset = asset;
    _currentPlaybackAssetKey = _playbackAssetKey(
      isVideo: asset?.isVideo ?? false,
      assetId: asset?.remoteId,
      mediaId: asset?.livePhotoVideoId,
    );
  }

  /// Clears the session prepared for the last playback asset, but only if this
  /// service still points at that same asset.
  ///
  /// Gallery/video pages can overlap during swipes and disposal. An outgoing
  /// page may try to clean up the session it previously prepared after a newer
  /// page has already become current. The key comparison prevents that older
  /// page from clearing the newer page's cast session.
  Future<void> clearPreparedPlaybackSessionIfCurrent() async {
    final preparedKey = _preparedPlaybackAssetKey;
    if (preparedKey == null) {
      return;
    }

    _preparedPlaybackAssetKey = null;
    if (_currentPlaybackAssetKey == null || _currentPlaybackAssetKey == preparedKey) {
      await _gCastRepository.clearSession();
    }
  }

  Future<void> preparePlaybackMetadata(BaseAsset asset, {required bool isCurrent}) async {
    if (!isCurrent) {
      return;
    }

    final assetKey = _playbackAssetKey(
      isVideo: asset.isVideo,
      assetId: asset.remoteId,
      mediaId: asset.livePhotoVideoId,
    );
    if (assetKey == null || asset.remoteId == null) {
      await clearPreparedPlaybackSessionIfCurrent();
      return;
    }

    if (_preparedPlaybackAssetKey == assetKey && isSessionValid()) {
      return;
    }

    await _setMetadata(
      assetId: asset.remoteId!,
      mediaId: asset.livePhotoVideoId,
      title: asset.name,
      durationMs: asset.duration.inMilliseconds,
    );
    _preparedPlaybackAssetKey = assetKey;
  }

  Future<(String, Duration)?> _prepareAsset(BaseAsset? asset, {required bool reload}) async {
    final assetId = _currentRemoteVideoId(asset);
    if (assetId == null || asset == null) {
      return null;
    }

    if (!reload && currentAssetId == assetId) {
      return (assetId, asset.duration);
    }

    await _setMetadata(
      assetId: assetId,
      title: asset.name,
      durationMs: asset.duration.inMilliseconds,
    );

    return (assetId, asset.duration);
  }

  Future<List<(String, CastDestinationType, dynamic)>> getDevices() async {
    final devices = <(String, CastDestinationType, dynamic)>[];

    if (isConnected && _receiverName.isNotEmpty) {
      devices.add((_receiverName, CastDestinationType.googleCast, null));
      devices.add((_switchDeviceLabel, CastDestinationType.googleCast, _pickerDestination));
      return devices;
    }

    devices.add((_pickerLabel, CastDestinationType.googleCast, _pickerDestination));
    return devices;
  }

  Future<void> connect(dynamic device) async {
    final preparedAsset = await _prepareAsset(_currentPlaybackAsset, reload: true);
    if (preparedAsset == null) {
      return;
    }

    currentAssetId = preparedAsset.$1;
    onDuration?.call(preparedAsset.$2);
    onCurrentTime?.call(Duration.zero);
    await _gCastRepository.connect(preparedAsset.$1);
  }

  CastDestinationType getType() {
    return CastDestinationType.googleCast;
  }

  Future<bool> initialize() async {
    return true;
  }

  Future<void> disconnect() async {
    await _gCastRepository.disconnect();
    _resetState();
  }

  Future<void> loadMedia(RemoteAsset asset, bool reload) async {
    if (!isConnected) {
      return;
    }

    final preparedAsset = await _prepareAsset(asset, reload: reload);
    if (preparedAsset == null) {
      return;
    }

    currentAssetId = preparedAsset.$1;
    onDuration?.call(preparedAsset.$2);
    onCurrentTime?.call(Duration.zero);
    await _gCastRepository.loadMedia(preparedAsset.$1);
  }

  Future<void> syncPlaybackState(VideoPlaybackValue playbackValue) async {
    if (isConnected) {
      onCurrentTime?.call(playbackValue.position);
      onDuration?.call(playbackValue.duration);
      onCastState?.call(_mapPlaybackState(playbackValue.state));
    }

    await _gCastRepository.setCurrentPosition(
      playbackValue.position.inMilliseconds,
      playbackValue.state == VideoPlaybackState.playing,
    );
  }

  void play() {
    if (!isConnected) {
      return;
    }

    Future.sync(() => _gCastRepository.play());
    onCastState?.call(CastState.playing);
  }

  void pause() {
    if (!isConnected) {
      return;
    }

    Future.sync(() => _gCastRepository.pause());
    onCastState?.call(CastState.paused);
  }

  void seekTo(Duration position) {
    if (!isConnected) {
      return;
    }

    Future.sync(() => _gCastRepository.seekTo(position.inMilliseconds));
    onCurrentTime?.call(position);
  }

  void stop() {
    _resetState();
    Future.sync(() => _gCastRepository.stopCast());
  }
}
