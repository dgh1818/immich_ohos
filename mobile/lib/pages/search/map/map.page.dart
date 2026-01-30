import 'dart:async';
import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/entities/asset.entity.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/maplibrecontroller_extensions.dart';
import 'package:immich_mobile/models/map/map_event.model.dart';
import 'package:immich_mobile/models/map/map_marker.model.dart';
import 'package:immich_mobile/providers/asset_viewer/current_asset.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/show_controls.provider.dart';
import 'package:immich_mobile/providers/db.provider.dart';
import 'package:immich_mobile/providers/map/map_marker.provider.dart';
import 'package:immich_mobile/providers/map/map_state.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/debounce.dart';
import 'package:immich_mobile/utils/immich_loading_overlay.dart';
import 'package:immich_mobile/utils/map_utils.dart';
import 'package:immich_mobile/widgets/asset_grid/asset_grid_data_structure.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';
import 'package:immich_mobile/widgets/map/map_app_bar.dart';
import 'package:immich_mobile/widgets/map/map_asset_grid.dart';
import 'package:immich_mobile/widgets/map/map_bottom_sheet.dart';
import 'package:immich_mobile/widgets/map/map_theme_override.dart';
import 'package:immich_mobile/widgets/map/positioned_asset_marker_icon.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:logging/logging.dart';
import 'package:coordtransform_dart/coordtransform_dart.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:immich_mobile/main.dart';
import 'package:flutter/foundation.dart';

@RoutePage()
class MapPage extends HookConsumerWidget {
  const MapPage({super.key, this.initialLocation});
  final LatLng? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapController = useRef<MapLibreMapController?>(null);
    final markers = useRef<List<MapMarker>>([]);
    final markersInBounds = useRef<List<MapMarker>>([]);
    final bottomSheetStreamController = useStreamController<MapEvent>();
    final selectedMarker = useValueNotifier<_AssetMarkerMeta?>(null);
    final assetsDebouncer = useDebouncer();
    final layerDebouncer = useDebouncer(interval: const Duration(seconds: 1));
    final isLoading = useProcessingOverlay();
    final scrollController = useScrollController();
    final markerDebouncer = useDebouncer(interval: const Duration(milliseconds: 800));
    final selectedAssets = useValueNotifier<Set<Asset>>({});
    const mapZoomToAssetLevel = 12.0;

