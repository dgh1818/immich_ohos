import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/map_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/map/map.state.dart';
import 'package:immich_mobile/presentation/widgets/map/map_utils.dart';
import 'package:immich_mobile/providers/routes.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/async_mutex.dart';
import 'package:immich_mobile/utils/debounce.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/map/map_theme_override.dart';
import 'package:immich_mobile/widgets/map/positioned_asset_marker_icon.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:immich_mobile/providers/infrastructure/map.provider.dart';
import 'package:flutter/foundation.dart';
import 'package:coordtransform_dart/coordtransform_dart.dart';

class CustomSourceProperties implements SourceProperties {
  final Map<String, dynamic> data;
  const CustomSourceProperties({required this.data});

  @override
  Map<String, dynamic> toJson() {
    return {
      "type": "geojson",
      "data": data,
      // "cluster": true,
      // "clusterRadius": 1,
      // "clusterMinPoints": 5,
      // "tolerance": 0.1,
    };
  }
}

class DriftMapSelectedAsset {
  final String assetId;
  final String? thumbhash;
  final LatLng location;

  const DriftMapSelectedAsset({required this.assetId, required this.location, this.thumbhash});
}

class DriftMap extends ConsumerStatefulWidget {
  final LatLng? initialLocation;
  final bool showTimelineSheet;
  final ValueListenable<DriftMapSelectedAsset?>? selectedAssetListenable;
  final DriftMapSelectedAsset? pinnedAsset;
  final ValueChanged<BaseAsset?>? onTimelineAssetChanged;

  const DriftMap({
    super.key,
    this.initialLocation,
    this.showTimelineSheet = true,
    this.selectedAssetListenable,
    this.pinnedAsset,
    this.onTimelineAssetChanged,
  });

  @override
  ConsumerState<DriftMap> createState() => _DriftMapState();
}

class _DriftMapState extends ConsumerState<DriftMap> {

  MapLibreMapController? mapController;
  final _reloadMutex = AsyncMutex();
  final _debouncer = Debouncer(interval: const Duration(milliseconds: 500), maxWaitTime: const Duration(seconds: 2));
  final ValueNotifier<double> bottomSheetOffset = ValueNotifier(0.25);
  final ValueNotifier<_MapSelectedMarker?> _pinnedMarker = ValueNotifier(null);
  final ValueNotifier<_MapSelectedMarker?> _selectedMarker = ValueNotifier(null);
  StreamSubscription? _eventSubscription;

  DriftMapSelectedAsset? _pinnedAsset;
  DriftMapSelectedAsset? _pendingSelectedAsset;
  DriftMapSelectedAsset? _selectedAsset;
  
  final _sheetCameraDebouncer = Debouncer(interval: const Duration(milliseconds: 120));
  static const double _selectedMarkerSize = 100;
  bool _isReanchoring = false;

  @override
  void initState() {
    super.initState();
    _eventSubscription = EventStream.shared.listen<MapMarkerReloadEvent>(_onEvent);
    _pinnedAsset = widget.pinnedAsset;
    widget.selectedAssetListenable?.addListener(_onSelectedAssetChanged);
    bottomSheetOffset.addListener(() => _sheetCameraDebouncer.run(_reanchorActiveAssetForViewport));
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _sheetCameraDebouncer.dispose();
    bottomSheetOffset.dispose();
    _pinnedMarker.dispose();
    _selectedMarker.dispose();
    _eventSubscription?.cancel();
    widget.selectedAssetListenable?.removeListener(_onSelectedAssetChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DriftMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pinnedAsset != widget.pinnedAsset) {
      _pinnedAsset = widget.pinnedAsset;
      if (_pinnedAsset == null) {
        _pinnedMarker.value = null;
      } else {
        unawaited(_updatePinnedMarkerPosition(shouldAnimate: false));
      }
    }
    if (oldWidget.selectedAssetListenable != widget.selectedAssetListenable) {
      oldWidget.selectedAssetListenable?.removeListener(_onSelectedAssetChanged);
      widget.selectedAssetListenable?.addListener(_onSelectedAssetChanged);
    }
    if (oldWidget.showTimelineSheet != widget.showTimelineSheet) {
      unawaited(_reanchorActiveAssetForViewport());
    }
  }

