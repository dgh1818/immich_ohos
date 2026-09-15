import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/domain/services/setting.service.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/platform_extensions.dart';
import 'package:immich_mobile/extensions/scroll_extensions.dart';
import 'package:immich_mobile/main.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/action_buttons/download_status_floating_button.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_page.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_preloader.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_stack.provider.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/viewer_bottom_app_bar.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/viewer_top_app_bar.widget.dart';
import 'package:immich_mobile/presentation/widgets/images/image_provider.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/is_motion_video_playing.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/providers/infrastructure/current_album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/setting.provider.dart' as store_settings;
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/utils/viewer_hdr.dart';
import 'package:immich_mobile/utils/system_ui.utils.dart';
import 'package:immich_mobile/widgets/photo_view/photo_view.dart';

@RoutePage()
class AssetViewerPage extends StatelessWidget {
  final int initialIndex;
  final TimelineService timelineService;
  final int? heroOffset;
  final RemoteAlbum? currentAlbum;

  const AssetViewerPage({
    super.key,
    required this.initialIndex,
    required this.timelineService,
    this.heroOffset,
    this.currentAlbum,
  });

  @override
  Widget build(BuildContext context) {
    // This is necessary to ensure that the timeline service is available
    // since the Timeline and AssetViewer are on different routes / Widget subtrees.
    return ProviderScope(
      overrides: [
        timelineServiceProvider.overrideWithValue(timelineService),
        currentRemoteAlbumScopedProvider.overrideWithValue(currentAlbum),
      ],
      child: AssetViewer(initialIndex: initialIndex, heroOffset: heroOffset),
    );
  }
}

class AssetViewer extends ConsumerStatefulWidget {
  final int initialIndex;
  final int? heroOffset;

  const AssetViewer({super.key, required this.initialIndex, this.heroOffset});

  @override
  ConsumerState createState() => _AssetViewerState();

  /// Sets the asset and thumbnail size before opening the viewer.
  static void setAsset(WidgetRef ref, BaseAsset asset, {Size? thumbnailSize}) {
    ref.read(assetViewerProvider.notifier).reset();

    // Hide controls by default for videos
    if (asset.isVideo) {
      ref.read(assetViewerProvider.notifier).setControls(false);
    }

    ref.read(isPlayingMotionVideoProvider.notifier).playing = false;
    ref.read(assetViewerProvider.notifier).setAsset(asset, thumbnailSize: thumbnailSize);
  }
}

class _AssetViewerState extends ConsumerState<AssetViewer> {
  static const _viewerOverlayStyle = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  late final _heroOffset = widget.heroOffset ?? TabsRouterScope.of(context)?.controller.activeIndex ?? 0;
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late final _preloader = AssetPreloader(timelineService: ref.read(timelineServiceProvider), mounted: () => mounted);
  late final IsPlayingMotionVideo _motionVideoNotifier;

  late int _currentPage = widget.initialIndex;
  late int _totalAssets = ref.read(timelineServiceProvider).totalAssets;

  StreamSubscription? _reloadSubscription;
  KeepAliveLink? _stackChildrenKeepAlive;

  ImageStream? _currentImageStream;
  ImageStreamListener? _imageListener;

  final Map<String, int> _assetHdrModeCache = {};
  // True once the engine HDR surface was flipped on for this viewer session.
  bool _engineHdrOn = false;

  int _hdrToken = 0;
  bool _isDisposing = false;
  ModalRoute<dynamic>? _subscribedRoute;
  final _routeAware = _AssetViewerRouteAware();

  bool get _isImageHdrEnabled => AppSetting.get(Setting.imageHdr);
  bool get _isVideoHdrEnabled => AppSetting.get(Setting.videoHdr);
  bool get _canUseRef => mounted && !_isDisposing;

  void _onTapNavigate(int direction) {
    final page = _pageController.page?.toInt();
    if (page == null) {
      return;
    }
    final target = page + direction;
    final maxPage = _totalAssets - 1;
    if (target >= 0 && target <= maxPage) {
      _pageController.jumpToPage(target);
      unawaited(_onAssetChanged(target));
    }
  }

