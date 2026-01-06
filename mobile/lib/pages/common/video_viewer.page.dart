import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/asset_viewer/show_controls.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_controller_provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_controls_provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_value_provider.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_player.dart';
import 'package:immich_mobile/widgets/common/delayed_loading_indicator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:immich_mobile/providers/asset_viewer/is_motion_video_playing.provider.dart';
import 'package:logging/logging.dart';

import 'package:immich_mobile/utils/image_url_builder.dart';

import 'package:immich_mobile/models/sessions/session_create_response.model.dart';
import 'package:immich_mobile/repositories/sessions_api.repository.dart';
import 'package:huawei_cast/huawei_cast.dart';

HuaweiCast? castController;

//import 'package:immich_mobile/providers/cast.provider.dart';

class VideoViewerPage extends HookConsumerWidget {
  final Asset asset;
  final bool isMotionVideo;
  final Widget? placeholder;
  final Duration hideControlsTimer;
  final bool showControls;
  final bool showDownloadingIndicator;
  final bool loopVideo;

  const VideoViewerPage({
    super.key,
    required this.asset,
    this.isMotionVideo = false,
    this.placeholder,
    this.showControls = true,
    this.hideControlsTimer = const Duration(seconds: 5),
    this.showDownloadingIndicator = true,
    this.loopVideo = false,
  });

  @override
  build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(videoPlayerControllerProvider(asset: asset)).value;
    // The last volume of the video used when mute is toggled
    final lastVolume = useState(0.5);
    final pendingSeekTarget = useRef<Duration?>(null); //待跳转的进度位置
    final pendingSeekAt = useRef<DateTime?>(null); //点击进度条的时间

    SessionCreateResponse? sessionKey;
    final _sessionsApiService = ref.watch(sessionsAPIRepositoryProvider);

    //final isCasting = ref.watch(castProvider.select((c) => c.isCasting));

    // When the volume changes, set the volume
    // ref.listen(videoPlayerControlsProvider.select((value) => value.mute),
    //     (_, mute) {
    //   if (mute) {
    //     controller?.setVolume(0.0);
    //   } else {
    //     controller?.setVolume(lastVolume.value);
    //   }
    // });

    ref.listen(isPlayingMotionVideoProvider.notifier, (previous, current) async {
      if (controller == null || !asset.isMotionPhoto || !context.mounted) {
        return;
      }

      if (current.playing) {
        // 每次开始播放时都重置到开头
        await controller.seekTo(Duration.zero);
        await controller.play();
      } else {
        await controller.pause();
      }
    });

    // When the position changes, seek to the position
    ref.listen(videoPlayerControlsProvider.select((value) => value.position), (_, position) {
      if (controller == null) {
        // No seeking if there is no video
        return;
      }

      // Find the position to seek to
      final Duration seek = controller.value.duration * (position / 100.0);
      pendingSeekTarget.value = seek;
      pendingSeekAt.value = DateTime.now();
      ref.read(videoPlaybackValueProvider.notifier).position = seek;
      controller.seekTo(seek);
    });

    // When the custom video controls paus or plays
    ref.listen(videoPlayerControlsProvider.select((value) => value.pause), (lastPause, pause) {
      if (pause) {
        controller?.pause();
      } else {
        controller?.play();
      }
    });

    // Updates the [videoPlaybackValueProvider] with the current
    // position and duration of the video from the Chewie [controller]
    // Also sets the error if there is an error in the playback
    bool shouldHoldPosition(VideoPlaybackValue playback) {
      final target = pendingSeekTarget.value;
      final seekAt = pendingSeekAt.value;
      if (target == null || seekAt == null) {
        return false;
      }

      if (DateTime.now().difference(seekAt) > const Duration(seconds: 2)) {
        pendingSeekTarget.value = null;
        pendingSeekAt.value = null;
        return false;
      } //seekto两秒以后开始正常更新进度

      return true;
    }

