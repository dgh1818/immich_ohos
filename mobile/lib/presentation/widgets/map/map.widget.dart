import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:flutter/services.dart';
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

class DriftMap extends ConsumerStatefulWidget {
  final LatLng? initialLocation;

  const DriftMap({super.key, this.initialLocation});

  @override
  ConsumerState<DriftMap> createState() => _DriftMapState();
}

class _DriftMapState extends ConsumerState<DriftMap> {
  MapLibreMapController? mapController;
  final _reloadMutex = AsyncMutex();
  final _debouncer = Debouncer(interval: const Duration(milliseconds: 500), maxWaitTime: const Duration(seconds: 2));
  final ValueNotifier<double> bottomSheetOffset = ValueNotifier(0.25);

  @override
  void dispose() {
    _debouncer.dispose();
    bottomSheetOffset.dispose();
    super.dispose();
  }

  void onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

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

    if (defaultTargetPlatform == TargetPlatform.ohos && widget.initialLocation != null) {
      final out = CoordinateTransformUtil.wgs84ToGcj02(
        widget.initialLocation!.longitude,
        widget.initialLocation!.latitude,
      );
      final LatLng centreProcessed = LatLng(out[1], out[0]);
      final ByteData mapMarkData = await rootBundle.load("assets/location-pin.png");
      await controller.addMarkerAtLatLng_Ohos(centreProcessed, mapMarkData, 0.15);
    }

    _debouncer.run(setBounds);
    controller.addListener(onMapMoved);
  }

  void onMapMoved() {
    if (mapController!.isCameraMoving || !mounted) {
      return;
    }

    _debouncer.run(setBounds);
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

  Future<void> setBounds() async {
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
        if (mounted && ref.read(mapStateProvider.notifier).setBounds(bounds)) {
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
    return Stack(
      children: [
        _Map(initialLocation: widget.initialLocation, onMapCreated: onMapCreated, onMapReady: onMapReady),
        _DynamicBottomSheet(bottomSheetOffset: bottomSheetOffset),
        _DynamicMyLocationButton(onZoomToLocation: onZoomToLocation, bottomSheetOffset: bottomSheetOffset),
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
          styleString: style,
          onMapCreated: onMapCreated,
          onStyleLoadedCallback: onMapReady,
          attributionButtonPosition: AttributionButtonPosition.topRight,
          attributionButtonMargins: Platform.isIOS ? const Point(40, 12) : const Point(40, 72),
        ),
      ),
    );
  }
}

class _DynamicBottomSheet extends StatefulWidget {
  final ValueNotifier<double> bottomSheetOffset;

  const _DynamicBottomSheet({required this.bottomSheetOffset});

  @override
  State<_DynamicBottomSheet> createState() => _DynamicBottomSheetState();
}

class _DynamicBottomSheetState extends State<_DynamicBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        widget.bottomSheetOffset.value = notification.extent;
        return true;
      },
      child: const MapBottomSheet(),
    );
  }
}

class _DynamicMyLocationButton extends StatelessWidget {
  const _DynamicMyLocationButton({required this.onZoomToLocation, required this.bottomSheetOffset});

  final VoidCallback onZoomToLocation;
  final ValueNotifier<double> bottomSheetOffset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: bottomSheetOffset,
      builder: (context, offset, child) {
        return Positioned(
          right: 16,
          bottom: context.height * (offset - 0.02) + context.padding.bottom,
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