  void onMapCreated(MapLibreMapController controller) {
    mapController = controller;
    controller.addListener(() {
      if (_selectedAsset != null || _pendingSelectedAsset != null) {
        unawaited(_updateSelectedMarkerPosition(shouldAnimate: false, checkBounds: false));
      }
      if (_pinnedAsset != null) {
        unawaited(_updatePinnedMarkerPosition(shouldAnimate: false, checkBounds: false));
      }
    });
  }

  void _onEvent(_) => _debouncer.run(() => setBounds(forceReload: true));

  Future<void> onMapReady() async {
    final controller = mapController;
    if (controller == null) {
      return;
    }

    // await controller.addSource(
    //   MapUtils.defaultSourceId,
    //   const CustomSourceProperties(data: {'type': 'FeatureCollection', 'features': []}),
    // );

    if (Platform.isAndroid) {
      await controller.addCircleLayer(
        MapUtils.defaultSourceId,
        MapUtils.defaultHeatMapLayerId,
        const CircleLayerProperties(
          circleRadius: 10,
          circleColor: "rgba(150,86,34,0.7)",
          circleBlur: 1.0,
          circleOpacity: 0.7,
          circleStrokeWidth: 0.1,
          circleStrokeColor: "rgba(203,46,19,0.5)",
          circleStrokeOpacity: 0.7,
        ),
      );
    }

    if (Platform.isIOS) {
      await controller.addHeatmapLayer(
        MapUtils.defaultSourceId,
        MapUtils.defaultHeatMapLayerId,
        MapUtils.defaultHeatmapLayerProperties,
      );
    }

    _debouncer.run(() => setBounds(forceReload: true));
    controller.addListener(onMapMoved);
    unawaited(_updatePinnedMarkerPosition(shouldAnimate: false));
    unawaited(_updateSelectedMarkerPosition(shouldAnimate: false));
    unawaited(_reanchorActiveAssetForViewport());
  }

  void onMapMoved() {
    if (mapController!.isCameraMoving || !mounted) {
      return;
    }

    if (!_isReanchoring) {
      _debouncer.run(setBounds);
    }
    unawaited(_updatePinnedMarkerPosition(shouldAnimate: false, checkBounds: false));
    unawaited(_updateSelectedMarkerPosition(shouldAnimate: false, checkBounds: false));
  }

  LatLngBounds _toWgs84Bounds(LatLngBounds bounds) {
    if (defaultTargetPlatform != TargetPlatform.ohos) {
      return bounds;
    }

    final sw = bounds.southwest;
    final ne = bounds.northeast;
    final swWgs = CoordinateTransformUtil.gcj02ToWgs84(sw.longitude, sw.latitude);
    final neWgs = CoordinateTransformUtil.gcj02ToWgs84(ne.longitude, ne.latitude);

    return LatLngBounds(southwest: LatLng(swWgs[1], swWgs[0]), northeast: LatLng(neWgs[1], neWgs[0]));
  }

