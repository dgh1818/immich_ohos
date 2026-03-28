import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/domain/models/timeline.model.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/extensions/asyncvalue_extensions.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/widgets/action_buttons/download_status_floating_button.widget.dart';
import 'package:immich_mobile/presentation/widgets/bottom_sheet/general_bottom_sheet.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/scrubber.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/segment.model.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.state.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline_drag_region.dart';
import 'package:immich_mobile/providers/infrastructure/readonly_mode.provider.dart';
import 'package:immich_mobile/providers/infrastructure/setting.provider.dart';
import 'package:immich_mobile/providers/infrastructure/timeline.provider.dart';
import 'package:immich_mobile/providers/timeline/multiselect.provider.dart';
import 'package:immich_mobile/utils/debounce.dart';
import 'package:immich_mobile/widgets/common/immich_sliver_app_bar.dart';
import 'package:immich_mobile/widgets/common/mesmerizing_sliver_app_bar.dart';
import 'package:immich_mobile/widgets/common/selection_sliver_app_bar.dart';

class Timeline extends ConsumerStatefulWidget {
  const Timeline({
    super.key,
    this.topSliverWidget,
    this.topSliverWidgetHeight,
    this.bottomSliverWidget,
    this.showStorageIndicator = false,
    this.withStack = false,
    this.appBar = const ImmichSliverAppBar(floating: true, pinned: true, snap: false),
    this.bottomSheet = const GeneralBottomSheet(minChildSize: 0.18),
    this.groupBy,
    this.withScrubber = true,
    this.snapToMonth = true,
    this.initialScrollOffset,
    this.readOnly = false,
    this.persistentBottomBar = false,
    this.loadingWidget,
    this.onScrollAssetChanged,
    this.tilesPerRowOverride,
  });

  final Widget? topSliverWidget;
  final double? topSliverWidgetHeight;
  final Widget? bottomSliverWidget;
  final bool showStorageIndicator;
  final Widget? appBar;
  final Widget? bottomSheet;
  final bool withStack;
  final GroupAssetsBy? groupBy;
  final bool withScrubber;
  final bool snapToMonth;
  final double? initialScrollOffset;
  final bool readOnly;
  final bool persistentBottomBar;
  final Widget? loadingWidget;
  final ValueChanged<BaseAsset?>? onScrollAssetChanged;
  final int? tilesPerRowOverride;

  @override
  ConsumerState<Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<Timeline> {
  void _onColumnCountChanged(int columnCount) {}

  @override
  Widget build(BuildContext context) {
    final effectiveColumnCount =
        widget.tilesPerRowOverride ??
        ref.watch(settingsProvider.select((s) => s.get(Setting.tilesPerRow))) ??
        Setting.tilesPerRow.defaultValue;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: const Padding(padding: EdgeInsets.only(bottom: 60), child: DownloadStatusFloatingButton()),
      body: LayoutBuilder(
        builder: (_, constraints) => ProviderScope(
          overrides: [
            timelineArgsProvider.overrideWith(
              (ref) => TimelineArgs(
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
                columnCount:
                    widget.tilesPerRowOverride ??
                    ref.watch(settingsProvider.select((s) => s.get(Setting.tilesPerRow))) ??
                    Setting.tilesPerRow.defaultValue,
                showStorageIndicator: widget.showStorageIndicator,
                withStack: widget.withStack,
                groupBy: widget.groupBy,
              ),
            ),
            if (widget.readOnly) readonlyModeProvider.overrideWith(() => _AlwaysReadOnlyNotifier()),
          ],
          child: _SliverTimeline(
            topSliverWidget: widget.topSliverWidget,
            topSliverWidgetHeight: widget.topSliverWidgetHeight,
            bottomSliverWidget: widget.bottomSliverWidget,
            appBar: widget.appBar,
            bottomSheet: widget.bottomSheet,
            withScrubber: widget.withScrubber,
            persistentBottomBar: widget.persistentBottomBar,
            snapToMonth: widget.snapToMonth,
            initialScrollOffset: widget.initialScrollOffset,
            maxWidth: constraints.maxWidth,
            loadingWidget: widget.loadingWidget,
            onScrollAssetChanged: widget.onScrollAssetChanged,
            columnCount: effectiveColumnCount,
            onColumnCountChanged: _onColumnCountChanged,
            allowColumnResize: widget.tilesPerRowOverride == null,
          ),
        ),
      ),
    );
  }
}

