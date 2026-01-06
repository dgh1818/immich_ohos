import 'package:hooks_riverpod/hooks_riverpod.dart';
//import 'package:native_video_player/native_video_player.dart';

import 'package:immich_mobile/providers/asset_viewer/video_player_controller_provider.dart';
import 'package:video_player/video_player.dart';

enum VideoPlaybackState { initializing, paused, playing, buffering, completed }

class VideoPlaybackValue {
  /// The current position of the video
  final Duration position;

  /// The total duration of the video
  final Duration duration;

  /// The current state of the video playback
  final VideoPlaybackState state;

  /// The volume of the video
  final double volume;

  const VideoPlaybackValue({required this.position, required this.duration, required this.state, required this.volume});

  factory VideoPlaybackValue.fromController(VideoPlayerController? controller) {
    final video = controller?.value;
    late VideoPlaybackState status;
    if (video == null) {
      status = VideoPlaybackState.initializing;
      // } else if (video.isCompleted) {
      //   s = VideoPlaybackState.completed;
    } else if (video.isPlaying) {
      status = VideoPlaybackState.playing;
    } else if (video.isBuffering) {
      status = VideoPlaybackState.buffering;
    } else {
      status = VideoPlaybackState.paused;
    }

    return VideoPlaybackValue(
      position: video?.position ?? Duration.zero,
      duration: video?.duration ?? Duration.zero,
      state: status,
      volume: video?.volume ?? 0.0,
    );
  }

  factory VideoPlaybackValue.uninitialized() {
    return VideoPlaybackValue(
      position: Duration.zero,
      duration: Duration.zero,
      state: VideoPlaybackState.initializing,
      volume: 0.0,
    );
  }

  VideoPlaybackValue copyWith({Duration? position, Duration? duration, VideoPlaybackState? state, double? volume}) {
    return VideoPlaybackValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      state: state ?? this.state,
      volume: volume ?? this.volume,
    );
  }
}

const VideoPlaybackValue videoPlaybackValueDefault = VideoPlaybackValue(
  position: Duration.zero,
  duration: Duration.zero,
  state: VideoPlaybackState.initializing,
  volume: 0.0,
);

final videoPlaybackValueProvider = StateNotifierProvider<VideoPlaybackValueState, VideoPlaybackValue>((ref) {
  return VideoPlaybackValueState(ref);
});

class VideoPlaybackValueState extends StateNotifier<VideoPlaybackValue> {
  VideoPlaybackValueState(this.ref) : super(videoPlaybackValueDefault);

  final Ref ref;

  VideoPlaybackValue get value => state;

  set value(VideoPlaybackValue value) {
    state = value;
  }

  set position(Duration value) {
    if (state.position == value) return;
    state = VideoPlaybackValue(position: value, duration: state.duration, state: state.state, volume: state.volume);
  }

  set status(VideoPlaybackState value) {
    if (state.state == value) return;
    state = VideoPlaybackValue(position: state.position, duration: state.duration, state: value, volume: state.volume);
  }

  void reset() {
    state = videoPlaybackValueDefault;
  }
}

/*
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:native_video_player/native_video_player.dart';

enum VideoPlaybackState { initializing, paused, playing, buffering, completed }

class VideoPlaybackValue {
  /// The current position of the video
  final Duration position;

  /// The total duration of the video
  final Duration duration;

  /// The current state of the video playback
  final VideoPlaybackState state;

  /// The volume of the video
  final double volume;

  const VideoPlaybackValue({required this.position, required this.duration, required this.state, required this.volume});

  factory VideoPlaybackValue.fromNativeController(NativeVideoPlayerController controller) {
    final playbackInfo = controller.playbackInfo;
    final videoInfo = controller.videoInfo;

    if (playbackInfo == null || videoInfo == null) {
      return videoPlaybackValueDefault;
    }

    final VideoPlaybackState status = switch (playbackInfo.status) {
      PlaybackStatus.playing => VideoPlaybackState.playing,
      PlaybackStatus.paused => VideoPlaybackState.paused,
      PlaybackStatus.stopped => VideoPlaybackState.completed,
    };

    return VideoPlaybackValue(
      position: Duration(milliseconds: playbackInfo.position),
      duration: Duration(milliseconds: videoInfo.duration),
      state: status,
      volume: playbackInfo.volume,
    );
  }

  VideoPlaybackValue copyWith({Duration? position, Duration? duration, VideoPlaybackState? state, double? volume}) {
    return VideoPlaybackValue(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      state: state ?? this.state,
      volume: volume ?? this.volume,
    );
  }
}

const VideoPlaybackValue videoPlaybackValueDefault = VideoPlaybackValue(
  position: Duration.zero,
  duration: Duration.zero,
  state: VideoPlaybackState.initializing,
  volume: 0.0,
);

final videoPlaybackValueProvider = StateNotifierProvider<VideoPlaybackValueState, VideoPlaybackValue>((ref) {
  return VideoPlaybackValueState(ref);
});

class VideoPlaybackValueState extends StateNotifier<VideoPlaybackValue> {
  VideoPlaybackValueState(this.ref) : super(videoPlaybackValueDefault);

  final Ref ref;

  VideoPlaybackValue get value => state;

  set value(VideoPlaybackValue value) {
    state = value;
  }

  set position(Duration value) {
    if (state.position == value) return;
    state = VideoPlaybackValue(position: value, duration: state.duration, state: state.state, volume: state.volume);
  }

  set status(VideoPlaybackState value) {
    if (state.state == value) return;
    state = VideoPlaybackValue(position: state.position, duration: state.duration, state: value, volume: state.volume);
  }

  void reset() {
    state = videoPlaybackValueDefault;
  }
}
*/
