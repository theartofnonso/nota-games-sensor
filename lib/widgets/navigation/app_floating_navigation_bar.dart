import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trainware/colors.dart';

/// One slot in [AppFloatingNavigationBar] (custom layout, not [NavigationBar]).
class AppFloatingNavItem {
  /// Used for accessibility only (no on-screen label).
  final String label;
  final Widget icon;
  final Widget selectedIcon;

  const AppFloatingNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

/// Translucent frosted floating bar with fully rounded (stadium) ends.
class AppFloatingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppFloatingNavItem> items;

  const AppFloatingNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxIndex = items.length - 1;
    final idx = currentIndex.clamp(0, maxIndex);

    final gradientColors = isDark
        ? [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.06),
          ]
        : [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.38),
          ];

    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
      shape: StadiumBorder(
        side: BorderSide(color: outlineColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (i) {
                final selected = i == idx;
                final item = items[i];
                return Expanded(
                  child: _FloatingNavSlot(
                    semanticLabel: item.label,
                    selected: selected,
                    selectorColor: vibrantGreen,
                    isDark: isDark,
                    onTap: () => onDestinationSelected(i),
                    child: selected ? item.selectedIcon : item.icon,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavSlot extends StatelessWidget {
  final String semanticLabel;
  final bool selected;
  /// Brand vibrant green for selected pill + ripple (not theme vibrantAccent).
  final Color selectorColor;
  final bool isDark;
  final VoidCallback onTap;
  final Widget child;

  const _FloatingNavSlot({
    required this.semanticLabel,
    required this.selected,
    required this.selectorColor,
    required this.isDark,
    required this.onTap,
    required this.child,
  });

  void _handleTap() {
    // Intentionally strong feedback for primary navigation taps.
    HapticFeedback.heavyImpact();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          customBorder: const CircleBorder(),
          splashColor: selectorColor.withValues(alpha: 0.22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: _kNavSelectedIndicatorSize,
                height: _kNavSelectedIndicatorSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? selectorColor.withValues(alpha: isDark ? 0.32 : 0.22)
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: IconTheme.merge(
                  data: IconThemeData(
                    size: 24,
                    color: selected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white60 : Colors.black45),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom inset for content when using [AppFloatingNavigationBar] in a [Stack].
const kAppFloatingNavBarReserveHeight = 88.0;

/// Diameter of the circular selected-state highlight behind each nav icon.
const double _kNavSelectedIndicatorSize = 44.0;
