import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline.repository.dart';
import 'package:immich_mobile/utils/image_url_builder.dart';
import 'package:logging/logging.dart';

enum OhosLaunchMode {
  legacyFlutter('legacy_flutter'),
  hybridArkuiPhotos('hybrid_arkui_photos');

  const OhosLaunchMode(this.value);
  final String value;
}

class HybridArkuiBridgeService {
  HybridArkuiBridgeService._(Drift drift) : _timelineRepository = DriftTimelineRepository(drift);

  static const MethodChannel _channel = MethodChannel('immich/hybrid');
  static HybridArkuiBridgeService? _instance;

  final DriftTimelineRepository _timelineRepository;
  final Logger _log = Logger('HybridArkuiBridgeService');

  static Future<void> init(Drift drift) async {
    if (defaultTargetPlatform != TargetPlatform.ohos) {
      return;
    }

    final instance = _instance ??= HybridArkuiBridgeService._(drift);
    _channel.setMethodCallHandler(instance._handleCall);
    await _hydrateLaunchModePreference();
  }

  static Future<void> setLaunchModePreference(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.ohos) {
      return;
    }

    await _channel.invokeMethod<void>('setLaunchModePreference', enabled);
  }

  Future<Object?> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'getLaunchMode':
        return _getLaunchMode().value;
      case 'fetchPhotoPage':
        final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
        final offset = (args['offset'] as num?)?.toInt() ?? 0;
        final requestedLimit = (args['limit'] as num?)?.toInt() ?? 90;
        final limit = requestedLimit.clamp(30, 180).toInt();
        final page = await _buildPhotoPage(offset: offset, limit: limit);
        return jsonEncode(page);
      default:
        throw MissingPluginException('Unsupported hybrid bridge method: ${call.method}');
    }
  }

  OhosLaunchMode _getLaunchMode() {
    final enabled = Store.tryGet(StoreKey.hybridArkuiPhotos) ?? false;
    final accessToken = Store.tryGet<String>(StoreKey.accessToken);
    final serverEndpoint = Store.tryGet<String>(StoreKey.serverEndpoint);
    final hasSession =
        accessToken != null && accessToken.isNotEmpty && serverEndpoint != null && serverEndpoint.isNotEmpty;

    if (!enabled || !hasSession) {
      return OhosLaunchMode.legacyFlutter;
    }

    return OhosLaunchMode.hybridArkuiPhotos;
  }

  Future<Map<String, Object?>> _buildPhotoPage({required int offset, required int limit}) async {
    if (_getLaunchMode() != OhosLaunchMode.hybridArkuiPhotos) {
      return _unavailablePage('Hybrid ArkUI photos mode is disabled');
    }

    final currentUser = Store.tryGet<UserDto>(StoreKey.currentUser);
    final serverEndpoint = Store.tryGet<String>(StoreKey.serverEndpoint);
    if (currentUser == null || serverEndpoint == null || serverEndpoint.isEmpty) {
      return _unavailablePage('Missing authenticated session context');
    }

    final userIds = await _resolveTimelineUserIds(currentUser.id);
    final assets = await _timelineRepository.main(userIds, GroupAssetsBy.day).assetSource(offset, limit);
    final sections = _chunkIntoSections(assets);

    return {
      'ready': true,
      'offset': offset,
      'nextOffset': offset + assets.length,
      'hasMore': assets.length >= limit,
      'sections': sections,
    };
  }

  Future<List<String>> _resolveTimelineUserIds(String userId) async {
    try {
      return await _timelineRepository
          .watchTimelineUserIds(userId)
          .first
          .timeout(const Duration(seconds: 2), onTimeout: () => <String>[userId]);
    } catch (error, stackTrace) {
      _log.warning('Falling back to current user timeline only', error, stackTrace);
      return <String>[userId];
    }
  }

  Map<String, Object?> _unavailablePage(String reason) {
    return {'ready': false, 'hasMore': false, 'nextOffset': 0, 'sections': const <Object?>[], 'reason': reason};
  }

  List<Map<String, Object?>> _chunkIntoSections(List<BaseAsset> assets) {
    final sections = <_PhotoSectionAccumulator>[];

    for (final asset in assets) {
      final localCreatedAt = asset.createdAt.toLocal();
      final sectionKey = _formatSectionDate(localCreatedAt);
      final sectionTitle = _formatSectionTitle(localCreatedAt);

      if (sections.isEmpty || sections.last.key != sectionKey) {
        sections.add(_PhotoSectionAccumulator(key: sectionKey, title: sectionTitle));
      }

      sections.last.assets.add(_serializeAsset(asset));
    }

    return sections
        .map((section) {
          return <String, Object?>{'key': section.key, 'title': section.title, 'rows': _chunkAssets(section.assets, 4)};
        })
        .toList(growable: false);
  }

  List<List<Map<String, Object?>>> _chunkAssets(List<Map<String, Object?>> assets, int chunkSize) {
    final rows = <List<Map<String, Object?>>>[];
    for (int index = 0; index < assets.length; index += chunkSize) {
      final end = (index + chunkSize).clamp(0, assets.length).toInt();
      rows.add(assets.sublist(index, end));
    }
    return rows;
  }

  String _formatSectionDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatSectionTitle(DateTime dateTime) {
    return '${dateTime.year}年${dateTime.month}月${dateTime.day}日';
  }

  Map<String, Object?> _serializeAsset(BaseAsset asset) {
    final remoteId = asset.remoteId;
    final localId = asset.localId;
    final thumbHash = asset is RemoteAsset ? asset.thumbHash : null;

    return {
      'id': remoteId ?? localId ?? '${asset.createdAt.microsecondsSinceEpoch}_${asset.name}',
      'localId': localId,
      'remoteId': remoteId,
      'storage': asset.storage.name,
      'thumbnailUrl': remoteId != null ? getThumbnailUrlForRemoteId(remoteId, thumbhash: thumbHash) : null,
      'thumbHash': thumbHash,
      'isVideo': asset.isVideo,
      'durationInSeconds': asset.durationInSeconds ?? 0,
      'createdAt': asset.createdAt.toIso8601String(),
      'width': asset.width,
      'height': asset.height,
      'isFavorite': asset.isFavorite,
    };
  }

  static Future<void> _hydrateLaunchModePreference() async {
    try {
      final stateRaw = await _channel.invokeMethod<String>('getLaunchModePreferenceState');
      final state = stateRaw == null ? const <String, Object?>{} : (jsonDecode(stateRaw) as Map<String, Object?>);
      final initialized = state['initialized'] == true;
      final enabled = state['hybridArkuiPhotos'] == true;

      if (!initialized) {
        if ((Store.tryGet(StoreKey.hybridArkuiPhotos) ?? false) != false) {
          await Store.put(StoreKey.hybridArkuiPhotos, false);
        }
        await setLaunchModePreference(false);
        return;
      }

      if ((Store.tryGet(StoreKey.hybridArkuiPhotos) ?? false) != enabled) {
        await Store.put(StoreKey.hybridArkuiPhotos, enabled);
      }
    } catch (error, stackTrace) {
      debugPrint('Hybrid launch mode preference sync failed: $error\n$stackTrace');
    }
  }
}

class _PhotoSectionAccumulator {
  _PhotoSectionAccumulator({required this.key, required this.title});

  final String key;
  final String title;
  final List<Map<String, Object?>> assets = <Map<String, Object?>>[];
}