class _AlwaysReadOnlyNotifier extends ReadOnlyModeNotifier {
  @override
  bool build() => true;

  @override
  void setReadonlyMode(bool value) {}

  @override
  void toggleReadonlyMode() {}
}

class _SliverTimeline extends ConsumerStatefulWidget {
  const _SliverTimeline({
    this.topSliverWidget,
    this.topSliverWidgetHeight,
    this.bottomSliverWidget,
    this.appBar,
    this.bottomSheet,
    this.withScrubber = true,
    this.persistentBottomBar = false,
    this.snapToMonth = true,
    this.initialScrollOffset,
    this.maxWidth,
    this.loadingWidget,
    this.onScrollAssetChanged,
    required this.columnCount,
    this.onColumnCountChanged,
    this.allowColumnResize = true,
  });

  final Widget? topSliverWidget;
  final double? topSliverWidgetHeight;
  final Widget? bottomSliverWidget;
  final Widget? appBar;
  final Widget? bottomSheet;
  final bool withScrubber;
  final bool persistentBottomBar;
  final bool snapToMonth;
  final double? initialScrollOffset;
  final double? maxWidth;
  final Widget? loadingWidget;
  final ValueChanged<BaseAsset?>? onScrollAssetChanged;
  final int columnCount;
  final ValueChanged<int>? onColumnCountChanged;
  final bool allowColumnResize;

  @override
  ConsumerState createState() => _SliverTimelineState();
}

class _SliverTimelineState extends ConsumerState<_SliverTimeline> {
  late final ScrollController _scrollController;
  StreamSubscription? _eventSubscription;
  late final Debouncer _scrollAssetDebouncer;
  List<Segment>? _segmentsCache;
  int? _lastScrollAssetIndex;

  bool _dragging = false;
  TimelineAssetIndex? _dragAnchorIndex;
  final Set<BaseAsset> _draggedAssets = HashSet();
  ScrollPhysics? _scrollPhysics;

