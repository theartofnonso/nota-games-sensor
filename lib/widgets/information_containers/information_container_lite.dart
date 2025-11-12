import 'package:flutter/material.dart';


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
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = useOpacity && systemBrightness == Brightness.dark;

    final trailingWidget = trailing;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: isDarkMode ? color?.withValues(alpha: 0.1) : color, borderRadius: BorderRadius.circular(5)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Row(
          spacing: 20,
          children: [
            Expanded(
                child: richText ??
                    Text(content,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: isDarkMode ? color : Colors.black,
                            fontWeight: FontWeight.w600))),
            if(trailingWidget != null) trailingWidget
          ],
        ),
      ),
    );
  }
}
