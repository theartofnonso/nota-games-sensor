import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Client-only subscription entry point shown near logout/settings actions.
class SubscriptionSection extends StatelessWidget {
  final VoidCallback onTap;

  const SubscriptionSection({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceOpacity = theme.brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.08)
        : onSurface.withValues(alpha: 0.06);
    final contentColor = onSurface.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: surfaceOpacity,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.crown,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manage subscription',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