  @override
  void initState() {
    super.initState();
    _motionVideoNotifier = ref.read(isPlayingMotionVideoProvider.notifier);

    final asset = ref.read(assetViewerProvider).currentAsset;
    assert(asset != null, "Current asset should not be null when opening the AssetViewer");
    if (asset != null) {
      _stackChildrenKeepAlive = ref.read(stackChildrenNotifier(asset).notifier).ref.keepAlive();
    }

    _reloadSubscription = EventStream.shared.listen(_onEvent);

    WidgetsBinding.instance.addPostFrameCallback(_onAssetInit);

    final assetViewer = ref.read(assetViewerProvider);
    unawaited(_setSystemUIMode(assetViewer.showingControls, assetViewer.showingDetails));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (_subscribedRoute == route || route is! PageRoute) {
      return;
    }

    if (_subscribedRoute != null) {
      routeObserver.unsubscribe(_routeAware);
    }

    _routeAware.onPop = _onRoutePop;
    _routeAware.onPopNext = _onRoutePopNext;
    routeObserver.subscribe(_routeAware, route);
    _subscribedRoute = route;
  }

  @override
  void dispose() {
    _isDisposing = true;
    if (_subscribedRoute != null) {
      routeObserver.unsubscribe(_routeAware);
      _subscribedRoute = null;
    }
    _pageController.dispose();
    _preloader.dispose();
    unawaited(_reloadSubscription?.cancel());
    _stackChildrenKeepAlive?.close();
    _removeImageListener();
    _motionVideoNotifier.playing = false;
    ViewerHdr.resetModes();
    _engineHdrOn = false;

    unawaited(restoreEdgeToEdge());

    super.dispose();
  }

