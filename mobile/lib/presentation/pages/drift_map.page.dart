import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/map/map.widget.dart';
import 'package:immich_mobile/presentation/widgets/map/map_settings_sheet.dart';
import 'package:immich_mobile/presentation/widgets/map/map.state.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/asset.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/utils/debounce.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

@RoutePage()
class DriftMapPage extends ConsumerStatefulWidget {
  final LatLng? initialLocation;
  final String? initialAssetId;
  final String? initialAssetThumbhash;

  const DriftMapPage({
    super.key,
    this.initialLocation,
    this.initialAssetId,
    this.initialAssetThumbhash,
  });

  @override
  ConsumerState<DriftMapPage> createState() => _DriftMapPageState();
}

class _DriftMapPageState extends ConsumerState<DriftMapPage> {
  final ValueNotifier<DriftMapSelectedAsset?> _selectedAsset = ValueNotifier(null);
  final Debouncer _selectedAssetDebouncer = Debouncer(
    interval: const Duration(milliseconds: 150),
    maxWaitTime: const Duration(milliseconds: 400),
  );

  DriftMapSelectedAsset? _pinnedAsset;
  String? _pendingAssetId;
  String? _pendingThumbhash;

  @override
  void initState() {
    super.initState();
    final initialLocation = widget.initialLocation;
    if (initialLocation != null && widget.initialAssetId != null) {
      _pinnedAsset = DriftMapSelectedAsset(
        assetId: widget.initialAssetId!,
        thumbhash: widget.initialAssetThumbhash,
        location: initialLocation,
      );
    }
  }

  @override
  void dispose() {
    _selectedAsset.dispose();
    _selectedAssetDebouncer.dispose();
    super.dispose();
  }

  void onSettingsPressed(BuildContext context) {
    showModalBottomSheet(
      elevation: 0.0,
      showDragHandle: true,
      isScrollControlled: true,
      context: context,
      builder: (_) => const DriftMapSettingsSheet(),
    );
  }

  void _onTimelineAssetChanged(BaseAsset? asset) {
    if (asset == null || asset is! RemoteAsset) {
      _pendingAssetId = null;
      _pendingThumbhash = null;
      _selectedAsset.value = null;
      return;
    }

    _pendingAssetId = asset.id;
    _pendingThumbhash = asset.thumbHash;

    _selectedAssetDebouncer.run(() async {
      final assetId = _pendingAssetId;
      final thumbhash = _pendingThumbhash;
      if (assetId == null) {
        return;
      }

      final exif = await ref.read(remoteAssetRepositoryProvider).getExif(assetId);
      if (!mounted || _pendingAssetId != assetId) {
        return;
      }

      if (exif == null || !exif.hasCoordinates) {
        _selectedAsset.value = null;
        return;
      }

      _selectedAsset.value = DriftMapSelectedAsset(
        assetId: assetId,
        thumbhash: thumbhash,
        location: LatLng(exif.latitude!, exif.longitude!),
      );
    });
  }

  Widget _buildMapStack(BuildContext context, {required bool showTimelineSheet}) {
    return Stack(
      children: [
        DriftMap(
          initialLocation: widget.initialLocation,
          showTimelineSheet: showTimelineSheet,
          selectedAssetListenable: _selectedAsset,
          pinnedAsset: _pinnedAsset,
          onTimelineAssetChanged: _onTimelineAssetChanged,
        ),
        Positioned(
          left: 20,
          top: 70,
          child: IconButton.filled(
            color: Colors.white,
            onPressed: () => context.router.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: Colors.indigo,
              shadowColor: Colors.black26,
              elevation: 4,
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 70,
          child: IconButton.filled(
            color: Colors.white,
            onPressed: () => onSettingsPressed(context),
            icon: const Icon(Icons.more_vert_rounded),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(8),
              backgroundColor: Colors.indigo,
              shadowColor: Colors.black26,
              elevation: 4,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ui.SetHdr.setHdrMode(hdr: 0, is_image: true);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: context.isMobile
          ? _buildMapStack(context, showTimelineSheet: true)
          : Row(
              children: [
                Expanded(child: _buildMapStack(context, showTimelineSheet: false)),
                Expanded(
                  child: ProviderScope(
                    overrides: [
                      timelineServiceProvider.overrideWith((ref) {
                        final user = ref.watch(currentUserProvider);
                        if (user == null) {
                          throw Exception('User must be logged in to access map');
                        }

                        final users = ref.watch(mapStateProvider).withPartners
                            ? ref.watch(timelineUsersProvider).valueOrNull ?? [user.id]
                            : [user.id];

                        final timelineService =
                            ref.watch(timelineFactoryProvider).map(users, ref.watch(mapStateProvider).toOptions());
                        ref.onDispose(timelineService.dispose);
                        return timelineService;
                      }),
                    ],
                    child: Timeline(
                      appBar: null,
                      bottomSheet: null,
                      withScrubber: false,
                      onScrollAssetChanged: _onTimelineAssetChanged,
                      tilesPerRowOverride: 4,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
