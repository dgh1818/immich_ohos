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
        final Uri uri = Uri(
          scheme: 'geo',
          host: '$latitude,$longitude',
          queryParameters: {'z': '$zoomLevel', 'q': '$latitude,$longitude'},
        );
        if (await canLaunchUrl(uri)) {
          return uri;
        }
      } else if (Platform.isIOS) {
        final params = {'ll': '$latitude,$longitude', 'q': '$latitude,$longitude', 'z': '$zoomLevel'};
        final Uri uri = Uri.https('maps.apple.com', '/', params);
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

    Future<void> openMapPage() {
      dPrint(() => 'ExifMap: pushing MapRoute (ohos)');
      return context.pushRoute<LatLng?>(
        MapRoute(
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
          // OHOS keeps the native onMapClick path alive: the platform view
          // consumes touches natively (zoom buttons prove it), so the channel
          // callback is the primary navigation trigger.
          onTap: defaultTargetPlatform == TargetPlatform.ohos
              ? (tapPosition, latLong) => openMapPage()
              : (tapPosition, latLong) => openExternally(),
          onCreated: onMapCreated,
        );

        if (defaultTargetPlatform != TargetPlatform.ohos) {
          return mapThumbnail;
        }

        // Fallback for hosts where the platform view never delivers
        // onMapClick; DuplicateGuard on the route absorbs double-fire.
        return GestureDetector(behavior: HitTestBehavior.opaque, onTap: openMapPage, child: mapThumbnail);
      },
    );
  }
}
