import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/exif.model.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/utils/debug_print.dart';
import 'package:immich_mobile/widgets/map/map_thumbnail.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

class ExifMap extends StatelessWidget {
  final ExifInfo exifInfo;
  // TODO: Pass in a BaseAsset instead of the ID and thumbhash when removing old timeline
  // This is currently structured this way because of the old timeline implementation
  // reusing this component
  final String? markerId;
  final String? markerAssetThumbhash;
  final MapCreatedCallback? onMapCreated;
  final void Function(String)? onReverseGeocoded;

  const ExifMap({
    super.key,
    required this.exifInfo,
    this.markerAssetThumbhash,
    this.markerId = 'marker',
    this.onMapCreated,
    this.onReverseGeocoded,
  });

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = exifInfo.hasCoordinates;
    Future<Uri?> createCoordinatesUri() async {
      if (!hasCoordinates) {
        return null;
      }

      final double latitude = exifInfo.latitude!;
      final double longitude = exifInfo.longitude!;

      const zoomLevel = 16;

      if (Platform.isAndroid) {
        Uri uri = Uri(
          scheme: 'geo',
          host: '$latitude,$longitude',
          queryParameters: {'z': '$zoomLevel', 'q': '$latitude,$longitude'},
        );
        if (await canLaunchUrl(uri)) {
          return uri;
        }
      } else if (Platform.isIOS) {
        var params = {'ll': '$latitude,$longitude', 'q': '$latitude,$longitude', 'z': '$zoomLevel'};
        Uri uri = Uri.https('maps.apple.com', '/', params);
        if (await canLaunchUrl(uri)) {
          return uri;
        }
      }

      return Uri(
        scheme: 'https',
        host: 'openstreetmap.org',
        queryParameters: {'mlat': '$latitude', 'mlon': '$longitude'},
        fragment: 'map=$zoomLevel/$latitude/$longitude',
      );
    }

    Future<void> openExternally() async {
      Uri? uri = await createCoordinatesUri();

      if (uri == null) {
        return;
      }

      dPrint(() => 'Opening Map Uri: $uri');
      unawaited(launchUrl(uri));
    }

    Future<void> openMapPage() async {
      dPrint(() => 'ExifMap: pushing DriftMapRoute (ohos)');
      await context.pushRoute<LatLng?>(
        DriftMapRoute(
          initialLocation: LatLng(exifInfo.latitude ?? 0, exifInfo.longitude ?? 0),
          initialAssetId: markerId,
          initialAssetThumbhash: markerAssetThumbhash,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapThumbnail = MapThumbnail(
          centre: LatLng(exifInfo.latitude ?? 0, exifInfo.longitude ?? 0),
          height: 150,
          width: constraints.maxWidth,
          zoom: 12.0,
          assetMarkerRemoteId: markerId,
          assetThumbhash: markerAssetThumbhash,
          onReverseGeocoded: onReverseGeocoded,
          // OHOS: the native map click never reaches onMapClick when the
          // inline detail sheet's vertical-drag recognizer is above the
          // platform view, so taps are handled by a Flutter-side layer below.
          onTap: defaultTargetPlatform == TargetPlatform.ohos ? null : (tapPosition, latLong) => openExternally(),
          onCreated: onMapCreated,
        );

        if (defaultTargetPlatform != TargetPlatform.ohos) {
          return mapThumbnail;
        }

        return GestureDetector(behavior: HitTestBehavior.opaque, onTap: openMapPage, child: mapThumbnail);
      },
    );
  }
}