  // The normal onPageChange callback listens to OnScrollUpdate events, and will
  // round the current page and update whenever that value changes. In practise,
  // this means that the page will change when swiped half way, and may flip
  // whilst dragging.
  //
  // Changing the page at the end of a scroll should be more robust, and allow
  // the page to be dragged more than half way whilst keeping the current video
  // playing, and preventing the video on the next page from becoming ready
  // unnecessarily.
  bool _onScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0) {
      return false;
    }

    final page = _pageController.page?.round();
    if (page != null && page != _currentPage) {
      unawaited(_onAssetChanged(page));
    }
    return false;
  }

  void _onAssetInit(Duration timeStamp) {
    if (!_canUseRef) {
      return;
    }
    final asset = ref.read(assetViewerProvider).currentAsset;
    if (asset != null) {
      _syncHdrForAsset(asset);
    }
    _preloader.preload(
      widget.initialIndex,
      context.sizeData,
      thumbnailSize: ref.read(assetViewerProvider).thumbnailSize,
    );
    _handleCasting();
  }

  Future<void> _onAssetChanged(int index) async {
    if (!_canUseRef) {
      return;
    }
    _stopMotionPlayback(restoreControls: false);
    _currentPage = index;

    final asset = await ref.read(timelineServiceProvider).getAssetAsync(index);
    if (!_canUseRef || asset == null) {
      return;
    }

    // The viewer is closing; don't flip the current asset now. Flipping it swaps
    // the grid tile hero keys mid pop and animates the close on two tiles (#23779).
    if (!mounted || !(ModalRoute.of(context)?.isActive ?? true)) {
      return;
    }

    ref.read(isPlayingMotionVideoProvider.notifier).playing = false;
    ref.read(assetViewerProvider.notifier).setAsset(
      asset,
      thumbnailSize: ref.read(assetViewerProvider).thumbnailSize,
    );
    _syncHdrForAsset(asset);
    _preloader.preload(index, context.sizeData, thumbnailSize: ref.read(assetViewerProvider).thumbnailSize);
    _handleCasting();
    _stackChildrenKeepAlive?.close();
    _stackChildrenKeepAlive = ref.read(stackChildrenNotifier(asset).notifier).ref.keepAlive();
  }

  void _handleCasting() {
    if (!_canUseRef) {
      return;
    }
    if (!ref.read(castProvider).isCasting) {
      return;
    }
    final asset = ref.read(assetViewerProvider).currentAsset;
    if (asset == null) {
      return;
    }

    if (asset is RemoteAsset) {
      context.scaffoldMessenger.hideCurrentSnackBar();
      ref.read(castProvider.notifier).loadMedia(asset, false);
      return;
    }

    context.scaffoldMessenger.clearSnackBars();
    ref.read(castProvider.notifier).stop();
    context.scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          context.t.local_asset_cast_failed,
          style: context.textTheme.bodyLarge?.copyWith(color: context.primaryColor),
        ),
      ),
    );
  }

  void _onEvent(Event event) {
    if (!_canUseRef) {
      return;
    }
    switch (event) {
      case TimelineReloadEvent():
        _onTimelineReloadEvent();
      case ViewerReloadAssetEvent():
        _onViewerReloadEvent();
      case final ViewerStackAssetDeletedEvent event:
        unawaited(_onViewerStackAssetDeletedEvent(event));
      default:
    }
  }

  void _onViewerReloadEvent() {
    if (!_canUseRef) {
      return;
    }
    if (_totalAssets <= 1) {
      return;
    }

    final index = _pageController.page?.round() ?? 0;
    final target = index >= _totalAssets - 1 ? index - 1 : index + 1;
    unawaited(_pageController.animateToPage(target, duration: Durations.medium1, curve: Curves.easeInOut));
    unawaited(_onAssetChanged(target));
  }

  Future<void> _onViewerStackAssetDeletedEvent(ViewerStackAssetDeletedEvent event) async {
    final timelineAsset = ref.read(timelineServiceProvider).getAssetSafe(_currentPage);
    if (timelineAsset == null) {
      _onViewerReloadEvent();
      return;
    }

    final stackProvider = stackChildrenNotifier(timelineAsset);

    ref.invalidate(stackProvider);
    final stack = await ref.read(stackProvider.future);

    if (!mounted) {
      return;
    }

    if (stack.isEmpty) {
      _onViewerReloadEvent();
      return;
    }

    final targetIndex = math.min(event.stackIndex, stack.length - 1);
    ref.read(assetViewerProvider.notifier)
      ..setAsset(stack[targetIndex])
      ..setStackIndex(targetIndex);
  }

  void _onTimelineReloadEvent() {
    if (!_canUseRef) {
      return;
    }
    final timelineService = ref.read(timelineServiceProvider);
    final totalAssets = timelineService.totalAssets;

    if (totalAssets == 0) {
      unawaited(context.maybePop());
      return;
    }

    final currentAsset = ref.read(assetViewerProvider).currentAsset;
    final assetIndex = currentAsset != null ? timelineService.getIndex(currentAsset.heroTag) : null;
    final index = (assetIndex ?? _currentPage).clamp(0, totalAssets - 1);

    if (index != _currentPage) {
      _pageController.jumpToPage(index);
      unawaited(_onAssetChanged(index));
    } else if (currentAsset is RemoteAsset && currentAsset.stackId != null && assetIndex == null) {
      final timelineAsset = timelineService.getAssetSafe(index);
      if (timelineAsset is! RemoteAsset || currentAsset.stackId != timelineAsset.stackId) {
        unawaited(_onAssetChanged(index));
      }
    } else if (currentAsset != null && assetIndex == null) {
      unawaited(_onAssetChanged(index));
    }

    if (_totalAssets != totalAssets) {
      setState(() {
        _totalAssets = totalAssets;
      });
    }
  }

  Future<void> _setSystemUIMode(bool controls, bool details) {
    final immersive = !controls || (CurrentPlatform.isIOS && details);
    return immersive ? SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky) : restoreEdgeToEdge();
  }

  void _onRoutePop() {
    ViewerHdr.resetModes();
    unawaited(restoreEdgeToEdge());
  }

  // A route pushed above the viewer (e.g. the EXIF map page) was popped and
  // this viewer is visible again.  The covering page may have forced the
  // engine to SDR, so re-assert HDR for the current asset.
  void _onRoutePopNext() {
    if (!_canUseRef) {
      return;
    }

    final asset = ref.read(assetViewerProvider).currentAsset;
    if (asset != null) {
      _syncHdrForAsset(asset);
    }
  }

  void _removeImageListener() {
    final stream = _currentImageStream;
    final listener = _imageListener;
    if (stream == null || listener == null) {
      return;
    }

    stream.removeListener(listener);

    _currentImageStream = null;
    _imageListener = null;
  }

  ImageProvider _getHdrImageProvider(BaseAsset asset) {
    final useLocalAsset = asset.hasLocal && (!asset.hasRemote || !AppSetting.get(Setting.preferRemoteImage));
    // TODO(ai-hdr): Phase 2 gates this by Setting.imageAiHdr; forced on for
    // the current device verification.
    return getFullImageProvider(asset, size: useLocalAsset ? const Size(-1, -1) : const Size(1080, 1920), aiHdr: false);
  }

  void _watchImageHdr(BaseAsset asset, ImageProvider provider, {required bool resetToSdrIfNoSyncImage}) {
    _removeImageListener();

    final token = ++_hdrToken;
    final stream = provider.resolve(ImageConfiguration.empty);

    _currentImageStream = stream;

    bool gotSyncImage = false;

    _imageListener = ImageStreamListener((info, synchronousCall) {
      if (!_canUseRef || !mounted || token != _hdrToken) {
        return;
      }
      if (ref.read(isPlayingMotionVideoProvider)) {
        return;
      }

      if (synchronousCall) {
        gotSyncImage = true;
      }

      // Ignore the small placeholder tier: flipping the surface (or even the
      // image mode) on it re-enables HLG while the hero still draws SDR
      // frames — the white flash on entry.  Only preview-sized content
      // decides the HDR mode and the surface flip.
      if (info.image.width < 800) {
        return;
      }

      final hdr = ViewerHdr.imageModeFromColorSpace(info.image.colorSpace);

      _assetHdrModeCache[asset.heroTag] = hdr;

      ViewerHdr.applyImageMode(enabled: _isImageHdrEnabled, hdr: hdr);
      // The engine HDR surface is only flipped when HLG content actually
      // exists; enabling it eagerly at viewer entry rendered SDR frames
      // into the HLG-encoded swapchain (blinding flash on open).
      if (hdr == 1 && !_engineHdrOn) {
        _engineHdrOn = true;
        ViewerHdr.enableEngine(imageEnabled: true, videoEnabled: _isVideoHdrEnabled);
      }
    }, onError: (_, __) {});

    stream.addListener(_imageListener!);

    // 关键点：
    // 如果 addListener 后没有同步拿到任何已解码图像，
    // 才说明当前图还没 ready，这时清 SDR，防止上一张 HLG 污染当前预览图。
    if (resetToSdrIfNoSyncImage && !gotSyncImage) {
      ViewerHdr.applyImageMode(enabled: _isImageHdrEnabled, hdr: 0);
    }
  }

  void _syncHdrForAsset(BaseAsset asset) {
    // OHOS AI HDR decoupling: the generator decodes HLG purely from the
    // request policy (policy 1), so the surface must NOT be enabled here —
    // an early HLG surface renders the SDR hero/transition frames white (the
    // 2D pipeline does not map sRGB into HLG).  The surface flips in the
    // image listener below, exactly when HLG content is ready.
    if (!asset.isImage) {
      ViewerHdr.enableEngine(imageEnabled: false, videoEnabled: _isVideoHdrEnabled);
      _hdrToken++;
      _removeImageListener();

      ViewerHdr.applyImageMode(enabled: _isImageHdrEnabled, hdr: 0);
      ViewerHdr.applyVideoMode(enabled: _isVideoHdrEnabled);
      return;
    }

    if (!_isImageHdrEnabled) {
      _hdrToken++;
      _removeImageListener();

      ViewerHdr.applyImageMode(enabled: false, hdr: 0);
      return;
    }

    final cachedHdr = _assetHdrModeCache[asset.heroTag];

    if (cachedHdr != null) {
      // 如果这张图之前已经解码/判断过，先用上次结果，避免 HDR 图先闪 SDR
      ViewerHdr.applyImageMode(enabled: _isImageHdrEnabled, hdr: cachedHdr);
    }

    _watchImageHdr(asset, _getHdrImageProvider(asset), resetToSdrIfNoSyncImage: cachedHdr == null);
  }

  void _applyMotionVideoHdr() {
    _hdrToken++;
    _removeImageListener();
    ViewerHdr.enableEngine(imageEnabled: _isImageHdrEnabled, videoEnabled: _isVideoHdrEnabled);
    ViewerHdr.applyImageMode(enabled: _isImageHdrEnabled, hdr: 0);
    ViewerHdr.applyVideoMode(enabled: _isVideoHdrEnabled);
  }

  void _stopMotionPlayback({bool restoreControls = true}) {
    if (!_canUseRef) {
      return;
    }
    final asset = ref.read(assetViewerProvider).currentAsset;
    if (asset?.isMotionPhoto != true || !ref.read(isPlayingMotionVideoProvider)) {
      return;
    }

    ref.read(isPlayingMotionVideoProvider.notifier).playing = false;
    unawaited(ref.read(videoPlayerProvider(asset!.heroTag).notifier).pause());
    if (restoreControls && !ref.read(assetViewerProvider).showingDetails) {
      ref.read(assetViewerProvider.notifier).setControls(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showingControls = ref.watch(assetViewerProvider.select((s) => s.showingControls));
    final showingDetails = ref.watch(assetViewerProvider.select((s) => s.showingDetails));
    final isZoomed = ref.watch(assetViewerProvider.select((s) => s.isZoomed));
    final backgroundColor = showingDetails
        ? context.colorScheme.surface
        : Colors.black.withValues(alpha: ref.watch(assetViewerProvider.select((s) => s.backgroundOpacity)));

    // Listen for casting changes and send initial asset to the cast provider
    ref.listen(castProvider.select((value) => value.isCasting), (_, isCasting) {
      if (!_canUseRef) {
        return;
      }
      if (!isCasting) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_canUseRef) {
          return;
        }
        _handleCasting();
      });
    });

    ref.listen(assetViewerProvider.select((value) => (value.showingControls, value.showingDetails)), (_, state) {
      final (controls, details) = state;
      unawaited(_setSystemUIMode(controls, details));
    });

    ref.listen(assetViewerProvider.select((value) => value.currentAsset?.heroTag), (_, __) {
      if (!_canUseRef) {
        return;
      }
      final asset = ref.read(assetViewerProvider).currentAsset;
      if (asset == null || ref.read(isPlayingMotionVideoProvider)) {
        return;
      }
      _syncHdrForAsset(asset);
      _handleCasting();
    });

    ref.listen(isPlayingMotionVideoProvider, (_, isPlaying) {
      if (!_canUseRef) {
        return;
      }
      if (isPlaying) {
        _applyMotionVideoHdr();
        return;
      }

      final asset = ref.read(assetViewerProvider).currentAsset;
      if (asset != null) {
        _syncHdrForAsset(asset);
      }
    });

    ref.listen(
      store_settings.settingsProvider.select(
        (settings) => (settings.get(Setting.imageHdr), settings.get(Setting.videoHdr)),
      ),
      (_, __) {
        if (!_canUseRef) {
          return;
        }
        final asset = ref.read(assetViewerProvider).currentAsset;
        if (asset != null) {
          _syncHdrForAsset(asset);
        }
      },
    );

    return AnnotatedRegion(
      value: _viewerOverlayStyle,
      child: Scaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: const ViewerTopAppBar(),
        extendBody: true,
        extendBodyBehindAppBar: true,
        floatingActionButton: IgnorePointer(
          ignoring: !showingControls,
          child: AnimatedOpacity(
            opacity: showingControls ? 1.0 : 0.0,
            duration: Durations.short2,
            child: const DownloadStatusFloatingButton(),
          ),
        ),
        // 不用 bottomNavigationBar 槽位，改用 Stack 内 Positioned 放置，
        // 避免 Scaffold 为 bottomNavigationBar 预留空间导致 FAB 被顶到上面。
        body: Listener(
          onPointerUp: (_) => _stopMotionPlayback(),
          onPointerCancel: (_) => _stopMotionPlayback(),
          child: Stack(
            children: [
              NotificationListener<ScrollEndNotification>(
                onNotification: _onScrollEnd,
                child: PhotoViewGestureDetectorScope(
                  axis: Axis.horizontal,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: isZoomed
                        ? const NeverScrollableScrollPhysics()
                        : CurrentPlatform.isIOS
                        ? const FastScrollPhysics()
                        : const FastClampingScrollPhysics(),
                    itemCount: _totalAssets,
                    itemBuilder: (context, index) =>
                        AssetPage(index: index, heroOffset: _heroOffset, onTapNavigate: _onTapNavigate),
                  ),
                ),
              ),
              if (!CurrentPlatform.isIOS)
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: Durations.short2,
                    color: Colors.black.withValues(alpha: showingDetails ? 0.6 : 0.0),
                    height: context.padding.top,
                  ),
                ),
              const Positioned(left: 0, right: 0, bottom: 0, child: ViewerBottomAppBar()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetViewerRouteAware extends RouteAware {
  VoidCallback? onPop;
  VoidCallback? onPopNext;

  @override
  void didPop() {
    onPop?.call();
    super.didPop();
  }

  @override
  void didPopNext() {
    onPopNext?.call();
    super.didPopNext();
  }
}
