import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:huawei_cast/huawei_cast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.state.dart';
import 'package:immich_mobile/providers/asset_viewer/is_motion_video_playing.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_controls_provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_value_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset_viewer/current_asset.provider.dart';
import 'package:immich_mobile/utils/hooks/timer_hook.dart';
import 'package:immich_mobile/widgets/asset_viewer/center_play_button.dart';
import 'package:immich_mobile/widgets/common/delayed_loading_indicator.dart';

class VideoViewerControls extends HookConsumerWidget {
  final Duration hideTimerDuration;

  const VideoViewerControls({super.key, this.hideTimerDuration = const Duration(seconds: 5)});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetIsVideo = ref.watch(currentAssetNotifier.select((asset) => asset != null && asset.isVideo));
    bool showControls = ref.watch(assetViewerProvider.select((s) => s.showingControls));
    final showBottomSheet = ref.watch(assetViewerProvider.select((s) => s.showingBottomSheet));
    if (showBottomSheet) {
      showControls = false;
    }
    final VideoPlaybackState state = ref.watch(videoPlaybackValueProvider.select((value) => value.state));
    final cast = ref.watch(castProvider);

    final isPlayingMotionVideo = ref.watch(isPlayingMotionVideoProvider);
    final huaweiCast = HuaweiCast();

    final hideTimer = useTimer(hideTimerDuration, () {
      if (!context.mounted || isPlayingMotionVideo) {
        return;
      }
      final state = ref.read(videoPlaybackValueProvider).state;

      if (state != VideoPlaybackState.paused && state != VideoPlaybackState.completed && assetIsVideo) {
        ref.read(assetViewerProvider.notifier).setControls(false);
      }
    });
    final showBuffering = state == VideoPlaybackState.buffering;

    void showControlsAndStartHideTimer() {
      if (isPlayingMotionVideo) {
        return;
      }
      hideTimer.reset();
      ref.read(assetViewerProvider.notifier).setControls(true);
    }

    void toggleControls() {
      if (isPlayingMotionVideo) {
        return;
      }
      if (showControls) {
        ref.read(assetViewerProvider.notifier).setControls(false);
        return;
      }
      showControlsAndStartHideTimer();
    }

    // When we change position, only keep the timer alive if controls are already showing
    ref.listen(videoPlayerControlsProvider.select((v) => v.position), (previous, next) {
      if (showControls) {
        hideTimer.reset();
      }
    });

    useEffect(() {
      // Bridge transport commands coming back from HuaweiCast/system media
      // controls into the same Riverpod controls used by the in-app player UI.
      // This keeps remote play/pause/scrub actions and the local player state aligned.
      final subscription = huaweiCast.remoteControlStream.listen((event) {
        switch (event.method) {
          case 'play':
            ref.read(videoPlayerControlsProvider.notifier).play();
            break;
          case 'pause':
            ref.read(videoPlayerControlsProvider.notifier).pause();
            break;
          case 'seekTo':
            final position = Duration(milliseconds: event.position ?? 0);
            // Update both the requested seek target and the visible playback
            // position so the slider reflects remote scrubbing immediately.
            ref.read(videoPlayerControlsProvider.notifier).position = position;
            ref.read(videoPlaybackValueProvider.notifier).position = position;
            break;
          default:
            break;
        }
      });

      return () {
        unawaited(subscription.cancel());
      };
    }, const []);

    /// Toggles between playing and pausing depending on the state of the video
    void togglePlay() {
      showControlsAndStartHideTimer();

      if (cast.isCasting) {
        if (cast.castState == CastState.playing) {
          ref.read(castProvider.notifier).pause();
        } else if (cast.castState == CastState.paused) {
          ref.read(castProvider.notifier).play();
        } else if (cast.castState == CastState.idle) {
          // resend the play command since its finished
          final asset = ref.read(currentAssetNotifier);
          if (asset == null) {
            return;
          }
        }
        return;
      }

      if (state == VideoPlaybackState.playing) {
        ref.read(videoPlayerControlsProvider.notifier).pause();
      } else if (state == VideoPlaybackState.completed) {
        ref.read(videoPlayerControlsProvider.notifier).restart();
      } else {
        ref.read(videoPlayerControlsProvider.notifier).play();
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: toggleControls,
      child: AbsorbPointer(
        absorbing: !showControls,
        child: Stack(
          children: [
            if (showBuffering)
              const Center(child: DelayedLoadingIndicator(fadeInDuration: Duration(milliseconds: 400)))
            else
              GestureDetector(
                onTap: () => ref.read(assetViewerProvider.notifier).setControls(false),
                child: CenterPlayButton(
                  backgroundColor: Colors.black54,
                  iconColor: Colors.white,
                  isFinished: state == VideoPlaybackState.completed,
                  isPlaying:
                      state == VideoPlaybackState.playing || (cast.isCasting && cast.castState == CastState.playing),
                  show: assetIsVideo && showControls,
                  onPressed: togglePlay,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
