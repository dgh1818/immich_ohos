import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/entities/asset.entity.dart' as old_asset_entity;
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/services/gcast.service.dart';

final castProvider = StateNotifierProvider<CastNotifier, CastManagerState>(
  (ref) => CastNotifier(ref.watch(gCastServiceProvider), ref),
);

class CastNotifier extends StateNotifier<CastManagerState> {
  final GCastService _gCastService;
  final Ref _ref;

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
    final currentAsset = _ref.read(assetViewerProvider).currentAsset;
    if (currentAsset != null) {
      return currentAsset;
    }

    final legacyAsset = _ref.read(currentAssetProvider);
    if (legacyAsset?.remoteId == null) {
      return null;
    }

    return RemoteAsset(
      id: legacyAsset!.remoteId!,
      name: legacyAsset.name,
      ownerId: legacyAsset.ownerId.toString(),
      checksum: legacyAsset.checksum,
      type: legacyAsset.type == old_asset_entity.AssetType.image
          ? AssetType.image
          : legacyAsset.type == old_asset_entity.AssetType.video
          ? AssetType.video
          : AssetType.other,
      createdAt: legacyAsset.fileCreatedAt,
      updatedAt: legacyAsset.updatedAt,
      durationInSeconds: legacyAsset.durationInSeconds,
      isEdited: false,
    );
  }

  BaseAsset? _legacyPlaybackAsset(old_asset_entity.Asset? asset) {
    if (asset?.remoteId == null) {
      return null;
    }

    return RemoteAsset(
      id: asset!.remoteId!,
      name: asset.name,
      ownerId: asset.ownerId.toString(),
      checksum: asset.checksum,
      type: asset.type == old_asset_entity.AssetType.image
          ? AssetType.image
          : asset.type == old_asset_entity.AssetType.video
          ? AssetType.video
          : AssetType.other,
      createdAt: asset.fileCreatedAt,
      updatedAt: asset.updatedAt,
      durationInSeconds: asset.durationInSeconds,
      livePhotoVideoId: asset.livePhotoVideoId,
      isEdited: false,
    );
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

  // TODO: remove this when we migrate legacy viewers to the new asset viewer.
  void loadMediaOld(old_asset_entity.Asset asset, bool reload) {
    final remoteAsset = RemoteAsset(
      id: asset.remoteId!,
      name: asset.name,
      ownerId: asset.ownerId.toString(),
      checksum: asset.checksum,
      type: asset.type == old_asset_entity.AssetType.image
          ? AssetType.image
          : asset.type == old_asset_entity.AssetType.video
          ? AssetType.video
          : AssetType.other,
      createdAt: asset.fileCreatedAt,
      updatedAt: asset.updatedAt,
      durationInSeconds: asset.durationInSeconds,
      isEdited: false,
    );

    _gCastService.loadMedia(remoteAsset, reload);
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
    return await _gCastService.getDevices();
  }

  void setCurrentPlaybackAsset(BaseAsset? asset) {
    _gCastService.setCurrentPlaybackAsset(asset);
  }

  void setCurrentPlaybackAssetOld(old_asset_entity.Asset? asset) {
    _gCastService.setCurrentPlaybackAsset(_legacyPlaybackAsset(asset));
  }

  Future<void> preparePlaybackMetadata(BaseAsset asset, {required bool isCurrent}) async {
    await _gCastService.preparePlaybackMetadata(asset, isCurrent: isCurrent);
  }

  Future<void> preparePlaybackMetadataOld(old_asset_entity.Asset asset, {required bool isCurrent}) async {
    final playbackAsset = _legacyPlaybackAsset(asset);
    if (playbackAsset == null) {
      if (isCurrent) {
        _gCastService.setCurrentPlaybackAsset(null);
        await _gCastService.clearPreparedPlaybackSessionIfCurrent();
      }
      return;
    }

    await _gCastService.preparePlaybackMetadata(playbackAsset, isCurrent: isCurrent);
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