  Future<void> setBounds({bool forceReload = false}) async {
    final controller = mapController;
    if (controller == null || !mounted) {
      return;
    }

    // When the AssetViewer is open, the DriftMap route stays alive in the background.
    // If we continue to update bounds, the map-scoped timeline service gets recreated and the previous one disposed,
    // which can invalidate the TimelineService instance that was passed into AssetViewerRoute (causing "loading forever").
    final currentRoute = ref.read(currentRouteNameProvider);
    if (currentRoute == AssetViewerRoute.name || currentRoute == GalleryViewerRoute.name) {
      return;
    }

    final bounds = _toWgs84Bounds(await controller.getVisibleRegion());
    unawaited(
      _reloadMutex.run(() async {
        if (mounted && (ref.read(mapStateProvider.notifier).setBounds(bounds) || forceReload)) {
          final markers = await ref.read(mapMarkerProvider(bounds).future);

          final mapService = ref.watch(mapServiceProvider);
          final markersData = await mapService.getMarkers(bounds);

          final List<LatLng> totalData = [];

          for (final marker in markersData) {
            final coordinateProcessed = CoordinateTransformUtil.wgs84ToGcj02(
              marker.location.longitude,
              marker.location.latitude,
            );
            totalData.add(LatLng(coordinateProcessed[1], coordinateProcessed[0]));
            // 使用 marker 的属性或方法
          }

          if (defaultTargetPlatform == TargetPlatform.ohos) {
            await mapController?.addHeatmapData_Ohos(totalData);
          }

          await reloadMarkers(markers);
        }
      }),
    );
  }

  Future<void> reloadMarkers(Map<String, dynamic> markers) async {
    final controller = mapController;
    if (controller == null || !mounted) {
      return;
    }

    //await controller.setGeoJsonSource(MapUtils.defaultSourceId, markers);
  }

  void _onSelectedAssetChanged() {
    _pendingSelectedAsset = widget.selectedAssetListenable?.value;
    if (_pendingSelectedAsset == null) {
      _selectedAsset = null;
      _selectedMarker.value = null;
      return;
    }
    unawaited(_updateSelectedMarkerPosition(shouldAnimate: true));
  }

  // OHOS adaptation: the timeline only covers the map instead of resizing it,
  // so we compute the center of the still-visible map area here to keep the marker from being hidden.
  // OHOS 适配：时间线只是遮挡地图，并不会缩小地图控件本身，
  // 所以这里计算当前仍然可见的地图区域中心，避免 marker 被时间线遮住。
  double _visibleMapCenterY() {
    final top = max(_selectedMarkerSize / 2, context.padding.top + 96.0);
    final bottom = (!widget.showTimelineSheet || !context.isMobile) ? context.height : context.height * (1.0 - bottomSheetOffset.value);
    return bottom <= top ? top : (top + bottom) / 2;
  }

  // OHOS adaptation: when the sheet moves, we re-anchor the active asset toward the visible map center
  // so the marker stays readable instead of being occluded by the timeline.
  // OHOS 适配：当底部时间线位置变化时，需要把当前资产重新锚定到可见地图中心附近，
  // 这样 marker 不会被时间线遮挡住。
  Future<void> _reanchorActiveAssetForViewport() async {
    final controller = mapController;
    final asset = _pendingSelectedAsset ?? _selectedAsset ?? _pinnedAsset;
    if (!mounted || controller == null) {
      return;
    }

    late final LatLng processed;
    if (asset != null) {
      processed = _toMapCoordinate(asset.location);
    } else {
      final bounds = await controller.getVisibleRegion();
      processed = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      );
    }

    // Get current screen position of the marker (physical pixels on non-iOS)
    final point = await controller.toScreenLocation(processed);
    final markerLogicalY = point.y.toDouble() / (Platform.isIOS ? 1.0 : context.devicePixelRatio);
    final targetCenterY = _visibleMapCenterY();
    // On OHOS, scrollBy positive y moves content DOWN on screen (camera north).
    // To move the marker UP on screen when it's below the visible center,
    // we need negative scrollBy y (camera moves south = content moves up = marker screen pos moves up).
    // markerLogicalY > targetCenterY means marker is below center → need negative scroll.
    final scrollDy = targetCenterY - markerLogicalY;

    if (scrollDy.abs() < 1) {
      return;
    }

