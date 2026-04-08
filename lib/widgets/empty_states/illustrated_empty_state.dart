import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Circle icon + title + body — matches nutrition tracker and routines shell
/// empty states (icon in soft circle, titleLarge, muted body).
class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
    this.outerVerticalPadding = 32,
    this.childBelow,
  });

  final IconData icon;
  final String title;
  final String body;
  final EdgeInsetsGeometry padding;

  /// Extra vertical padding around the centered block (e.g. nutrition uses 32).
  final double outerVerticalPadding;
  final Widget? childBelow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: outerVerticalPadding),
      child: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, size: 48, color: muted),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (childBelow != null) ...[
                const SizedBox(height: 28),
                childBelow!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
