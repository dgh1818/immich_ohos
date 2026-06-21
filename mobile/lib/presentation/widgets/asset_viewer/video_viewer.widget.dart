import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/infrastructure/repositories/storage.repository.dart';
import 'package:immich_mobile/platform/native_sync_api_ohos.g.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_viewer_controls.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/is_motion_video_playing.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/services/api.service.dart';
import 'package:logging/logging.dart';
import 'package:native_video_player/native_video_player.dart';

class NativeVideoViewer extends ConsumerStatefulWidget {
  final BaseAsset asset;
  final String? localFilePath;
  final bool isCurrent;
  final bool showControls;
  final Widget image;

  const NativeVideoViewer({
    super.key,
    required this.asset,
    this.localFilePath,
    required this.image,
    this.isCurrent = false,
    this.showControls = true,
  });

  @override
  ConsumerState<NativeVideoViewer> createState() => _NativeVideoViewerState();
}

class _NativeVideoViewerState extends ConsumerState<NativeVideoViewer> with WidgetsBindingObserver {
  static final _log = Logger('NativeVideoViewer');

  NativeVideoPlayerController? _controller;
  late final Future<VideoSource?> _videoSource;
  Timer? _loadTimer;
  bool _isVideoReady = false;
  bool _shouldPlayOnForeground = true;
  bool _isDisposing = false;
  late final VideoPlayerNotifier _notifier;
  late final CastNotifier _castNotifier;

  bool get _canUseRef => mounted && !_isDisposing;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(videoPlayerProvider(widget.asset.heroTag).notifier);
    _castNotifier = ref.read(castProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _videoSource = _createSource();
    if (widget.isCurrent) {
      _castNotifier.setCurrentPlaybackAsset(widget.asset);
    }
  }

  @override
  void didUpdateWidget(NativeVideoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCurrent == oldWidget.isCurrent || _controller == null) {
      return;
    }

    if (!widget.isCurrent) {
      _loadTimer?.cancel();
      unawaited(_castNotifier.clearPreparedPlaybackSessionIfCurrent());
      _notifier.pause();
      return;
    }

