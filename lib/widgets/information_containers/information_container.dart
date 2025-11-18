import 'package:flutter/material.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class InformationContainer extends StatelessWidget {
  final Widget leadingIcon;
  final String title;
  final Widget? richDescription;
  final String description;
  final Widget? trailingIcon;
  final Color color;

  const InformationContainer(
      {super.key,
      required this.leadingIcon,
      required this.title,
      this.trailingIcon,
      this.description = "",
      required this.color,
      this.richDescription});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>();
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (colors?.borderLight ?? Colors.white.withValues(alpha: 0.12)),
          width: 1,
        ),
        color: isDarkMode
            ? color.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.08),
        boxShadow: isDarkMode
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      width: double.infinity,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            letterSpacing: 1,
            color: colors?.textSecondary ??
                (isDarkMode ? Colors.white70 : Colors.black54),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        richDescription ??
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
      ]),
    );
  }
}
