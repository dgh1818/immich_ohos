import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/models/user.model.dart';
import 'package:immich_mobile/domain/services/timeline.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/timeline.repository.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/asset_viewer.page.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/routing/router.dart';
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
  static const int _defaultSyncRemoteHeadPredownloadPages = 4;
  static HybridArkuiBridgeService? _instance;
  static AppRouter? _router;
  static WidgetRef? _uiRef;
  static final Logger _staticLog = Logger('HybridArkuiBridgeService');

  final DriftTimelineRepository _timelineRepository;
  final Logger _log = Logger('HybridArkuiBridgeService');

  static void bindUi({required AppRouter router, required WidgetRef ref}) {
    _router = router;
    _uiRef = ref;
  }

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

  static Future<void> predownloadTimelineHeadThumbnailsAfterRemoteSync({
    int pages = _defaultSyncRemoteHeadPredownloadPages,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.ohos) {
      return;
    }

    final enabled = Store.tryGet(StoreKey.hybridArkuiPhotos) ?? false;
    final accessToken = Store.tryGet<String>(StoreKey.accessToken);
    final serverEndpoint = Store.tryGet<String>(StoreKey.serverEndpoint);
    if (!enabled || accessToken == null || accessToken.isEmpty || serverEndpoint == null || serverEndpoint.isEmpty) {
      return;
    }

    final normalizedPages = pages.clamp(1, 4).toInt();
    try {
      await _channel.invokeMethod<void>('predownloadTimelineHeadThumbnails', {
        'pages': normalizedPages,
      });
    } catch (error, stackTrace) {
      _staticLog.fine('Failed to schedule hybrid head thumbnail predownload after remote sync', error, stackTrace);
    }
  }

  Future<Object?> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'getLaunchMode':
        return _getLaunchMode().value;
      case 'fetchTimelineWindow':
        final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
        final offset = (args['offset'] as num?)?.toInt() ?? 0;
        final requestedLimit = (args['limit'] as num?)?.toInt() ?? 90;
        final limit = requestedLimit.clamp(30, 360).toInt();
        final timelineWindow = await _buildTimelineWindowPayload(offset: offset, limit: limit);
        return jsonEncode(timelineWindow);
      case 'openTimelineAssetViewerAt':
        final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
        final index = (args['index'] as num?)?.toInt() ?? -1;
        await _openTimelineAssetViewerAt(index);
        return true;
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

  Future<Map<String, Object?>> _buildTimelineWindowPayload({required int offset, required int limit}) async {
    if (_getLaunchMode() != OhosLaunchMode.hybridArkuiPhotos) {
      return _unavailablePage('Hybrid ArkUI photos mode is disabled');
    }

    final currentUser = Store.tryGet<UserDto>(StoreKey.currentUser);
    final serverEndpoint = Store.tryGet<String>(StoreKey.serverEndpoint);
    if (currentUser == null || serverEndpoint == null || serverEndpoint.isEmpty) {
      return _unavailablePage('Missing authenticated session context');
    }

    final userIds = await _resolveTimelineUserIds(currentUser.id);
    final timelineQuery = _timelineRepository.main(userIds, GroupAssetsBy.day);
    final assets = await timelineQuery.assetSource(offset, limit);
    final sections = _chunkIntoSections(assets);
    final bucketMetadata = offset == 0
        ? await _buildBucketMetadata(userIds)
        : const _HybridBucketMetadata.empty();
    final groupDayGroups = _buildGroupDayGroups(sections, offset);
    final nextOffset = offset + assets.length;
    final hasMore = assets.length >= limit;
    final shouldLogTotalAssetCount = offset == 0 || !hasMore;
    final totalAssetCount = shouldLogTotalAssetCount
        ? await _resolveTimelineTotalAssetCount(timelineQuery)
        : null;
    final totalHasMore = totalAssetCount != null ? nextOffset < totalAssetCount : null;
    final firstAsset = assets.isNotEmpty ? assets.first : null;
    final lastAsset = assets.isNotEmpty ? assets.last : null;
    final firstAssetId = firstAsset?.remoteId ?? firstAsset?.localId ?? '';
    final lastAssetId = lastAsset?.remoteId ?? lastAsset?.localId ?? '';

    print(
      '[HybridArkuiBridgeService] fetchTimelineWindow result: '
      'offset=$offset limit=$limit returned=${assets.length} '
      'hasMore=${hasMore ? 1 : 0} nextOffset=$nextOffset windowEndOffset=$nextOffset '
      'totalAssetCount=${totalAssetCount ?? -1} totalHasMore=${totalHasMore == null ? -1 : (totalHasMore ? 1 : 0)} '
      'sections=${sections.length} groupDayGroups=${groupDayGroups.length} userIds=${userIds.length} '
      'firstAssetId=$firstAssetId firstCreatedAt=${firstAsset?.createdAt.toIso8601String() ?? ''} '
      'lastAssetId=$lastAssetId lastCreatedAt=${lastAsset?.createdAt.toIso8601String() ?? ''}',
    );

    return {
      'ready': true,
      'offset': offset,
      'nextOffset': nextOffset,
      'hasMore': hasMore,
      'windowStartOffset': offset,
      'windowEndOffset': nextOffset,
      'sections': sections,
      'groupDayGroups': groupDayGroups,
      'yearBuckets': bucketMetadata.yearBuckets,
      'monthBuckets': bucketMetadata.monthBuckets,
    };
  }

  Future<int?> _resolveTimelineTotalAssetCount(TimelineQuery timelineQuery) async {
    try {
      final buckets = await _firstBucketsOrEmpty(timelineQuery.bucketSource());
      return buckets.fold<int>(0, (total, bucket) => total + bucket.assetCount);
    } catch (error, stackTrace) {
      print(
        '[HybridArkuiBridgeService] Failed to resolve hybrid timeline total asset count: '
        'error=$error stackTrace=$stackTrace',
      );
      return null;
    }
  }

  Future<_HybridBucketMetadata> _buildBucketMetadata(List<String> userIds) async {
    try {
      final monthBuckets = await _firstBucketsOrEmpty(
        _timelineRepository.main(userIds, GroupAssetsBy.month).bucketSource(),
      );
      final timeBuckets = monthBuckets.whereType<TimeBucket>().toList(growable: false);
      if (timeBuckets.isEmpty) {
        return const _HybridBucketMetadata.empty();
      }

      final monthBucketPayload = <Map<String, Object?>>[];
      final yearBucketPayload = <Map<String, Object?>>[];
      String? currentYear;
      int currentYearOffset = 0;
      int currentYearCount = 0;
      int runningOffset = 0;

      for (final bucket in timeBuckets) {
        final localBucketDate = bucket.date.toLocal();
        final monthKey = _formatMonthDate(localBucketDate);
        final yearKey = _formatYearDate(localBucketDate);
        monthBucketPayload.add({
          'date': monthKey,
          'count': bucket.assetCount,
          'offset': runningOffset,
        });

        if (currentYear != null && currentYear != yearKey) {
          yearBucketPayload.add({
            'date': currentYear,
            'count': currentYearCount,
            'offset': currentYearOffset,
          });
          currentYearCount = 0;
        }

        if (currentYear != yearKey) {
          currentYear = yearKey;
          currentYearOffset = runningOffset;
        }

        currentYearCount += bucket.assetCount;
        runningOffset += bucket.assetCount;
      }

      if (currentYear != null) {
        yearBucketPayload.add({
          'date': currentYear,
          'count': currentYearCount,
          'offset': currentYearOffset,
        });
      }

      return _HybridBucketMetadata(
        yearBuckets: yearBucketPayload,
        monthBuckets: monthBucketPayload,
      );
    } catch (error, stackTrace) {
      _log.warning('Failed to build hybrid timeline bucket metadata', error, stackTrace);
      return const _HybridBucketMetadata.empty();
    }
  }

  Future<List<TBucket>> _firstBucketsOrEmpty<TBucket extends Bucket>(Stream<List<TBucket>> stream) {
    return _firstBucketsOrEmptyImpl(stream);
  }

  Future<List<TBucket>> _firstBucketsOrEmptyImpl<TBucket extends Bucket>(Stream<List<TBucket>> stream) async {
    try {
      return await stream.first.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      return <TBucket>[];
    }
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
    return {
      'ready': false,
      'offset': 0,
      'hasMore': false,
      'nextOffset': 0,
      'windowStartOffset': 0,
      'windowEndOffset': 0,
      'sections': const <Object?>[],
      'groupDayGroups': const <Object?>[],
      'yearBuckets': const <Object?>[],
      'monthBuckets': const <Object?>[],
      'reason': reason,
    };
  }

  List<Map<String, Object?>> _buildGroupDayGroups(
    List<Map<String, Object?>> sections,
    int windowStartOffset,
  ) {
    final groups = <Map<String, Object?>>[];
    int runningOffset = windowStartOffset;
    for (final section in sections) {
      final rows = (section['rows'] as List<Object?>?) ?? const <Object?>[];
      int count = 0;
      for (final row in rows) {
        if (row is List<Object?>) {
          count += row.length;
        }
      }
      groups.add({
        'key': section['key'],
        'title': section['title'],
        'count': count,
        'offset': runningOffset,
      });
      runningOffset += count;
    }
    return groups;
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
    return _formatSectionDate(dateTime);
  }

  String _formatMonthDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  String _formatYearDate(DateTime dateTime) {
    return dateTime.year.toString().padLeft(4, '0');
  }

  Map<String, Object?> _serializeAsset(BaseAsset asset) {
    final remoteId = asset.remoteId;
    final localId = asset.localId;
    final thumbHash = asset is RemoteAsset ? asset.thumbHash : null;
    final localCreatedAt = asset.createdAt.toLocal();

    return {
      'id': remoteId ?? localId ?? '${asset.createdAt.microsecondsSinceEpoch}_${asset.name}',
      'localId': localId,
      'remoteId': remoteId,
      'storage': asset.storage.name,
      'thumbnailUrl': remoteId != null ? getThumbnailUrlForRemoteId(remoteId, thumbhash: thumbHash) : null,
      'thumbHash': thumbHash,
      'isVideo': asset.isVideo,
      'durationInSeconds': asset.durationInSeconds ?? 0,
      'createdAt': localCreatedAt.toIso8601String(),
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

  Future<void> _openTimelineAssetViewerAt(int index) async {
    if (index < 0) {
      throw ArgumentError.value(index, 'index', 'Timeline asset index must be non-negative');
    }

    final router = _router;
    final ref = _uiRef;
    if (router == null || ref == null) {
      throw StateError('Hybrid asset viewer is not ready');
    }

    final currentUser = Store.tryGet<UserDto>(StoreKey.currentUser);
    if (currentUser == null) {
      throw StateError('Missing current user for hybrid asset viewer');
    }

    final timelineUsers = await _resolveTimelineUserIds(currentUser.id);
    final timelineService = ref.read(timelineFactoryProvider).main(timelineUsers);

    try {
      final asset = await timelineService.getAssetAsync(index);
      if (asset == null) {
        throw StateError('Timeline asset at index $index is unavailable');
      }

      AssetViewer.setAsset(ref, asset);
      final routeFuture = router.push(AssetViewerRoute(initialIndex: index, timelineService: timelineService));
      await _setHybridSelectedPane(1);
      unawaited(
        routeFuture.whenComplete(() async {
          await timelineService.dispose();
          await _setHybridSelectedPane(0);
        }),
      );
    } catch (_) {
      await timelineService.dispose();
      rethrow;
    }
  }

  Future<void> _setHybridSelectedPane(int pane) async {
    try {
      await _channel.invokeMethod<void>('setHybridSelectedPane', pane);
    } catch (error, stackTrace) {
      _log.warning('Failed to sync hybrid selected pane', error, stackTrace);
    }
  }
}

class _PhotoSectionAccumulator {
  _PhotoSectionAccumulator({required this.key, required this.title});

  final String key;
  final String title;
  final List<Map<String, Object?>> assets = <Map<String, Object?>>[];
}

class _HybridBucketMetadata {
  const _HybridBucketMetadata({
    required this.yearBuckets,
    required this.monthBuckets,
  });

  const _HybridBucketMetadata.empty()
      : yearBuckets = const <Map<String, Object?>>[],
        monthBuckets = const <Map<String, Object?>>[];

  final List<Map<String, Object?>> yearBuckets;
  final List<Map<String, Object?>> monthBuckets;
}