    final routeAware = useMemoized(() => _MyRouteAware());

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final modalRoute = ModalRoute.of(context);
        if (modalRoute is PageRoute) {
          routeObserver.subscribe(routeAware, modalRoute);
        }
      });

      return () {
        routeObserver.unsubscribe(routeAware);
      };
    }, [context]);

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

    // updates the markersInBounds value with the map markers that are visible in the current
    // map camera bounds
    Future<void> updateAssetsInBounds() async {
      // Guard map not created
      if (mapController.value == null) {
        return;
      }

      final bounds = _toWgs84Bounds(await mapController.value!.getVisibleRegion());
      final inBounds = markers.value.where((m) {
        // marker 原始是 WGS84
        final wgs = m.latLng;

        // 转成 GCJ-02 后再判断
        final gcj = CoordinateTransformUtil.wgs84ToGcj02(wgs.longitude, wgs.latitude);
        final p = LatLng(gcj[1], gcj[0]); // [lon, lat] -> LatLng(lat, lon)
        return bounds.contains(p);
      }).toList();
      // Notify bottom sheet to update asset grid only when there are new assets
      if (markersInBounds.value.length != inBounds.length) {
        bottomSheetStreamController.add(MapAssetsInBoundsUpdated(inBounds.map((e) => e.assetRemoteId).toList()));
      }
      markersInBounds.value = inBounds;
    }

    // removes all sources and layers and re-adds them with the updated markers
    Future<void> reloadLayers() async {
      if (mapController.value != null) {
        ByteData mapMarkData = await rootBundle.load("assets/location-pin.png");
        if (initialLocation != null) {
          final outLngLat = CoordinateTransformUtil.wgs84ToGcj02(initialLocation!.longitude, initialLocation!.latitude);
          final LatLng centreProcessed = LatLng(outLngLat[1], outLngLat[0]);

          if (defaultTargetPlatform == TargetPlatform.ohos) {
            await mapController.value?.addMarkerAtLatLng_Ohos(centreProcessed, mapMarkData, 0.15);
            await mapController.value?.addHeatmapDataOhos(markers.value);
          }
        }

        layerDebouncer.run(() => mapController.value!.reloadAllLayersForMarkers(markers.value));
      }
    }

    Future<void> loadMarkers() async {
      try {
        isLoading.value = true;
        markers.value = await ref.read(mapMarkersProvider.future);
        assetsDebouncer.run(updateAssetsInBounds);
        await reloadLayers();
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      final currentAssetLink = ref.read(currentAssetProvider.notifier).ref.keepAlive();

      loadMarkers();
      return currentAssetLink.close;
    }, []);

    // Refetch markers when map state is changed
    ref.listen(mapStateNotifierProvider, (_, current) {
      if (current.shouldRefetchMarkers) {
        markerDebouncer.run(() {
          ref.invalidate(mapMarkersProvider);
          // Reset marker
          selectedMarker.value = null;
          loadMarkers();
          ref.read(mapStateNotifierProvider.notifier).setRefetchMarkers(false);
        });
      }
    });

    // updates the selected markers position based on the current map camera
    Future<void> updateAssetMarkerPosition(MapMarker marker, {bool shouldAnimate = true}) async {
      final outLngLat = CoordinateTransformUtil.wgs84ToGcj02(marker.latLng.longitude, marker.latLng.latitude);
      final LatLng centreProcessed = LatLng(outLngLat[1], outLngLat[0]);
      final assetPoint = await mapController.value!.toScreenLocation(centreProcessed);
      selectedMarker.value = _AssetMarkerMeta(point: assetPoint, marker: marker, shouldAnimate: shouldAnimate);
      (assetPoint, marker, shouldAnimate);
    }

    // finds the nearest asset marker from the tap point and store it as the selectedMarker
    Future<void> onMarkerClicked(Point<double> point, LatLng coords) async {
      // Guard map not created
      if (mapController.value == null) {
        return;
      }
      final latlngBound = await mapController.value!.getBoundsFromPoint(point, 50);
      final marker = markersInBounds.value.firstWhereOrNull(
        (m) => latlngBound.contains(LatLng(m.latLng.latitude, m.latLng.longitude)),
      );

      if (marker != null) {
        await updateAssetMarkerPosition(marker);
      } else {
        // If no asset was previously selected and no new asset is available, close the bottom sheet
        if (selectedMarker.value == null) {
          bottomSheetStreamController.add(const MapCloseBottomSheet());
        }
        selectedMarker.value = null;
      }
    }

    void onMapCreated(MapLibreMapController controller) async {
      mapController.value = controller;
      controller.addListener(() {
        if (controller.isCameraMoving && selectedMarker.value != null) {
          updateAssetMarkerPosition(selectedMarker.value!.marker, shouldAnimate: false);
        }
      });
    }

    Future<void> onMarkerTapped() async {
      final assetId = selectedMarker.value?.marker.assetRemoteId;
      if (assetId == null) {
        return;
      }

      final asset = await ref.read(dbProvider).assets.getByRemoteId(assetId);
      if (asset == null) {
        return;
      }

      // Since we only have a single asset, we can just show GroupAssetBy.none
      final renderList = await RenderList.fromAssets([asset], GroupAssetsBy.none);

      ref.read(currentAssetProvider.notifier).set(asset);
      if (asset.isVideo) {
        ref.read(showControlsProvider.notifier).show = false;
      }
      unawaited(context.pushRoute(GalleryViewerRoute(initialIndex: 0, heroOffset: 0, renderList: renderList)));
    }

    /// BOTTOM SHEET CALLBACKS

    Future<void> onMapMoved() async {
      assetsDebouncer.run(updateAssetsInBounds);
    }

    void onBottomSheetScrolled(String assetRemoteId) {
      final assetMarker = markersInBounds.value.firstWhereOrNull((m) => m.assetRemoteId == assetRemoteId);
      if (assetMarker != null) {
        updateAssetMarkerPosition(assetMarker);
      }
    }

    void onZoomToAsset(String assetRemoteId) {
      final assetMarker = markersInBounds.value.firstWhereOrNull((m) => m.assetRemoteId == assetRemoteId);
      if (mapController.value != null && assetMarker != null) {
        // Offset the latitude a little to show the marker just above the viewports center
        final offset = context.isMobile ? 0.02 : 0;
        final latlng = LatLng(assetMarker.latLng.latitude - offset, assetMarker.latLng.longitude);
        mapController.value!.animateCamera(
          CameraUpdate.newLatLngZoom(latlng, mapZoomToAssetLevel),
          duration: const Duration(milliseconds: 800),
        );
      }
    }

    void onZoomToLocation() async {
      final (location, error) = await MapUtils.checkPermAndGetLocation(context: context);
      if (error != null) {
        if (error == LocationPermission.unableToDetermine && context.mounted) {
          ImmichToast.show(
            context: context,
            gravity: ToastGravity.BOTTOM,
            toastType: ToastType.error,
            msg: "map_cannot_get_user_location".tr(),
          );
        }
        return;
      }

      if (mapController.value != null && location != null) {
        await mapController.value!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(location.latitude, location.longitude), mapZoomToAssetLevel),
          duration: const Duration(milliseconds: 800),
        );
      }
    }

    void onAssetsSelected(bool selected, Set<Asset> selection) {
      selectedAssets.value = selected ? selection : {};
    }

    return MapThemeOverride(
      mapBuilder: (style) => context.isMobile
          // Single-column
          ? Scaffold(
              extendBodyBehindAppBar: true,
              appBar: MapAppBar(selectedAssets: selectedAssets),
              body: Stack(
                children: [
                  _MapWithMarker(
                    initialLocation: initialLocation,
                    style: style,
                    selectedMarker: selectedMarker,
                    onMapCreated: onMapCreated,
                    onMapMoved: onMapMoved,
                    onMapClicked: onMarkerClicked,
                    onStyleLoaded: reloadLayers,
                    onMarkerTapped: onMarkerTapped,
                  ),
                  // Should be a part of the body and not scaffold::bottomsheet for the
                  // location button to be hit testable
                  MapBottomSheet(
                    mapEventStream: bottomSheetStreamController.stream,
                    onGridAssetChanged: onBottomSheetScrolled,
                    onZoomToAsset: onZoomToAsset,
                    onAssetsSelected: onAssetsSelected,
                    onZoomToLocation: onZoomToLocation,
                    selectedAssets: selectedAssets,
                  ),
                ],
              ),
            )
          // Two-pane
          : Row(
              children: [
                Expanded(
                  child: Scaffold(
                    extendBodyBehindAppBar: true,
                    appBar: MapAppBar(selectedAssets: selectedAssets),
                    body: Stack(
                      children: [
                        _MapWithMarker(
                          initialLocation: initialLocation,
                          style: style,
                          selectedMarker: selectedMarker,
                          onMapCreated: onMapCreated,
                          onMapMoved: onMapMoved,
                          onMapClicked: onMarkerClicked,
                          onStyleLoaded: reloadLayers,
                          onMarkerTapped: onMarkerTapped,
                        ),
                        Positioned(
                          right: 3,
                          bottom: 10,
                          child: ElevatedButton(
                            onPressed: onZoomToLocation,
                            style: ElevatedButton.styleFrom(shape: const CircleBorder()),
                            child: const Icon(Icons.my_location),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (ctx, constraints) => MapAssetGrid(
                      controller: scrollController,
                      mapEventStream: bottomSheetStreamController.stream,
                      onGridAssetChanged: onBottomSheetScrolled,
                      onZoomToAsset: onZoomToAsset,
                      onAssetsSelected: onAssetsSelected,
                      selectedAssets: selectedAssets,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AssetMarkerMeta {
  final Point<num> point;
  final MapMarker marker;
  final bool shouldAnimate;

  const _AssetMarkerMeta({required this.point, required this.marker, required this.shouldAnimate});

  @override
  String toString() => '_AssetMarkerMeta(point: $point, marker: $marker, shouldAnimate: $shouldAnimate)';
}

class _MapWithMarker extends StatelessWidget {
  final AsyncValue<String> style;
  final MapCreatedCallback onMapCreated;
  final OnCameraIdleCallback onMapMoved;
  final OnMapClickCallback onMapClicked;
  final OnStyleLoadedCallback onStyleLoaded;
  final Function()? onMarkerTapped;
  final ValueNotifier<_AssetMarkerMeta?> selectedMarker;
  final LatLng? initialLocation;

  const _MapWithMarker({
    required this.style,
    required this.onMapCreated,
    required this.onMapMoved,
    required this.onMapClicked,
    required this.onStyleLoaded,
    required this.selectedMarker,
    this.onMarkerTapped,
    this.initialLocation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SizedBox(
        height: constraints.maxHeight,
        width: constraints.maxWidth,
        child: Stack(
          children: [
            style.widgetWhen(
              onData: (style) => MapLibreMap(
                attributionButtonMargins: const Point(8, kToolbarHeight),
                initialCameraPosition: CameraPosition(
                  target: initialLocation ?? const LatLng(0, 0),
                  zoom: initialLocation != null ? 12 : 0,
                ),
                styleString: style,
                // This is needed to update the selectedMarker's position on map camera updates
                // The changes are notified through the mapController ValueListener which is added in [onMapCreated]
                trackCameraPosition: true,
                onMapCreated: onMapCreated,
                onCameraIdle: onMapMoved,
                onMapClick: onMapClicked,
                onStyleLoadedCallback: onStyleLoaded,
                tiltGesturesEnabled: false,
                dragEnabled: false,
                myLocationEnabled: false,
                attributionButtonPosition: AttributionButtonPosition.topRight,
                rotateGesturesEnabled: false,
                zoomGesturesEnabled: true,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: selectedMarker,
              builder: (ctx, value, _) => value != null
                  ? PositionedAssetMarkerIcon(
                      point: value.point,
                      assetRemoteId: value.marker.assetRemoteId,
                      assetThumbhash: '',
                      durationInMilliseconds: value.shouldAnimate ? 100 : 0,
                      onTap: onMarkerTapped,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRouteAware extends RouteAware {
  //@override
  // void didPopNext() {
  //   super.didPopNext();
  //   ui.SetHdr.setHdrMode(hdr: 0, is_image: true);
  // }
  // void didPush() { }

  // @override
  // void didPop() {
  //   ui.SetHdr.setHdrMode(hdr: 0, is_image: true);
  //   super.didPop();
  // }

  @override
  didPush() {
    ui.SetHdr.setHdrMode(hdr: 0, is_image: true);
    super.didPushNext();
  }

  // void didPushNext() { }
}
