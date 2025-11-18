import 'package:flutter/material.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class InformationContainerLite extends StatelessWidget {
  final String content;
  final Color? color;
  final RichText? richText;
  final void Function()? onTap;
  final bool useOpacity;
  final Widget? trailing;

  const InformationContainerLite(
      {super.key,
      required this.content,
      required this.color,
      this.richText,
      this.onTap,
      this.useOpacity = false,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>();
    final isDarkMode = theme.brightness == Brightness.dark;

    final trailingWidget = trailing;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                (colors?.borderLight ?? Colors.white.withValues(alpha: 0.15)),
            width: 1,
          ),
          color: () {
            if (useOpacity) {
              // Subtle tinted background
              final base =
                  color ?? (colors?.containerBackground ?? Colors.black);
              return isDarkMode
                  ? base.withValues(alpha: 0.08)
                  : base.withValues(alpha: 0.08);
            }
            // Neutral subtle background
            return isDarkMode
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade50;
          }(),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(spacing: 16, children: [
          Expanded(
            child: richText ??
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: useOpacity && color != null
                        ? (isDarkMode ? color : theme.colorScheme.onSurface)
                        : (theme.colorScheme.onSurface),
                    fontWeight: FontWeight.w600,
                  ),
                ),
          ),
          if (trailingWidget != null) trailingWidget
        ]),
      ),
    );
  }
}
