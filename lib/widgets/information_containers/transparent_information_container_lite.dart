import 'package:flutter/material.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class TransparentInformationContainerLite extends StatelessWidget {
  final String content;
  final RichText? richText;
  final void Function()? onTap;
  final bool useOpacity;
  final Widget? trailing;

  const TransparentInformationContainerLite(
      {super.key,
      required this.content,
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
                (colors?.borderLight ?? Colors.white.withValues(alpha: 0.12)),
            width: 1,
          ),
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.grey.shade50,
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 16,
          children: [
            Expanded(
                child: richText ??
                    Text(content,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w500))),
            if (trailingWidget != null) trailingWidget
          ],
        ),
      ),
    );
  }
}
