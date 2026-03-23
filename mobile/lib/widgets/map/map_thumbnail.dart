import 'dart:math';

import 'package:coordtransform_dart/coordtransform_dart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/maplibrecontroller_extensions.dart';
import 'package:immich_mobile/widgets/asset_viewer/detail_panel/asset_location.dart';
import 'package:immich_mobile/widgets/map/map_theme_override.dart';
import 'package:immich_mobile/widgets/map/positioned_asset_marker_icon.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// A non-interactive thumbnail of a map in the given coordinates with optional markers
///
/// User can provide either a [assetMarkerRemoteId] to display the asset's thumbnail or set
/// [showMarkerPin] to true which would display a marker pin instead. If both are provided,
/// [assetMarkerRemoteId] will take precedence
class MapThumbnail extends HookConsumerWidget {
  final Function(Point<double>, LatLng)? onTap;
  final LatLng centre;
  final String? assetMarkerRemoteId;
  final String? assetThumbhash;
  final bool showMarkerPin;
  final double zoom;
  final double height;
  final double width;
  final ThemeMode? themeMode;
  final bool showAttribution;
  final MapCreatedCallback? onCreated;
  final bool isZoomControlsEnabled;
  final void Function(String)? onReverseGeocoded;

  const MapThumbnail({
    super.key,
    required this.centre,
    this.height = 100,
    this.width = 100,
    this.onTap,
    this.zoom = 8,
    this.assetMarkerRemoteId,
    this.assetThumbhash,
    this.showMarkerPin = false,
    this.themeMode,
    this.showAttribution = true,
    this.onCreated,
    this.isZoomControlsEnabled = true,
    this.onReverseGeocoded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useRef<MapLibreMapController?>(null);
    final styleLoaded = useState(false);
    final position = useValueNotifier<Point<num>?>(null);

    LatLng toMapCoordinate(LatLng location) {
      if (defaultTargetPlatform != TargetPlatform.ohos) {
        return location;
      }

      final outLngLat = CoordinateTransformUtil.wgs84ToGcj02(location.longitude, location.latitude);
      return LatLng(outLngLat[1], outLngLat[0]);
    }

    final centreProcessed = toMapCoordinate(centre);

    Future<void> onLocationChanged() async {
      final reverseLocation = controller.value?.reverseLocation;
      if (reverseLocation == null || reverseLocation.isEmpty) {
        return;
      }

      ref.read(exifLocationTextProvider.notifier).state = reverseLocation;
      onReverseGeocoded?.call(reverseLocation);
    }

    useEffect(() {
      final mapController = controller.value;
      if (mapController == null || defaultTargetPlatform != TargetPlatform.ohos) {
        return null;
      }

      mapController.addListener(onLocationChanged);
      return () => mapController.removeListener(onLocationChanged);
    }, [controller.value]);

    Future<void> onMapCreated(MapLibreMapController mapController) async {
      controller.value = mapController;
      styleLoaded.value = false;

      if (assetMarkerRemoteId != null &&
          (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        // The iOS implementation may return an incorrect screen location
        // immediately after map creation, so keep the delayed read.
        Future.delayed(
          const Duration(milliseconds: 100),
          () async => position.value = await mapController.toScreenLocation(centre),
        );
      }

      onCreated?.call(mapController);
    }

    Future<void> onStyleLoaded() async {
      try {
        if (defaultTargetPlatform == TargetPlatform.ohos) {
          if (assetMarkerRemoteId != null) {
            position.value = await controller.value?.toScreenLocation(centreProcessed);
          }

          await controller.value?.reverseGeo(centreProcessed);
        }

        if (showMarkerPin && controller.value != null) {
          if (defaultTargetPlatform == TargetPlatform.ohos) {
            final mapMarkData = await rootBundle.load("assets/location-pin.png");
            await controller.value?.addMarkerAtLatLng_Ohos(centreProcessed, mapMarkData, 0.15);
          } else {
            await controller.value?.addMarkerAtLatLng(centre);
          }
        }
      } finally {
        // Calling methods on the controller after it is disposed will throw an error
        // We do not have a way to check if the controller is disposed for now
        // https://github.com/maplibre/flutter-maplibre-gl/issues/192
      }

      styleLoaded.value = true;
    }

    return MapThemeOverride(
      themeMode: themeMode,
      mapBuilder: (style) => AnimatedContainer(
        duration: Durations.medium2,
        curve: Curves.easeOut,
        foregroundDecoration: BoxDecoration(
          color: context.colorScheme.inverseSurface.withAlpha(styleLoaded.value ? 0 : 200),
          borderRadius: const BorderRadius.all(Radius.circular(15)),
        ),
        height: height,
        width: width,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(15)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              style.widgetWhen(
                onData: (style) => MapLibreMap(
                  initialCameraPosition: CameraPosition(target: centreProcessed, zoom: zoom),
                  styleString: style,
                  onMapCreated: onMapCreated,
                  onStyleLoadedCallback: onStyleLoaded,
                  onMapClick: onTap,
                  doubleClickZoomEnabled: false,
                  dragEnabled: false,
                  zoomGesturesEnabled: isZoomControlsEnabled,
                  tiltGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  myLocationEnabled: false,
                  attributionButtonMargins: showAttribution ? null : const Point(-100, 0),
                ),
              ),
              ValueListenableBuilder<Point<num>?>(
                valueListenable: position,
                builder: (_, value, __) {
                  if (value == null || assetMarkerRemoteId == null || assetThumbhash == null) {
                    return const SizedBox.shrink();
                  }

                  return PositionedAssetMarkerIcon(
                    size: height / 2,
                    point: value,
                    assetRemoteId: assetMarkerRemoteId!,
                    assetThumbhash: assetThumbhash!,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