  int _perRow = 4;
  double _scaleFactor = 3.0;
  double _baseScaleFactor = 3.0;
  int? _restoreAssetIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: widget.initialScrollOffset ?? 0.0,
      onAttach: _restoreAssetPosition,
    );
    _scrollAssetDebouncer = Debouncer(
      interval: const Duration(milliseconds: 150),
      maxWaitTime: const Duration(milliseconds: 400),
    );
    _scrollController.addListener(_onScroll);
    _eventSubscription = EventStream.shared.listen(_onEvent);

    final currentTilesPerRow = widget.columnCount;
    _perRow = currentTilesPerRow;
    _scaleFactor = 7.0 - _perRow;
    _baseScaleFactor = _scaleFactor;

    ref.listenManual(multiSelectProvider.select((s) => s.isEnabled), _onMultiSelectionToggled);
  }

  @override
  void didUpdateWidget(covariant _SliverTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.maxWidth != oldWidget.maxWidth || widget.columnCount != oldWidget.columnCount) {
      final asyncSegments = ref.read(timelineSegmentProvider);
      asyncSegments.whenData((segments) {
        final index = _getCurrentAssetIndex(segments);
        final _ = ref.refresh(timelineArgsProvider);
        _restoreAssetIndex = index;
      });
    }
  }

  void _onEvent(Event event) {
    switch (event) {
      case ScrollToTopEvent():
        ref.read(timelineStateProvider.notifier).setScrubbing(true);
        _scrollController
            .animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut)
            .whenComplete(() => ref.read(timelineStateProvider.notifier).setScrubbing(false));

      case ScrollToDateEvent scrollToDateEvent:
        _scrollToDate(scrollToDateEvent.date);
      case TimelineReloadEvent():
        setState(() {});
      default:
        break;
    }
  }

  void _restoreAssetPosition(_) {
    if (_restoreAssetIndex == null) {
      return;
    }

    final asyncSegments = ref.read(timelineSegmentProvider);
    asyncSegments.whenData((segments) {
      final targetSegment = segments.lastWhereOrNull((segment) => segment.firstAssetIndex <= _restoreAssetIndex!);
      if (targetSegment != null) {
        final assetIndexInSegment = _restoreAssetIndex! - targetSegment.firstAssetIndex;
        final newColumnCount = ref.read(timelineArgsProvider).columnCount;
        final rowIndexInSegment = (assetIndexInSegment / newColumnCount).floor();
        final targetRowIndex = targetSegment.firstIndex + 1 + rowIndexInSegment;
        final targetOffset = targetSegment.indexToLayoutOffset(targetRowIndex);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollController.jumpTo(targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent));
          }
        });
      }
    });
    _restoreAssetIndex = null;
  }

  void _onMultiSelectionToggled(_, bool isEnabled) {
    EventStream.shared.emit(MultiSelectToggleEvent(isEnabled));
  }

  int? _getCurrentAssetIndex(List<Segment> segments) {
    final currentOffset = _scrollController.offset.clamp(0.0, _scrollController.position.maxScrollExtent);
    final segment = segments.findByOffset(currentOffset) ?? segments.lastOrNull;
    int? targetAssetIndex;
    if (segment != null) {
      final rowIndex = segment.getMinChildIndexForScrollOffset(currentOffset);
      if (rowIndex > segment.firstIndex) {
        final rowIndexInSegment = rowIndex - (segment.firstIndex + 1);
        final assetsPerRow = ref.read(timelineArgsProvider).columnCount;
        final assetIndexInSegment = rowIndexInSegment * assetsPerRow;
        targetAssetIndex = segment.firstAssetIndex + assetIndexInSegment;
      } else {
        targetAssetIndex = segment.firstAssetIndex;
      }
    }
    return targetAssetIndex;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _eventSubscription?.cancel();
    _scrollAssetDebouncer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onScrollAssetChanged == null) {
      return;
    }
    _scrollAssetDebouncer.run(_emitScrollAsset);
  }

  Future<void> _emitScrollAsset() async {
    if (!mounted || widget.onScrollAssetChanged == null) {
      return;
    }

    final segments = _segmentsCache;
    if (segments == null || segments.isEmpty || !_scrollController.hasClients) {
      return;
    }

    final timelineService = ref.read(timelineServiceProvider);
    final totalAssets = timelineService.totalAssets;
    if (totalAssets == 0) {
      if (_lastScrollAssetIndex != null) {
        _lastScrollAssetIndex = null;
        widget.onScrollAssetChanged?.call(null);
      }
      return;
    }

    final offset = _scrollController.offset;
    final segment = segments.findByOffset(offset);
    if (segment == null) {
      return;
    }

    final rowIndex = segment.getMinChildIndexForScrollOffset(offset);
    final columnCount = ref.read(timelineArgsProvider).columnCount;
    int assetIndex;
    if (rowIndex <= segment.firstIndex) {
      assetIndex = segment.firstAssetIndex;
    } else {
      final rowIndexInSegment = rowIndex - (segment.firstIndex + 1);
      assetIndex = segment.firstAssetIndex + (rowIndexInSegment * columnCount);
    }

    if (assetIndex < 0) {
      assetIndex = 0;
    } else if (assetIndex >= totalAssets) {
      assetIndex = totalAssets - 1;
    }

    if (_lastScrollAssetIndex == assetIndex) {
      return;
    }
    _lastScrollAssetIndex = assetIndex;

    final asset = await timelineService.getAssetAsync(assetIndex);
    if (!mounted) {
      return;
    }
    widget.onScrollAssetChanged?.call(asset);
  }

  void _scrollToDate(DateTime date) {
    final asyncSegments = ref.read(timelineSegmentProvider);
    asyncSegments.whenData((segments) {
      final targetSegment = segments.firstWhereOrNull((segment) {
        if (segment.bucket is TimeBucket) {
          final segmentDate = (segment.bucket as TimeBucket).date;
          return segmentDate.year == date.year && segmentDate.month == date.month && segmentDate.day == date.day;
        }
        return false;
      });

      final fallbackSegment =
          targetSegment ??
          segments.firstWhereOrNull((segment) {
            if (segment.bucket is TimeBucket) {
              final segmentDate = (segment.bucket as TimeBucket).date;
              return segmentDate.year == date.year && segmentDate.month == date.month;
            }
            return false;
          });

      if (fallbackSegment != null) {
        final targetOffset = fallbackSegment.startOffset - 50;
        ref.read(timelineStateProvider.notifier).setScrubbing(true);
        _scrollController
            .animateTo(
              targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            )
            .whenComplete(() => ref.read(timelineStateProvider.notifier).setScrubbing(false));
      } else {
        ref.read(timelineStateProvider.notifier).setScrubbing(false);
      }
    });
  }

  void _setDragStartIndex(TimelineAssetIndex index) {
    setState(() {
      _scrollPhysics = const ClampingScrollPhysics();
      _dragAnchorIndex = index;
      _dragging = true;
    });
  }

  void _stopDrag() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _scrollPhysics = null;
      });
    });
    setState(() {
      _dragging = false;
      _draggedAssets.clear();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(timelineStateProvider.notifier).setScrolling(false);
      }
    });
  }

  void _dragScroll(ScrollDirection direction) {
    _scrollController.animateTo(
      _scrollController.offset + (direction == ScrollDirection.forward ? 175 : -175),
      duration: const Duration(milliseconds: 125),
      curve: Curves.easeOut,
    );
  }

  void _handleDragAssetEnter(TimelineAssetIndex index) {
    if (_dragAnchorIndex == null || !_dragging) {
      return;
    }

    final timelineService = ref.read(timelineServiceProvider);
    final dragAnchorIndex = _dragAnchorIndex!;

    final startIndex = math.min(dragAnchorIndex.assetIndex, index.assetIndex);
    final endIndex = math.max(dragAnchorIndex.assetIndex, index.assetIndex);
    final count = endIndex - startIndex + 1;

    if (timelineService.hasRange(startIndex, count)) {
      final selectedAssets = timelineService.getAssets(startIndex, count);

      final multiSelectNotifier = ref.read(multiSelectProvider.notifier);
      for (final asset in _draggedAssets) {
        multiSelectNotifier.deselectAsset(asset);
      }
      _draggedAssets.clear();

      for (final asset in selectedAssets) {
        multiSelectNotifier.selectAsset(asset);
        _draggedAssets.add(asset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncSegments = ref.watch(timelineSegmentProvider);
    final maxHeight = ref.watch(timelineArgsProvider.select((args) => args.maxHeight));
    final isSelectionMode = ref.watch(multiSelectProvider.select((s) => s.forceEnable));
    final isMultiSelectEnabled = ref.watch(multiSelectProvider.select((s) => s.isEnabled));
    final isReadonlyModeEnabled = ref.watch(readonlyModeProvider);
    final isMultiSelectStatusVisible = !isSelectionMode && isMultiSelectEnabled;
    final isBottomWidgetVisible =
        widget.bottomSheet != null && (isMultiSelectStatusVisible || widget.persistentBottomBar);

    return PopScope(
      canPop: !isMultiSelectEnabled,
      onPopInvokedWithResult: (_, __) {
        if (isMultiSelectEnabled) {
          ref.read(multiSelectProvider.notifier).reset();
        }
      },
      child: asyncSegments.widgetWhen(
        onLoading: widget.loadingWidget != null ? () => widget.loadingWidget! : null,
        onData: (segments) {
          _segmentsCache = segments;
          final childCount = (segments.lastOrNull?.lastIndex ?? -1) + 1;
          final double appBarExpandedHeight = widget.appBar != null && widget.appBar is MesmerizingSliverAppBar
              ? 200
              : 0;
          final topPadding = widget.appBar == null ? 0.0 : 50.0;
          const sharedBottomPadding = 150.0;

          final grid = CustomScrollView(
            primary: true,
            physics: _scrollPhysics,
            cacheExtent: maxHeight * 6,
            slivers: [
              if (isSelectionMode) const SelectionSliverAppBar() else if (widget.appBar != null) widget.appBar!,
              if (widget.topSliverWidget != null) widget.topSliverWidget!,
              _SliverSegmentedList(
                segments: segments,
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    if (index >= childCount) {
                      return null;
                    }
                    final segment = segments.findByIndex(index);
                    return segment?.builder(ctx, index) ?? const SizedBox.shrink();
                  },
                  childCount: childCount,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                ),
              ),
              if (widget.bottomSliverWidget != null) widget.bottomSliverWidget!,
              const SliverPadding(padding: EdgeInsets.only(bottom: sharedBottomPadding)),
            ],
          );

          final Widget timeline;
          if (widget.withScrubber) {
            timeline = Scrubber(
              snapToMonth: widget.snapToMonth,
              layoutSegments: segments,
              timelineHeight: maxHeight,
              topPadding: topPadding,
              bottomPadding: sharedBottomPadding,
              monthSegmentSnappingOffset: (widget.topSliverWidgetHeight ?? 0) + appBarExpandedHeight,
              hasAppBar: widget.appBar != null,
              child: grid,
            );
          } else {
            timeline = grid;
          }

          return PrimaryScrollController(
            controller: _scrollController,
            child: RawGestureDetector(
              gestures: {
                CustomScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<CustomScaleGestureRecognizer>(
                  () => CustomScaleGestureRecognizer(),
                  (CustomScaleGestureRecognizer scale) {
                    scale.onStart = (details) {
                      _baseScaleFactor = _scaleFactor;
                    };

                    scale.onUpdate = (details) {
                      if (!widget.allowColumnResize) {
                        return;
                      }
                      final newScaleFactor = math.max(math.min(5.0, _baseScaleFactor * details.scale), 1.0);
                      final newPerRow = 7 - newScaleFactor.toInt();

                      if (newPerRow != _perRow) {
                        final targetAssetIndex = _getCurrentAssetIndex(segments);
                        setState(() {
                          _scaleFactor = newScaleFactor;
                          _perRow = newPerRow;
                          _restoreAssetIndex = targetAssetIndex;
                        });

                        widget.onColumnCountChanged?.call(_perRow);
                        ref.read(settingsProvider.notifier).set(Setting.tilesPerRow, _perRow);
                      }
                    };
                  },
                ),
              },
              child: TimelineDragRegion(
                onStart: !isReadonlyModeEnabled ? _setDragStartIndex : null,
                onAssetEnter: _handleDragAssetEnter,
                onEnd: !isReadonlyModeEnabled ? _stopDrag : null,
                onScroll: _dragScroll,
                onScrollStart: () {
                  ref.read(timelineStateProvider.notifier).setScrolling(true);
                },
                child: Stack(
                  children: [
                    timeline,
                    if (isBottomWidgetVisible)
                      Positioned(
                        top: MediaQuery.paddingOf(context).top,
                        left: 25,
                        child: const SizedBox(
                          height: kToolbarHeight,
                          child: Center(child: _MultiSelectStatusButton()),
                        ),
                      ),
                    if (isBottomWidgetVisible) widget.bottomSheet!,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverSegmentedList extends SliverMultiBoxAdaptorWidget {
  final List<Segment> _segments;

  const _SliverSegmentedList({required List<Segment> segments, required super.delegate}) : _segments = segments;

  @override
  _RenderSliverTimelineBoxAdaptor createRenderObject(BuildContext context) =>
      _RenderSliverTimelineBoxAdaptor(childManager: context as SliverMultiBoxAdaptorElement, segments: _segments);

  @override
  void updateRenderObject(BuildContext context, _RenderSliverTimelineBoxAdaptor renderObject) {
    renderObject.segments = _segments;
  }
}

class _RenderSliverTimelineBoxAdaptor extends RenderSliverMultiBoxAdaptor {
  List<Segment> _segments;

  set segments(List<Segment> updatedSegments) {
    if (_segments.equals(updatedSegments)) {
      return;
    }
    _segments = updatedSegments;
    markNeedsLayout();
  }

  _RenderSliverTimelineBoxAdaptor({required super.childManager, required List<Segment> segments})
    : _segments = segments;

  int getMinChildIndexForScrollOffset(double offset) =>
      _segments.findByOffset(offset)?.getMinChildIndexForScrollOffset(offset) ?? 0;

  int getMaxChildIndexForScrollOffset(double offset) =>
      _segments.findByOffset(offset)?.getMaxChildIndexForScrollOffset(offset) ?? 0;

  double indexToLayoutOffset(int index) =>
      (_segments.findByIndex(index) ?? _segments.lastOrNull)?.indexToLayoutOffset(index) ?? 0;

  double estimateMaxScrollOffset() => _segments.lastOrNull?.endOffset ?? 0;

  double computeMaxScrollOffset() => _segments.lastOrNull?.endOffset ?? 0;

  @override
  void performLayout() {
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    assert(scrollOffset >= 0.0);

    final double remainingExtent = constraints.remainingCacheExtent;
    assert(remainingExtent >= 0.0);

    final double targetScrollOffset = scrollOffset + remainingExtent;

    final int firstRequiredChildIndex = getMinChildIndexForScrollOffset(scrollOffset);

    final int? lastRequiredChildIndex = targetScrollOffset.isFinite
        ? getMaxChildIndexForScrollOffset(targetScrollOffset)
        : null;

    if (firstChild == null) {
      collectGarbage(0, 0);
    } else {
      final int leadingChildrenToRemove = calculateLeadingGarbage(firstIndex: firstRequiredChildIndex);
      final int trailingChildrenToRemove = lastRequiredChildIndex == null
          ? 0
          : calculateTrailingGarbage(lastIndex: lastRequiredChildIndex);
      collectGarbage(leadingChildrenToRemove, trailingChildrenToRemove);
    }

    if (firstChild == null) {
      final double firstChildLayoutOffset = indexToLayoutOffset(firstRequiredChildIndex);
      final bool childAdded = addInitialChild(index: firstRequiredChildIndex, layoutOffset: firstChildLayoutOffset);

      if (!childAdded) {
        final double max = firstRequiredChildIndex <= 0 ? 0.0 : computeMaxScrollOffset();
        geometry = SliverGeometry(scrollExtent: max, maxPaintExtent: max);
        childManager.didFinishLayout();
        return;
      }
    }

    RenderBox? highestLaidOutChild;
    final childConstraints = constraints.asBoxConstraints();

    for (int currentIndex = indexOf(firstChild!) - 1; currentIndex >= firstRequiredChildIndex; --currentIndex) {
      final RenderBox? newLeadingChild = insertAndLayoutLeadingChild(childConstraints);
      if (newLeadingChild == null) {
        final Segment? segment = _segments.findByIndex(currentIndex) ?? _segments.firstOrNull;
        geometry = SliverGeometry(scrollOffsetCorrection: segment?.indexToLayoutOffset(currentIndex) ?? 0.0);
        return;
      }
      final childParentData = newLeadingChild.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = indexToLayoutOffset(currentIndex);
      assert(childParentData.index == currentIndex);
      highestLaidOutChild ??= newLeadingChild;
    }

    if (highestLaidOutChild == null) {
      firstChild!.layout(childConstraints);
      final childParentData = firstChild!.parentData! as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = indexToLayoutOffset(firstRequiredChildIndex);
      highestLaidOutChild = firstChild;
    }

    RenderBox? mostRecentlyLaidOutChild = highestLaidOutChild;
    double calculatedMaxScrollOffset = double.infinity;

    for (
      int currentIndex = indexOf(mostRecentlyLaidOutChild!) + 1;
      lastRequiredChildIndex == null || currentIndex <= lastRequiredChildIndex;
      ++currentIndex
    ) {
      RenderBox? child = childAfter(mostRecentlyLaidOutChild!);

      if (child == null || indexOf(child) != currentIndex) {
        child = insertAndLayoutChild(childConstraints, after: mostRecentlyLaidOutChild);
        if (child == null) {
          final Segment? segment = _segments.findByIndex(currentIndex) ?? _segments.lastOrNull;
          calculatedMaxScrollOffset = segment?.indexToLayoutOffset(currentIndex) ?? computeMaxScrollOffset();
          break;
        }
      } else {
        child.layout(childConstraints);
      }

      mostRecentlyLaidOutChild = child;
      final childParentData = mostRecentlyLaidOutChild.parentData! as SliverMultiBoxAdaptorParentData;
      assert(childParentData.index == currentIndex);
      childParentData.layoutOffset = indexToLayoutOffset(currentIndex);
    }

    final int lastLaidOutChildIndex = indexOf(lastChild!);
    final double leadingScrollOffset = indexToLayoutOffset(firstRequiredChildIndex);
    final double trailingScrollOffset = indexToLayoutOffset(lastLaidOutChildIndex + 1);

    assert(
      firstRequiredChildIndex == 0 ||
          (childScrollOffset(firstChild!) ?? -1.0) - scrollOffset <= precisionErrorTolerance,
    );
    assert(debugAssertChildListIsNonEmptyAndContiguous());
    assert(indexOf(firstChild!) == firstRequiredChildIndex);
    assert(lastRequiredChildIndex == null || lastLaidOutChildIndex <= lastRequiredChildIndex);

    calculatedMaxScrollOffset = math.min(calculatedMaxScrollOffset, estimateMaxScrollOffset());

    final double paintExtent = calculatePaintOffset(constraints, from: leadingScrollOffset, to: trailingScrollOffset);
    final double cacheExtent = calculateCacheOffset(constraints, from: leadingScrollOffset, to: trailingScrollOffset);

    final double targetEndScrollOffsetForPaint = constraints.scrollOffset + constraints.remainingPaintExtent;
    final int? targetLastIndexForPaint = targetEndScrollOffsetForPaint.isFinite
        ? getMaxChildIndexForScrollOffset(targetEndScrollOffsetForPaint)
        : null;

    final maxPaintExtent = math.max(paintExtent, calculatedMaxScrollOffset);

    geometry = SliverGeometry(
      scrollExtent: calculatedMaxScrollOffset,
      paintExtent: paintExtent,
      maxPaintExtent: maxPaintExtent,
      hasVisualOverflow:
          (targetLastIndexForPaint != null && lastLaidOutChildIndex >= targetLastIndexForPaint) ||
          constraints.scrollOffset > 0.0,
      cacheExtent: cacheExtent,
    );

    if (calculatedMaxScrollOffset == trailingScrollOffset) {
      childManager.setDidUnderflow(true);
    }

    childManager.didFinishLayout();
  }
}

class _MultiSelectStatusButton extends ConsumerWidget {
  const _MultiSelectStatusButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectCount = ref.watch(multiSelectProvider.select((s) => s.selectedAssets.length));
    return ElevatedButton.icon(
      onPressed: () => ref.read(multiSelectProvider.notifier).reset(),
      icon: Icon(Icons.close_rounded, color: context.colorScheme.onPrimary),
      label: Text(
        selectCount.toString(),
        style: context.textTheme.titleMedium?.copyWith(height: 2.5, color: context.colorScheme.onPrimary),
      ),
    );
  }
}

class CustomScaleGestureRecognizer extends ScaleGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}
