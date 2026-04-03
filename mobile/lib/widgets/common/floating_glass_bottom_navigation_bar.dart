import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class FloatingGlassBottomNavigationBar extends StatelessWidget {
  const FloatingGlassBottomNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final systemBottomInset = MediaQuery.paddingOf(context).bottom;
    final barWidth = math.min(288.0, math.max(244.0, screenWidth - 112));
    final bottomOffset = 8.0 + math.min(systemBottomInset, 10.0);
    const borderRadius = BorderRadius.all(Radius.circular(24));

    final glassColor = Color.lerp(
      colorScheme.surface.withValues(alpha: isDark ? 0.42 : 0.26),
      Colors.black.withValues(alpha: isDark ? 0.34 : 0.16),
      isDark ? 0.55 : 0.28,
    )!;
    final borderColor = Colors.white.withValues(alpha: isDark ? 0.14 : 0.20);
    final edgeGlowColor = Colors.white.withValues(alpha: isDark ? 0.06 : 0.10);
    final inactiveColor = Colors.white.withValues(alpha: 0.84);

    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomOffset),
        child: SizedBox(
          width: barWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(color: edgeGlowColor, blurRadius: 14, spreadRadius: 0.2),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(color: borderColor, width: 1.0),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.15 : 0.18),
                        Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                        glassColor,
                      ],
                      stops: const [0.0, 0.24, 1.0],
                    ),
                  ),
                  child: SizedBox(
                    height: 60,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 0,
                          height: 18,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: isDark ? 0.03 : 0.05),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (int index = 0; index < destinations.length; index++)
                              Expanded(
                                child: _DestinationButton(
                                  destination: destinations[index],
                                  isSelected: index == selectedIndex,
                                  activeColor: colorScheme.primary,
                                  inactiveColor: inactiveColor,
                                  onTap: destinations[index].enabled ? () => onDestinationSelected(index) : null,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    this.onTap,
  });

  final NavigationDestination destination;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isEnabled = onTap != null;
    final foregroundColor = isEnabled
        ? (isSelected ? activeColor : inactiveColor)
        : inactiveColor.withValues(alpha: 0.45);
    final icon = isSelected ? (destination.selectedIcon ?? destination.icon) : destination.icon;

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: const BoxDecoration(color: Colors.transparent),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Opacity(
                opacity: isEnabled ? 1 : 0.46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.0 : 0.96,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: IconTheme(
                        data: IconThemeData(color: foregroundColor, size: 22),
                        child: icon,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: (textTheme.labelSmall ?? const TextStyle(fontSize: 10)).copyWith(
                          color: foregroundColor,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
