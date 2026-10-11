import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:logging/logging.dart';
import 'package:native_video_player/native_video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'video_player_provider.freezed.dart';

enum VideoPlaybackStatus { paused, playing, buffering, completed }

@freezed
abstract class VideoPlayerState with _$VideoPlayerState {
  const factory VideoPlayerState({
    required Duration position,
    required Duration duration,
    required VideoPlaybackStatus status,
  }) = _VideoPlayerState;
}

const _defaultState = VideoPlayerState(
  position: Duration.zero,
  duration: Duration.zero,
  status: VideoPlaybackStatus.paused,
);

final videoPlayerProvider = StateNotifierProvider.autoDispose.family<VideoPlayerNotifier, VideoPlayerState, String>((
  ref,
  name,
) {
  return VideoPlayerNotifier();
});

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  static final _log = Logger('VideoPlayerNotifier');

  VideoPlayerNotifier() : super(_defaultState);

  NativeVideoPlayerController? _controller;
  Timer? _bufferingTimer;
  Timer? _seekTimer;
  Future<void>? _pendingSeek;
  Future<void>? _holdPause;
  VideoPlaybackStatus? _holdStatus;
  bool _isScrubbing = false;
  bool _scrubChanged = false;
  int _playbackGeneration = 0;

  @override
  void dispose() {
    _playbackGeneration++;
    _bufferingTimer?.cancel();
    _seekTimer?.cancel();
    unawaited(WakelockPlus.disable());
    _controller = null;

    super.dispose();
  }

  void attachController(NativeVideoPlayerController controller) {
    _playbackGeneration++;
    _controller = controller;
  }

  Future<void> load(VideoSource source) async {
    _startBufferingTimer();
    try {
      await _controller?.loadVideoSource(source);
    } catch (e) {
      _log.severe('Error loading video source: $e');
    }
  }

  Future<void> pause() async {
    if (_controller == null) {
      return;
    }

    _bufferingTimer?.cancel();

    try {
      await _controller!.pause();
      await _flushSeek();
    } catch (e) {
      _log.severe('Error pausing video: $e');
    }
  }

  Future<void> play() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final generation = _playbackGeneration;

    try {
      await _flushSeek();
      if (!mounted || generation != _playbackGeneration || !identical(_controller, controller)) {
        return;
      }
      await controller.play();
    } catch (e) {
      _log.severe('Error playing video: $e');
    }

    _startBufferingTimer();
  }

  Future<void> _flushSeek() async {
    if (_isScrubbing) {
      return;
    }
    final timer = _seekTimer;
    if (timer?.isActive ?? false) {
      timer!.cancel();
      _seekTimer = null;
      await _dispatchSeek();
    }

    final pendingSeek = _pendingSeek;
    if (pendingSeek != null) {
      await pendingSeek;
    }
  }

  void seekTo(Duration position) {
    if (_controller == null || state.position == position) {
      return;
    }

    _bufferingTimer?.cancel();
    state = state.copyWith(
      position: position,
      status: state.status == VideoPlaybackStatus.buffering ? VideoPlaybackStatus.playing : state.status,
    );

    if (_isScrubbing) {
      _scrubChanged = true;
      return;
    }

    _seekTimer?.cancel();

    _seekTimer = Timer(const Duration(milliseconds: 150), () {
      _seekTimer = null;
      unawaited(_dispatchSeek());
    });
  }

  /// Updates the progress bar while dragging without seeking the decoder.
  void beginScrubbing() {
    _scrubChanged = _seekTimer != null;
    _seekTimer?.cancel();
    _seekTimer = null;
    _bufferingTimer?.cancel();
    _isScrubbing = true;
  }

  /// Sends only the final slider position to the native player.
  void endScrubbing() {
    _isScrubbing = false;
    if (_scrubChanged) {
      _scrubChanged = false;
      unawaited(_dispatchSeek());
    }
  }

  Future<void> _dispatchSeek() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final pendingSeek = controller.seekTo(state.position.inMilliseconds);
    _pendingSeek = pendingSeek;
    try {
      await pendingSeek;
    } catch (e) {
      _log.severe('Error seeking video: $e');
    } finally {
      if (identical(_pendingSeek, pendingSeek)) {
        _pendingSeek = null;
        if (mounted && state.status == VideoPlaybackStatus.playing) {
          _startBufferingTimer();
        }
      }
    }
  }

  void toggle() {
    _holdStatus = null;

    switch (state.status) {
      case VideoPlaybackStatus.paused:
        unawaited(play());
      case VideoPlaybackStatus.playing || VideoPlaybackStatus.buffering:
        unawaited(pause());
      case VideoPlaybackStatus.completed:
        unawaited(restart());
    }
  }

  /// Pauses playback and preserves the current status for later restoration.
  void hold() {
    if (_holdStatus != null) {
      return;
    }

    _holdStatus = state.status;
    _holdPause = pause();
  }

  /// Restores playback to the status before [hold] was called.
  void release() {
    final status = _holdStatus;
    _holdStatus = null;

    final holdPause = _holdPause;
    unawaited(() async {
      await holdPause;
      if (!identical(_holdPause, holdPause)) {
        return;
      }
      _holdPause = null;
      if (mounted &&
          _holdStatus == null &&
          (status == VideoPlaybackStatus.playing || status == VideoPlaybackStatus.buffering)) {
        await play();
      }
    }());
  }

  void reset() {
    _playbackGeneration++;
    _bufferingTimer?.cancel();
    _seekTimer?.cancel();
    _seekTimer = null;
    _isScrubbing = false;
    _scrubChanged = false;
    _holdPause = null;
    _holdStatus = null;
    unawaited(WakelockPlus.disable());
    state = _defaultState;
  }

  Future<void> restart() async {
    seekTo(Duration.zero);
    await play();
  }

  Future<void> setVolume(double volume) async {
    try {
      await _controller?.setVolume(volume);
    } catch (e) {
      _log.severe('Error setting volume: $e');
    }
  }

  Future<void> setLoop(bool loop) async {
    try {
      await _controller?.setLoop(loop);
    } catch (e) {
      _log.severe('Error setting loop: $e');
    }
  }

  void onNativePlaybackReady() {
    if (!mounted) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    final videoInfo = _controller?.videoInfo;

    if (playbackInfo == null || videoInfo == null) {
      return;
    }

    state = state.copyWith(
      position: Duration(milliseconds: playbackInfo.position),
      duration: Duration(milliseconds: videoInfo.duration),
      status: _mapStatus(playbackInfo.status),
    );
  }

  void onNativePositionChanged() {
    if (!mounted ||
        _isScrubbing ||
        (CurrentPlatform.isOhos &&
            _pendingSeek != null &&
            (state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering)) ||
        (_seekTimer?.isActive ?? false)) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo == null) {
      return;
    }

    final position = Duration(milliseconds: playbackInfo.position);
    if (state.position == position) {
      return;
    }

    if (state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering) {
      _startBufferingTimer();
    }

    state = state.copyWith(
      position: position,
      status: state.status == VideoPlaybackStatus.buffering ? VideoPlaybackStatus.playing : state.status,
    );
  }

  void onNativeStatusChanged() {
    if (!mounted) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo == null) {
      return;
    }

    final newStatus = _mapStatus(playbackInfo.status);
    switch (newStatus) {
      case VideoPlaybackStatus.playing:
        unawaited(WakelockPlus.enable());
        _startBufferingTimer();
      default:
        onNativePlaybackEnded();
    }

    if (state.status != newStatus) {
      state = state.copyWith(status: newStatus);
    }
  }

  void onNativePlaybackEnded() {
    unawaited(WakelockPlus.disable());
    _bufferingTimer?.cancel();
  }

  void _startBufferingTimer() {
    _bufferingTimer?.cancel();
    if (!mounted || _seekTimer != null || _pendingSeek != null || _holdPause != null) {
      return;
    }
    _bufferingTimer = Timer(Duration(seconds: CurrentPlatform.isOhos ? 3 : 1), () {
      if (mounted && state.status == VideoPlaybackStatus.playing) {
        state = state.copyWith(status: VideoPlaybackStatus.buffering);
      }
    });
  }

  static VideoPlaybackStatus _mapStatus(PlaybackStatus status) => switch (status) {
    PlaybackStatus.playing => VideoPlaybackStatus.playing,
    PlaybackStatus.paused => VideoPlaybackStatus.paused,
    PlaybackStatus.stopped => VideoPlaybackStatus.completed,
  };
}
