import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:immich_mobile/models/map/map_marker.model.dart';
import 'package:immich_mobile/utils/map_utils.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:flutter/foundation.dart';
import 'package:coordtransform_dart/coordtransform_dart.dart';

extension MapMarkers on MapLibreMapController {
  static var _completer = Completer()..complete();

  Future<void> addGeoJSONSourceForMarkers(List<MapMarker> markers) async {
    return addSource(
      MapUtils.defaultSourceId,
      GeojsonSourceProperties(data: MapUtils.generateGeoJsonForMarkers(markers.toList())),
    );
  }

  Future<void> addHeatmapDataOhos(List<MapMarker> markers) async {
    final List<LatLng> totalData = [];

    for (final marker in markers) {
      final coordinateProcessed = CoordinateTransformUtil.wgs84ToGcj02(marker.latLng.longitude, marker.latLng.latitude);
      totalData.add(LatLng(coordinateProcessed[1], coordinateProcessed[0]));
      // 使用 marker 的属性或方法
    }

    if (defaultTargetPlatform == TargetPlatform.ohos) {
      //print("enter addHeatmapData_Ohos");
      await addHeatmapData_Ohos(totalData);
    }
  }

  Future<void> reloadAllLayersForMarkers(List<MapMarker> markers) async {
    // Wait for previous reload to complete
    if (!_completer.isCompleted) {
      return _completer.future;
    }
    _completer = Completer();

    final List<LatLng> totalData = [];

    for (final marker in markers) {
      totalData.add(marker.latLng);
      // 使用 marker 的属性或方法
    }

    if (defaultTargetPlatform == TargetPlatform.ohos) {
      await addHeatmapData_Ohos(totalData);
    }

    // !! Make sure to remove layers before sources else the native
    // maplibre library would crash when removing the source saying that
    // the source is still in use
    /*
    final existingLayers = await getLayerIds();
    if (existingLayers.contains(MapUtils.defaultHeatMapLayerId)) {
      await removeLayer(MapUtils.defaultHeatMapLayerId);
    }

    final existingSources = await getSourceIds();
    if (existingSources.contains(MapUtils.defaultSourceId)) {
      await removeSource(MapUtils.defaultSourceId);
    }

    await addGeoJSONSourceForMarkers(markers);

    if (Platform.isAndroid) {
      await addCircleLayer(
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
      await addHeatmapLayer(
        MapUtils.defaultSourceId,
        MapUtils.defaultHeatMapLayerId,
        MapUtils.defaultHeatMapLayerProperties,
      );
    }
*/

    _completer.complete();
  }

  Future<Symbol?> addMarkerAtLatLng(LatLng centre) async {
    // no marker is displayed if asset-path is incorrect
    try {
      final ByteData bytes = await rootBundle.load("assets/location-pin.png");
      await addImage("mapMarker", bytes.buffer.asUint8List());
      return addSymbol(SymbolOptions(geometry: centre, iconImage: "mapMarker", iconSize: 0.15, iconAnchor: "bottom"));
    } finally {
      // no-op
    }
  }

  Future<LatLngBounds> getBoundsFromPoint(Point<double> point, double distance) async {
    final southWestPx = Point(point.x - distance, point.y + distance);
    final northEastPx = Point(point.x + distance, point.y - distance);

    final southWest = await toLatLng(southWestPx);
    final northEast = await toLatLng(northEastPx);

    return LatLngBounds(southwest: southWest, northeast: northEast);
  }
}
