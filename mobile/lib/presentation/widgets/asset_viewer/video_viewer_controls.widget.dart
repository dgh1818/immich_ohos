import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:huawei_cast/huawei_cast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/is_motion_video_playing.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/utils/hooks/timer_hook.dart';
import 'package:immich_mobile/widgets/asset_viewer/center_play_button.dart';
import 'package:immich_mobile/widgets/common/delayed_loading_indicator.dart';

class VideoViewerControls extends HookConsumerWidget {
  final Duration hideTimerDuration;

  const VideoViewerControls({super.key, this.hideTimerDuration = const Duration(seconds: 5)});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetViewerProvider.select((s) => s.currentAsset));
    final heroTag = asset?.heroTag;
    final assetIsVideo = asset?.isVideo ?? false;
    final assetViewerNotifier = ref.read(assetViewerProvider.notifier);
    final castNotifier = ref.read(castProvider.notifier);
    final videoNotifier = heroTag == null ? null : ref.read(videoPlayerProvider(heroTag).notifier);

    bool showControls = ref.watch(assetViewerProvider.select((s) => s.showingControls));
    final showingDetails = ref.watch(assetViewerProvider.select((s) => s.showingDetails));
    if (showingDetails) {
      showControls = false;
    }

    final playback = heroTag == null ? null : ref.watch(videoPlayerProvider(heroTag));
    final state = playback?.status ?? VideoPlaybackStatus.paused;
    final cast = ref.watch(castProvider);

    final isPlayingMotionVideo = ref.watch(isPlayingMotionVideoProvider);
    final huaweiCast = useMemoized(HuaweiCast.new);

    final hideTimer = useTimer(hideTimerDuration, () {
      if (!context.mounted || isPlayingMotionVideo) {
        return;
      }

      final currentAsset = ref.read(assetViewerProvider).currentAsset;
      final currentState = currentAsset == null
          ? VideoPlaybackStatus.paused
          : ref.read(videoPlayerProvider(currentAsset.heroTag)).status;

      if (currentState != VideoPlaybackStatus.paused && currentState != VideoPlaybackStatus.completed && assetIsVideo) {
        ref.read(assetViewerProvider.notifier).setControls(false);
      }
    });
    final showBuffering = state == VideoPlaybackStatus.buffering;

    void showControlsAndStartHideTimer() {
      if (!context.mounted || isPlayingMotionVideo) {
        return;
      }
      hideTimer.reset();
      assetViewerNotifier.setControls(true);
    }

    void toggleControls() {
      if (!context.mounted || isPlayingMotionVideo) {
        return;
      }
      if (showControls) {
        assetViewerNotifier.setControls(false);
        return;
      }
      showControlsAndStartHideTimer();
    }

    if (heroTag != null) {
      ref.listen(videoPlayerProvider(heroTag).select((v) => v.position), (_, __) {
        if (!context.mounted) {
          return;
        }
        if (showControls) {
          hideTimer.reset();
        }
      });
    }

    useEffect(() {
      final subscription = huaweiCast.remoteControlStream.listen((event) {
        if (!context.mounted) {
          return;
        }
        final currentAsset = ref.read(assetViewerProvider).currentAsset;
        if (currentAsset == null) {
          return;
        }

        final notifier = ref.read(videoPlayerProvider(currentAsset.heroTag).notifier);
        switch (event.method) {
          case 'play':
            unawaited(notifier.play());
            break;
          case 'pause':
            unawaited(notifier.pause());
            break;
          case 'seekTo':
            notifier.seekTo(Duration(milliseconds: event.position ?? 0));
            break;
          default:
            break;
        }
      });

      return () {
        unawaited(subscription.cancel());
      };
    }, const []);

    void togglePlay() {
      if (!context.mounted) {
        return;
      }
      showControlsAndStartHideTimer();

      if (cast.isCasting) {
        if (cast.castState == CastState.playing) {
          castNotifier.pause();
        } else if (cast.castState == CastState.paused) {
          castNotifier.play();
        }
        return;
      }

      if (videoNotifier == null) {
        return;
      }

      switch (state) {
        case VideoPlaybackStatus.playing:
        case VideoPlaybackStatus.buffering:
          unawaited(videoNotifier.pause());
        case VideoPlaybackStatus.completed:
          unawaited(videoNotifier.restart());
        case VideoPlaybackStatus.paused:
          unawaited(videoNotifier.play());
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
                onTap: () {
                  if (!context.mounted) {
                    return;
                  }
                  assetViewerNotifier.setControls(false);
                },
                child: CenterPlayButton(
                  backgroundColor: Colors.black54,
                  iconColor: Colors.white,
                  isFinished: state == VideoPlaybackStatus.completed,
                  isPlaying:
                      state == VideoPlaybackStatus.playing || (cast.isCasting && cast.castState == CastState.playing),
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
