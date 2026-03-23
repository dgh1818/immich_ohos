import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/colors.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/utils/hooks/timer_hook.dart';
import 'package:immich_mobile/extensions/duration_extensions.dart';
import 'package:immich_mobile/widgets/asset_viewer/animated_play_pause.dart';

class VideoControls extends HookConsumerWidget {
  final String videoPlayerName;

  static const List<Shadow> _controlShadows = [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))];

  const VideoControls({super.key, required this.videoPlayerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = videoPlayerProvider(videoPlayerName);
    final cast = ref.watch(castProvider);
    final isCasting = cast.isCasting;
    final castNotifier = ref.read(castProvider.notifier);
    final playerNotifier = ref.read(provider.notifier);
    final assetViewerNotifier = ref.read(assetViewerProvider.notifier);

    final (position, duration) = isCasting
        ? ref.watch(castProvider.select((c) => (c.currentTime, c.duration)))
        : ref.watch(provider.select((v) => (v.position, v.duration)));

    final videoStatus = ref.watch(provider.select((v) => v.status));
    final isPlaying = isCasting
        ? cast.castState == CastState.playing
        : videoStatus == VideoPlaybackStatus.playing || videoStatus == VideoPlaybackStatus.buffering;
    final isFinished = !isCasting && videoStatus == VideoPlaybackStatus.completed;

    final hideTimer = useTimer(const Duration(seconds: 5), () {
      if (!context.mounted) return;
      if (ref.read(provider).status == VideoPlaybackStatus.playing) {
        assetViewerNotifier.setControls(false);
      }
    });

    ref.listen(provider.select((v) => v.status), (_, __) => hideTimer.reset());

    final isLoaded = duration != Duration.zero;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        spacing: 16,
        children: [
          Row(
            children: [
              IconButton(
                iconSize: 32,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(),
                icon: isFinished
                    ? const Icon(Icons.replay, color: Colors.white, size: 32, shadows: _controlShadows)
                    : AnimatedPlayPause(color: Colors.white, size: 32, playing: isPlaying, shadows: _controlShadows),
                onPressed: () {
                  if (!context.mounted) return;
                  if (isCasting) {
                    castNotifier.toggle();
                  } else {
                    playerNotifier.toggle();
                  }
                },
              ),
              const Spacer(),
              Text(
                "${position.format()} / ${duration.format()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: _controlShadows,
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          Slider(
            value: min(position.inMicroseconds.toDouble(), duration.inMicroseconds.toDouble()),
            min: 0,
            max: max(duration.inMicroseconds.toDouble(), 1),
            thumbColor: Colors.white,
            activeColor: Colors.white,
            inactiveColor: whiteOpacity75,
            padding: EdgeInsets.zero,
            onChangeStart: (_) => playerNotifier.hold(),
            onChangeEnd: (_) => playerNotifier.release(),
            onChanged: isLoaded
                ? (value) {
                    if (!context.mounted) return;
                    final seekTo = Duration(microseconds: value.toInt());
                    if (isCasting) {
                      castNotifier.seekTo(seekTo);
                    } else {
                      playerNotifier.seekTo(seekTo);
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