    _castNotifier.setCurrentPlaybackAsset(widget.asset);
    // Prevent unnecessary loading when swiping between assets.
    _loadTimer = Timer(const Duration(milliseconds: 200), _loadVideo);
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _loadTimer?.cancel();
    _removeListeners();
    unawaited(_castNotifier.clearPreparedPlaybackSessionIfCurrent());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_shouldPlayOnForeground && widget.isCurrent) {
          await _castNotifier.preparePlaybackMetadata(widget.asset, isCurrent: true);
          if (!_canUseRef || !widget.isCurrent) {
            return;
          }
          await _notifier.play();
        }
      case AppLifecycleState.paused:
        _shouldPlayOnForeground = await _controller?.isPlaying() ?? true;
        if (!_canUseRef) {
          return;
        }
        if (_shouldPlayOnForeground) {
          await _notifier.pause();
        }
      default:
    }
  }

  void _syncCastPlaybackState() {
    if (!_canUseRef || !widget.isCurrent) {
      return;
    }
    unawaited(_castNotifier.syncPlaybackState(ref.read(videoPlayerProvider(widget.asset.heroTag))));
  }

  Future<VideoSource?> _createSource() async {
    if (!_canUseRef) {
      return null;
    }

    final videoAsset = await ref.read(assetServiceProvider).getAsset(widget.asset) ?? widget.asset;
    if (!_canUseRef) {
      return null;
    }

    try {
      final localFilePath = widget.localFilePath;
      if (localFilePath != null) {
        final file = File(localFilePath);
        if (!await file.exists()) {
          throw Exception('No file found for the video');
        }

        return VideoSource.init(
          path: CurrentPlatform.isAndroid ? file.uri.toString() : file.path,
          type: VideoSourceType.file,
        );
      }

      if (videoAsset.hasLocal && videoAsset.livePhotoVideoId == null) {
        final id = videoAsset is LocalAsset ? videoAsset.id : (videoAsset as RemoteAsset).localId!;
        if (Platform.isOhos) {
          final path = await NativeSyncApiOhos().getPathFromUri(id);
          if (!_canUseRef) {
            return null;
          }
          return VideoSource.init(path: path, type: VideoSourceType.file);
        }

        final file = await StorageRepository().getFileForAsset(id);
        if (!_canUseRef) {
          return null;
        }

        if (file == null) {
          throw Exception('No file found for the video');
        }

        // Pass a file:// URI so Android's Uri.parse doesn't
        // interpret characters like '#' as fragment identifiers.
        return VideoSource.init(
          path: CurrentPlatform.isAndroid ? file.uri.toString() : file.path,
          type: VideoSourceType.file,
        );
      }

      final remoteId = (videoAsset as RemoteAsset).id;

      final serverEndpoint = Store.get(StoreKey.serverEndpoint);
      final isOriginalVideo = ref.read(appConfigProvider).viewer.loadOriginalVideo;
      final String postfixUrl = isOriginalVideo ? 'original' : 'video/playback';
      final String videoUrl = videoAsset.livePhotoVideoId != null
          ? '$serverEndpoint/assets/${videoAsset.livePhotoVideoId}/$postfixUrl'
          : '$serverEndpoint/assets/$remoteId/$postfixUrl';

      return VideoSource.init(
        path: videoUrl,
        type: VideoSourceType.network,
        headers: ApiService.getAuthenticatedRequestHeaders(videoUrl),
      );
    } catch (error) {
      _log.severe('Error creating video source for asset ${videoAsset.name}: $error');
      return null;
    }
  }

  void _onPlaybackReady() async {
    if (!_canUseRef || !widget.isCurrent) {
      return;
    }

    _notifier.onNativePlaybackReady();
    _syncCastPlaybackState();

    // onPlaybackReady may be called multiple times, usually when more data
    // loads. If this is not the first time that the player has become ready, we
    // should not autoplay.
    if (_isVideoReady) {
      return;
    }

    setState(() => _isVideoReady = true);

    if (ref.read(assetViewerProvider).showingDetails) {
      return;
    }

    final autoPlayVideo = ref.read(appConfigProvider).viewer.autoPlayVideo;
    if (autoPlayVideo || widget.asset.isMotionPhoto) {
      await _castNotifier.preparePlaybackMetadata(widget.asset, isCurrent: true);
      if (!_canUseRef || !widget.isCurrent) {
        return;
      }
      await _notifier.play();
    }
  }

  void _onPlaybackEnded() {
    if (!_canUseRef) {
      return;
    }

    _notifier.onNativePlaybackEnded();

    final loopVideo = ref.read(appConfigProvider).viewer.loopVideo;
    if (_controller?.playbackInfo?.status == PlaybackStatus.stopped && (widget.asset.isMotionPhoto || !loopVideo)) {
      ref.read(isPlayingMotionVideoProvider.notifier).playing = false;
    }
  }

  void _onPlaybackPositionChanged() {
    if (!_canUseRef) {
      return;
    }
    _notifier.onNativePositionChanged();
    _syncCastPlaybackState();
  }

  void _onPlaybackStatusChanged() {
    if (!_canUseRef) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo?.status == PlaybackStatus.playing) {
      unawaited(_castNotifier.preparePlaybackMetadata(widget.asset, isCurrent: widget.isCurrent));
    }

    _notifier.onNativeStatusChanged();
    _syncCastPlaybackState();
  }

  void _removeListeners() {
    _controller?.onPlaybackPositionChanged.removeListener(_onPlaybackPositionChanged);
    _controller?.onPlaybackStatusChanged.removeListener(_onPlaybackStatusChanged);
    _controller?.onPlaybackReady.removeListener(_onPlaybackReady);
    _controller?.onPlaybackEnded.removeListener(_onPlaybackEnded);
  }

  void _loadVideo() async {
    final nc = _controller;
    if (nc == null || nc.videoSource != null || !_canUseRef) {
      return;
    }

    final source = await _videoSource;
    if (source == null || !_canUseRef) {
      return;
    }

    await _notifier.load(source);
    if (!_canUseRef) {
      return;
    }
    final loopVideo = ref.read(appConfigProvider).viewer.loopVideo;
    await _notifier.setLoop(!widget.asset.isMotionPhoto && loopVideo);
    await _notifier.setVolume(1);
  }

  void _initController(NativeVideoPlayerController nc) {
    if (_controller != null || !_canUseRef) {
      return;
    }

    _notifier.attachController(nc);

    nc.onPlaybackPositionChanged.addListener(_onPlaybackPositionChanged);
    nc.onPlaybackStatusChanged.addListener(_onPlaybackStatusChanged);
    nc.onPlaybackReady.addListener(_onPlaybackReady);
    nc.onPlaybackEnded.addListener(_onPlaybackEnded);

    _controller = nc;

    if (widget.isCurrent) {
      _castNotifier.setCurrentPlaybackAsset(widget.asset);
      _loadVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCasting = ref.watch(castProvider.select((c) => c.isCasting));
    final status = ref.watch(videoPlayerProvider(widget.asset.heroTag).select((v) => v.status));
    final videoInfo = _controller?.videoInfo;
    final width = widget.asset.width;
    final height = widget.asset.height;
    final aspectRatio = videoInfo != null && videoInfo.width > 0 && videoInfo.height > 0
        ? videoInfo.width / videoInfo.height
        : width != null && height != null && width > 0 && height > 0
        ? width / height
        : 1.0;

    return Stack(
      children: [
        IgnorePointer(
          child: Stack(
            children: [
              Center(child: widget.image),
              if (!isCasting) ...[
                Visibility.maintain(
                  visible: _isVideoReady,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: NativeVideoPlayerView(onViewReady: _initController),
                    ),
                  ),
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: status == VideoPlaybackStatus.buffering ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.showControls) const Center(child: VideoViewerControls()),
      ],
    );
  }
}
