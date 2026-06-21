import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/services/gcast.service.dart';

final castProvider = StateNotifierProvider<CastNotifier, CastManagerState>(
  (ref) => CastNotifier(ref.watch(gCastServiceProvider), ref),
);

class CastNotifier extends StateNotifier<CastManagerState> {
  final GCastService _gCastService;
  final Ref _ref;

  List<(String, CastDestinationType, dynamic)> discovered = List.empty();

  CastNotifier(this._gCastService, this._ref)
    : super(
        const CastManagerState(
          isCasting: false,
          currentTime: Duration.zero,
          duration: Duration.zero,
          receiverName: '',
          castState: CastState.idle,
        ),
      ) {
    _gCastService.onConnectionState = _onConnectionState;
    _gCastService.onCurrentTime = _onCurrentTime;
    _gCastService.onDuration = _onDuration;
    _gCastService.onReceiverName = _onReceiverName;
    _gCastService.onCastState = _onCastState;
  }

  void _onConnectionState(bool isCasting) {
    state = state.copyWith(isCasting: isCasting);
  }

  void _onCurrentTime(Duration currentTime) {
    state = state.copyWith(currentTime: currentTime);
  }

  void _onDuration(Duration duration) {
    state = state.copyWith(duration: duration);
  }

  void _onReceiverName(String receiverName) {
    state = state.copyWith(receiverName: receiverName);
  }

  void _onCastState(CastState castState) {
    state = state.copyWith(castState: castState);
  }

  BaseAsset? _currentCastAsset() {
    return _ref.read(assetViewerProvider).currentAsset;
  }

  VideoPlayerNotifier? _currentVideoPlayer() {
    final heroTag = _ref.read(assetViewerProvider).currentAsset?.heroTag;
    if (heroTag == null) {
      return null;
    }
    return _ref.read(videoPlayerProvider(heroTag).notifier);
  }

  void loadMedia(RemoteAsset asset, bool reload) {
    _gCastService.loadMedia(asset, reload);
  }

  Future<void> connect(CastDestinationType type, dynamic device) async {
    _gCastService.setCurrentPlaybackAsset(_currentCastAsset());

    switch (type) {
      case CastDestinationType.googleCast:
        await _gCastService.connect(device);
        break;
    }
  }

  Future<List<(String, CastDestinationType, dynamic)>> getDevices() async {
    if (discovered.isEmpty) {
      discovered = await _gCastService.getDevices();
    }

    return discovered;
  }

  void setCurrentPlaybackAsset(BaseAsset? asset) {
    _gCastService.setCurrentPlaybackAsset(asset);
  }

  Future<void> preparePlaybackMetadata(BaseAsset asset, {required bool isCurrent}) async {
    await _gCastService.preparePlaybackMetadata(asset, isCurrent: isCurrent);
  }

  Future<void> clearPreparedPlaybackSessionIfCurrent() async {
    await _gCastService.clearPreparedPlaybackSessionIfCurrent();
  }

  Future<void> syncPlaybackState(VideoPlayerState playbackState) async {
    await _gCastService.syncPlaybackState(playbackState);
  }

  void toggle() {
    switch (state.castState) {
      case CastState.playing:
        pause();
      case CastState.paused:
        play();
      default:
    }
  }

  void play() {
    _gCastService.play();
    final player = _currentVideoPlayer();
    if (player != null) {
      unawaited(player.play());
    }
  }

  void pause() {
    _gCastService.pause();
    final player = _currentVideoPlayer();
    if (player != null) {
      unawaited(player.pause());
    }
  }

  void seekTo(Duration position) {
    _gCastService.seekTo(position);
    _currentVideoPlayer()?.seekTo(position);
  }

  void stop() {
    _gCastService.stop();
  }

  Future<void> disconnect() async {
    await _gCastService.disconnect();
  }
}
