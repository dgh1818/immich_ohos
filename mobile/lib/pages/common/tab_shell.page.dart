import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/constants.dart';
import 'package:immich_mobile/domain/models/events.model.dart';
import 'package:immich_mobile/domain/utils/event_stream.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/presentation/pages/search/paginated_search.provider.dart';
import 'package:immich_mobile/providers/haptic_feedback.provider.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';
import 'package:immich_mobile/providers/infrastructure/people.provider.dart';
import 'package:immich_mobile/providers/infrastructure/readonly_mode.provider.dart';
import 'package:immich_mobile/providers/search/search_input_focus.provider.dart';
import 'package:immich_mobile/providers/tab.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/floating_glass_bottom_navigation_bar.dart';

import 'package:flutter_svg/svg.dart';

@RoutePage()
class TabShellPage extends ConsumerStatefulWidget {
  const TabShellPage({super.key});

  @override
  ConsumerState<TabShellPage> createState() => _TabShellPageState();
}

class _TabShellPageState extends ConsumerState<TabShellPage> with SingleTickerProviderStateMixin {
  bool isRailExpanded = true;
  late final AnimationController animationController;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void toggleRail() {
    isRailExpanded ? animationController.forward() : animationController.reverse();
    setState(() => isRailExpanded = !isRailExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final isScreenLandscape = context.orientation == Orientation.landscape;
    final isReadonlyModeEnabled = ref.watch(readonlyModeProvider);

    const railWidth = 72.0;

    final navigationDestinations = [
      NavigationDestination(
        label: 'photos'.tr(),
        icon: const Icon(Icons.photo_library_outlined),
        selectedIcon: Icon(Icons.photo_library, color: context.primaryColor),
      ),
      NavigationDestination(
        label: 'search'.tr(),
        icon: const Icon(Icons.search_rounded),
        selectedIcon: Icon(Icons.search, color: context.primaryColor),
        enabled: !isReadonlyModeEnabled,
      ),
      NavigationDestination(
        label: 'albums'.tr(),
        icon: const Icon(Icons.photo_album_outlined),
        selectedIcon: Icon(Icons.photo_album_rounded, color: context.primaryColor),
        enabled: !isReadonlyModeEnabled,
      ),
      NavigationDestination(
        label: 'library'.tr(),
        icon: const Icon(Icons.space_dashboard_outlined),
        selectedIcon: Icon(Icons.space_dashboard_rounded, color: context.primaryColor),
        enabled: !isReadonlyModeEnabled,
      ),
    ];

    Widget navigationRail(TabsRouter tabsRouter) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        left: isRailExpanded ? 0 : -railWidth,
        top: 0,
        bottom: 0,
        child: Material(
          elevation: 4,
          child: NavigationRail(
            destinations: navigationDestinations
                .map(
                  (e) => NavigationRailDestination(
                    icon: e.icon,
                    label: Text(e.label),
                    selectedIcon: e.selectedIcon,
                    disabled: !e.enabled,
                  ),
                )
                .toList(),
            onDestinationSelected: (index) => _onNavigationSelected(tabsRouter, index, ref),
            selectedIndex: tabsRouter.activeIndex,
            labelType: NavigationRailLabelType.all,
            groupAlignment: 0.0,
          ),
        ),
      );
    }

    Widget buildLogo() {
      return Badge(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        backgroundColor: context.primaryColor,
        alignment: Alignment.centerRight,
        offset: const Offset(16, -8),
        label: Text(
          'β',
          style: TextStyle(
            fontSize: 11,
            color: context.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'OverpassMono',
            height: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: SvgPicture.asset('assets/immich-logo.svg', height: 40),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final baseWidth = screenWidth - railWidth;
    final targetScale = screenWidth / baseWidth;

    return AutoTabsRouter(
      routes: const [MainTimelineRoute(), DriftSearchRoute(), DriftAlbumsRoute(), DriftLibraryRoute()],
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (context, child, animation) => FadeTransition(opacity: animation, child: child),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        final heroedChild = HeroControllerScope(controller: HeroController(), child: child);
        return PopScope(
          canPop: tabsRouter.activeIndex == 0,
          onPopInvokedWithResult: (didPop, _) => !didPop ? tabsRouter.setActiveIndex(0) : null,
          child: Scaffold(
            extendBody: !isScreenLandscape,
            resizeToAvoidBottomInset: false,
            body: isScreenLandscape
                ? Stack(
                    children: [
                      navigationRail(tabsRouter),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        top: 0,
                        bottom: 0,
                        left: isRailExpanded ? railWidth : 0,
                        right: 0,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: AnimatedBuilder(
                              animation: animationController,
                              builder: (context, _) {
                                final scale = 1.0 + (targetScale - 1.0) * animationController.value;
                                return Transform.scale(
                                  scale: scale,
                                  alignment: Alignment.topRight,
                                  child: SizedBox(width: baseWidth, child: heroedChild),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 30,
                        left: 10,
                        child: GestureDetector(
                          onTap: toggleRail,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: buildLogo(),
                          ),
                        ),
                      ),
                    ],
                  )
                : child,
            bottomNavigationBar: _BottomNavigationBar(tabsRouter: tabsRouter, destinations: navigationDestinations),
          ),
        );
      },
    );
  }
}

void _onNavigationSelected(TabsRouter router, int index, WidgetRef ref) {
  // On Photos page menu tapped
  if (router.activeIndex == kPhotoTabIndex && index == kPhotoTabIndex) {
    EventStream.shared.emit(const ScrollToTopEvent());
  }

  if (index == kPhotoTabIndex) {
    ref.invalidate(driftMemoryFutureProvider);
  }

  if (router.activeIndex != kSearchTabIndex && index == kSearchTabIndex) {
    ref.read(searchPreFilterProvider.notifier).clear();
  }

  // On Search page tapped
  if (router.activeIndex == kSearchTabIndex && index == kSearchTabIndex) {
    ref.read(searchInputFocusProvider).requestFocus();
  }

  // Album page
  if (index == kAlbumTabIndex) {
    ref.read(remoteAlbumProvider.notifier).refresh();
  }

  // Library page
  if (index == kLibraryTabIndex) {
    ref.invalidate(localAlbumProvider);
    ref.invalidate(driftGetAllPeopleProvider);
  }

  ref.read(hapticFeedbackProvider.notifier).selectionClick();
  router.setActiveIndex(index);
  ref.read(tabProvider.notifier).state = TabEnum.values[index];
}

class _BottomNavigationBar extends ConsumerStatefulWidget {
  const _BottomNavigationBar({required this.tabsRouter, required this.destinations});

  final List<NavigationDestination> destinations;
  final TabsRouter tabsRouter;

  @override
  ConsumerState createState() => _BottomNavigationBarState();
}

class _BottomNavigationBarState extends ConsumerState<_BottomNavigationBar> {
  bool hideNavigationBar = false;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _eventSubscription = EventStream.shared.listen<MultiSelectToggleEvent>(_onEvent);
  }

  void _onEvent(MultiSelectToggleEvent event) {
    setState(() {
      hideNavigationBar = event.isEnabled;
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isScreenLandscape = context.orientation == Orientation.landscape;

    if (isScreenLandscape || hideNavigationBar) {
      return const SizedBox.shrink();
    }

    return FloatingGlassBottomNavigationBar(
      destinations: widget.destinations,
      selectedIndex: widget.tabsRouter.activeIndex,
      onDestinationSelected: (index) => _onNavigationSelected(widget.tabsRouter, index, ref),
    );
  }
}