    void updateVideoPlayback() {
      final videoPlayback = VideoPlaybackValue.fromController(controller);
      final holdPosition = shouldHoldPosition(videoPlayback);
      final updatedPlayback = holdPosition
          ? videoPlayback.copyWith(position: ref.read(videoPlaybackValueProvider).position)
          : videoPlayback;
      ref.read(videoPlaybackValueProvider.notifier).value = updatedPlayback;

      // 检测视频是否自然结束
      final isAtEnd = videoPlayback.position >= videoPlayback.duration;
      final isPaused = videoPlayback.state == VideoPlaybackState.paused;

      if (isAtEnd && isPaused) {
        // 动态视频自然结束时自动暂停
        if (asset.isMotionPhoto && !loopVideo) {
          ref.read(isPlayingMotionVideoProvider.notifier).playing = false;
        }
      }

      final state = videoPlayback.state;

      // Enable the WakeLock while the video is playing
      // 更新媒体中心播放状态
      if (castController != null) {
        if (state == VideoPlaybackState.playing) {
          castController!.setCurrentPosition(videoPlayback.position.inMilliseconds, true);
          // Sync with the controls playing
          WakelockPlus.enable();
        } else {
          castController!.setCurrentPosition(videoPlayback.position.inMilliseconds, false);
          // Sync with the controls pause
          WakelockPlus.disable();
        }
      }
    }

    bool isSessionValid() {
      // check if we already have a session token
      // we should always have a expiration date
      if (sessionKey == null || sessionKey?.expiresAt == null) {
        return false;
      }

      final tokenExpiration = DateTime.parse(sessionKey!.expiresAt!);

      // we want to make sure we have at least 10 seconds remaining in the session
      // this is to account for network latency and other delays when sending the request
      final bufferedExpiration = tokenExpiration.subtract(const Duration(seconds: 10));

      return bufferedExpiration.isAfter(DateTime.now());
    }

    setMetadata(Asset asset) async {
      // if(asset.isMotionPhoto){
      // TO DO

      if (!isSessionValid()) {
        sessionKey = await _sessionsApiService.createSession(
          "Cast",
          "Google Cast",
          duration: const Duration(minutes: 15).inSeconds,
        );
      }

      final unauthenticatedUrlThumb = getThumbnailUrlForRemoteId(asset.remoteId!);
      final authenticatedURLThumb = "$unauthenticatedUrlThumb&sessionKey=${sessionKey?.token}";

      final String unauthenticatedUrlVideo = getPlaybackUrlForRemoteId(asset.remoteId!);
      final authenticatedURLVideo = "$unauthenticatedUrlVideo&sessionKey=${sessionKey?.token}";

      if (controller != null) {
        castController = HuaweiCast(controller!);
        castController!.setMetadata(
          authenticatedURLVideo,
          authenticatedURLThumb,
          asset.name,
          asset.duration.inMilliseconds,
        );
      }
    } //

    // Adds and removes the listener to the video player
    useEffect(() {
      pendingSeekTarget.value = null;
      pendingSeekAt.value = null;
      if (asset.isRemote) {
        setMetadata(asset);
      }

      Future.microtask(() => ref.read(videoPlayerControlsProvider.notifier).reset());
      // Guard no controller
      if (controller == null) {
        return null;
      }

      // Hide the controls
      // Done in a microtask to avoid setting the state while the is building
      if (!isMotionVideo) {
        Future.microtask(() {
          ref.read(showControlsProvider.notifier).show = false;
        });
      }

      // Subscribes to listener
      Future.microtask(() {
        controller.addListener(updateVideoPlayback);
      });
      return () {
        // Removes listener when we dispose
        controller.removeListener(updateVideoPlayback);
        controller.pause();
        if (castController != null) {
          castController!.clearSession();
        }
      };
    }, [controller]);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        ref.read(videoPlaybackValueProvider.notifier).value = VideoPlaybackValue.uninitialized();
        controller?.dispose();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Stack(
          children: [
            Visibility(
              visible: controller == null,
              //visible: controller == null && !isCasting,
              child: Stack(
                children: [
                  if (placeholder != null) placeholder!,
                  const Positioned.fill(
                    child: Center(child: DelayedLoadingIndicator(fadeInDuration: Duration(milliseconds: 500))),
                  ),
                ],
              ),
            ),
            if (controller != null)
              SizedBox(
                height: context.height,
                width: context.width,
                child: VideoPlayerViewer(
                  controller: controller,
                  isMotionVideo: isMotionVideo,
                  placeholder: placeholder,
                  hideControlsTimer: hideControlsTimer,
                  showControls: showControls,
                  showDownloadingIndicator: showDownloadingIndicator,
                  loopVideo: loopVideo,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
