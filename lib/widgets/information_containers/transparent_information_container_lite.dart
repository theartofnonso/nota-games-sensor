import 'package:flutter/material.dart';


class TransparentInformationContainerLite extends StatelessWidget {
  final String content;
  final RichText? richText;
  final void Function()? onTap;
  final bool useOpacity;
  final Widget? trailing;

  const TransparentInformationContainerLite(
      {super.key, required this.content, this.richText, this.onTap, this.useOpacity = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = useOpacity && systemBrightness == Brightness.dark;

    final trailingWidget = trailing;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: isDarkMode ? Colors.white70.withValues(alpha: 0.1) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 20,
          children: [
            Expanded(
                child: richText ??
                    Text(content,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w400))),
            if (trailingWidget != null) trailingWidget
          ],
        ),
      ),
    );
  }
}