    _isReanchoring = true;
    await controller.animateCamera(
      CameraUpdate.scrollBy(0, scrollDy),
      duration: const Duration(milliseconds: 300),
    );
    // Delay reset to cover trailing onMapMoved callbacks, then refresh timeline bounds
    Future.delayed(const Duration(milliseconds: 500), () {
      _isReanchoring = false;
      if (mounted) {
        _debouncer.run(setBounds);
      }
    });

    // Update marker screen position after camera moved
    final newPoint = await controller.toScreenLocation(processed);
    if (!mounted || asset == null) {
      return;
    }

    if (_selectedAsset != null || _pendingSelectedAsset != null) {
      _selectedMarker.value = _MapSelectedMarker(point: newPoint, asset: asset, shouldAnimate: false);
      _selectedAsset = asset;
      _pendingSelectedAsset = null;
      return;
    }

    _pinnedMarker.value = _MapSelectedMarker(point: newPoint, asset: asset, shouldAnimate: false);
  }

  LatLng _toMapCoordinate(LatLng location) {
    if (defaultTargetPlatform != TargetPlatform.ohos) {
      return location;
    }
    final out = CoordinateTransformUtil.wgs84ToGcj02(location.longitude, location.latitude);
    return LatLng(out[1], out[0]);
  }

  Future<void> _updateSelectedMarkerPosition({bool shouldAnimate = true, bool checkBounds = true}) async {
    final asset = _pendingSelectedAsset ?? _selectedAsset;
    if (!mounted || asset == null) {
      _selectedAsset = null;
      _selectedMarker.value = null;
      return;
    }

    await _updateMarkerPosition(
      asset: asset,
      target: _selectedMarker,
      shouldAnimate: shouldAnimate,
      checkBounds: checkBounds,
    );

    if (!mounted) {
      return;
    }

    _selectedAsset = asset;
    _pendingSelectedAsset = null;
  }

  Future<void> _updatePinnedMarkerPosition({bool shouldAnimate = true, bool checkBounds = true}) async {
    await _updateMarkerPosition(
      asset: _pinnedAsset,
      target: _pinnedMarker,
      shouldAnimate: shouldAnimate,
      checkBounds: checkBounds,
    );
  }

  Future<void> _updateMarkerPosition({
    required DriftMapSelectedAsset? asset,
    required ValueNotifier<_MapSelectedMarker?> target,
    bool shouldAnimate = true,
    bool checkBounds = true,
  }) async {
    if (!mounted || asset == null) {
      target.value = null;
      return;
    }

    final controller = mapController;
    if (controller == null) {
      return;
    }

    final processed = _toMapCoordinate(asset.location);
    if (checkBounds) {
      final bounds = await controller.getVisibleRegion();
      if (!bounds.contains(processed)) {
        target.value = null;
        return;
      }
    }

    final point = await controller.toScreenLocation(processed);
    target.value = _MapSelectedMarker(point: point, asset: asset, shouldAnimate: shouldAnimate);
  }

  Future<void> onZoomToLocation() async {
    final (location, error) = await MapUtils.checkPermAndGetLocation(context: context);
    if (error != null) {
      if (error == LocationPermission.unableToDetermine && context.mounted) {
        ImmichToast.show(
          context: context,
          gravity: ToastGravity.BOTTOM,
          toastType: ToastType.error,
          msg: "map_cannot_get_user_location".t(context: context),
        );
      }
      return;
    }

    final controller = mapController;
    if (controller != null && location != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(location.latitude, location.longitude), MapUtils.mapZoomToAssetLevel),
        duration: const Duration(milliseconds: 800),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buildMarker(ValueListenable<_MapSelectedMarker?> markerListenable) {
      return ValueListenableBuilder<_MapSelectedMarker?>(
        valueListenable: markerListenable,
        builder: (context, marker, _) {
          if (marker == null) {
            return const SizedBox.shrink();
          }
          return PositionedAssetMarkerIcon(
            point: marker.point,
            assetRemoteId: marker.asset.assetId,
            assetThumbhash: marker.asset.thumbhash ?? '',
            size: _selectedMarkerSize,
            durationInMilliseconds: marker.shouldAnimate ? 100 : 0,
          );
        },
      );
    }

    return Stack(
      children: [
        _Map(initialLocation: widget.initialLocation, onMapCreated: onMapCreated, onMapReady: onMapReady),
        buildMarker(_pinnedMarker),
        buildMarker(_selectedMarker),
        if (widget.showTimelineSheet)
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              bottomSheetOffset.value = notification.extent;
              return true;
            },
            child: MapBottomSheet(onScrollAssetChanged: widget.onTimelineAssetChanged),
          ),
        _DynamicMyLocationButton(
          onZoomToLocation: onZoomToLocation,
          bottomSheetOffset: widget.showTimelineSheet ? bottomSheetOffset : null,
        ),
      ],
    );
  }
}

