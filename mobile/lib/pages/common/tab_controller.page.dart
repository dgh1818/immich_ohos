import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/providers/album/album.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/scroll_notifier.provider.dart';
import 'package:immich_mobile/providers/multiselect.provider.dart';
import 'package:immich_mobile/providers/search/search_input_focus.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/providers/asset.provider.dart';
import 'package:immich_mobile/providers/haptic_feedback.provider.dart';
import 'package:immich_mobile/providers/tab.provider.dart';

import 'package:flutter_svg/svg.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;

@RoutePage()
class TabControllerPage extends HookConsumerWidget {
  const TabControllerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRefreshingAssets = ref.watch(assetProvider);
    final isRefreshingRemoteAlbums = ref.watch(isRefreshingRemoteAlbumProvider);
    final isScreenLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final isRailExpanded = useState<bool>(true);
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 400),
    );

    const railWidth = 72.0;

    // 添加切换导航栏状态的函数
    void toggleRail() {
      if (isRailExpanded.value) {
        animationController.forward();
      } else {
        animationController.reverse();
      }
      isRailExpanded.value = !isRailExpanded.value;
    }

    Widget buildIcon({required Widget icon, required bool isProcessing}) {
      if (!isProcessing) return icon;
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -14,
            child: SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.primaryColor,
                ),
              ),
            ),
          ),
        ],
      );
    }

    void onNavigationSelected(TabsRouter router, int index) {
      // On Photos page menu tapped
      if (router.activeIndex == 0 && index == 0) {
        scrollToTopNotifierProvider.scrollToTop();
      }

      // On Search page tapped
      if (router.activeIndex == 1 && index == 1) {
        ref.read(searchInputFocusProvider).requestFocus();
      }

      ref.read(hapticFeedbackProvider.notifier).selectionClick();
      router.setActiveIndex(index);
      ref.read(tabProvider.notifier).state = TabEnum.values[index];
    }

    final navigationDestinations = [
      NavigationDestination(
        label: 'tab_controller_nav_photos'.tr(),
        icon: const Icon(
          Icons.photo_library_outlined,
        ),
        selectedIcon: buildIcon(
          isProcessing: isRefreshingAssets,
          icon: Icon(
            Icons.photo_library,
            color: context.primaryColor,
          ),
        ),
      ),
      NavigationDestination(
        label: 'tab_controller_nav_search'.tr(),
        icon: const Icon(
          Icons.search_rounded,
        ),
        selectedIcon: Icon(
          Icons.search,
          color: context.primaryColor,
        ),
      ),
      NavigationDestination(
        label: 'albums'.tr(),
        icon: const Icon(
          Icons.photo_album_outlined,
        ),
        selectedIcon: buildIcon(
          isProcessing: isRefreshingRemoteAlbums,
          icon: Icon(
            Icons.photo_album_rounded,
            color: context.primaryColor,
          ),
        ),
      ),
      NavigationDestination(
        label: 'library'.tr(),
        icon: const Icon(
          Icons.space_dashboard_outlined,
        ),
        selectedIcon: buildIcon(
          isProcessing: isRefreshingAssets,
          icon: Icon(
            Icons.space_dashboard_rounded,
            color: context.primaryColor,
          ),
        ),
      ),
    ];

    Widget bottomNavigationBar(TabsRouter tabsRouter) {
      return NavigationBar(
        selectedIndex: tabsRouter.activeIndex,
        onDestinationSelected: (index) =>
            onNavigationSelected(tabsRouter, index),
        destinations: navigationDestinations,
      );
    }

    Widget buildLogo() {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: SvgPicture.asset(
          'assets/immich-logo.svg',
          height: 40,
        ),
      );
    }

    Widget navigationRail(TabsRouter tabsRouter) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        left: isRailExpanded.value ? 0 : -72, // 收起时向左移出屏幕
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
                  ),
                )
                .toList(),
            onDestinationSelected: (index) =>
                onNavigationSelected(tabsRouter, index),
            selectedIndex: tabsRouter.activeIndex,
            labelType: NavigationRailLabelType.all,
            groupAlignment: 0.0,
          ),
        ),
      );
    }

    final multiselectEnabled = ref.watch(multiselectProvider);
    return AutoTabsRouter(
      routes: [
        const PhotosRoute(),
        SearchRoute(),
        const AlbumsRoute(),
        const LibraryRoute(),
      ],
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (context, child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        final heroedChild = HeroControllerScope(
          controller: HeroController(),
          child: child,
        );
        return PopScope(
          canPop: tabsRouter.activeIndex == 0,
          onPopInvokedWithResult: (didPop, _) =>
              !didPop ? tabsRouter.setActiveIndex(0) : null,
          child: Scaffold(
            body: isScreenLandscape
                ?
                // Row(
                //     children: [
                //       navigationRail(tabsRouter),
                //       const VerticalDivider(),
                //       Expanded(child: heroedChild),
                Stack(
                    children: [
                      // 左侧导航栏
                      navigationRail(tabsRouter),

                      // —— 2) 内容区 ——
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        // ▷ 收起时 left=0；展开时 left=railWidth
                        left: isRailExpanded.value ? railWidth : 0,
                        top: 0, right: 0, bottom: 0,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: heroedChild,
                        ),
                      ),

                      // Logo按钮（放在Stack顶层）
                      Positioned(
                        top: 30,
                        left: 10,
                        child: GestureDetector(
                          onTap: toggleRail, // 点击切换状态
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
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
                : heroedChild,
            bottomNavigationBar: multiselectEnabled || isScreenLandscape
                ? null
                : bottomNavigationBar(tabsRouter),
          ),
        );
      },
    );
  }
}