class _Map extends StatelessWidget {
  final LatLng? initialLocation;

  const _Map({this.initialLocation, required this.onMapCreated, required this.onMapReady});

  final MapCreatedCallback onMapCreated;

  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final initialLocation = this.initialLocation;
    LatLng? processedInitialLocation = initialLocation;

    if (defaultTargetPlatform == TargetPlatform.ohos && initialLocation != null) {
      final out = CoordinateTransformUtil.wgs84ToGcj02(initialLocation.longitude, initialLocation.latitude);
      processedInitialLocation = LatLng(out[1], out[0]);
    }

    return MapThemeOverride(
      mapBuilder: (style) => style.widgetWhen(
        onData: (style) => MapLibreMap(
          initialCameraPosition: processedInitialLocation == null
              ? const CameraPosition(target: LatLng(0, 0), zoom: 0)
              : CameraPosition(target: processedInitialLocation, zoom: MapUtils.mapZoomToAssetLevel),
          compassEnabled: false,
          rotateGesturesEnabled: false,
          trackCameraPosition: true,
          styleString: style,
          onMapCreated: onMapCreated,
          onStyleLoadedCallback: onMapReady,
          attributionButtonPosition: AttributionButtonPosition.topRight,
          attributionButtonMargins: const Point(8, kToolbarHeight),
        ),
      ),
    );
  }
}

class _DynamicMyLocationButton extends StatelessWidget {
  const _DynamicMyLocationButton({required this.onZoomToLocation, required this.bottomSheetOffset});

  final VoidCallback onZoomToLocation;
  final ValueListenable<double>? bottomSheetOffset;

  @override
  Widget build(BuildContext context) {
    final bottomSheetOffset = this.bottomSheetOffset;
    final isMobile = context.isMobile;
    final right = isMobile ? 20.0 : 4.0;
    final tabletBottomOffset = isMobile ? 0.0 : 96.0;
    final staticBottom = (isMobile ? 20.0 : 8.0) + context.padding.bottom + tabletBottomOffset;
    if (bottomSheetOffset == null) {
      return Positioned(
        right: right,
        bottom: staticBottom,
        child: ElevatedButton(
          onPressed: onZoomToLocation,
          style: ElevatedButton.styleFrom(shape: const CircleBorder()),
          child: const Icon(Icons.my_location),
        ),
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: bottomSheetOffset,
      builder: (context, offset, child) {
        return Positioned(
          right: right,
          bottom: context.height * (offset - 0.02) + context.padding.bottom + tabletBottomOffset,
          child: AnimatedOpacity(
            opacity: offset < 0.8 ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: ElevatedButton(
              onPressed: onZoomToLocation,
              style: ElevatedButton.styleFrom(shape: const CircleBorder()),
              child: const Icon(Icons.my_location),
            ),
          ),
        );
      },
    );
  }
}

class _MapSelectedMarker {
  final Point<num> point;
  final DriftMapSelectedAsset asset;
  final bool shouldAnimate;

  const _MapSelectedMarker({required this.point, required this.asset, required this.shouldAnimate});
}
