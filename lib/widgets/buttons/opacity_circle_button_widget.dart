import 'package:flutter/material.dart';

class OpacityCircleButtonWidget extends StatelessWidget {
  final void Function()? onPressed;
  final String label;
  final Color? buttonColor;
  final EdgeInsets? padding;
  final VisualDensity? visualDensity;

  const OpacityCircleButtonWidget(
      {super.key,
      this.onPressed,
      required this.label,
      this.buttonColor,
      this.padding,
      this.visualDensity = VisualDensity.compact});

  Color? _themeForegroundColor({required bool isDarkMode}) {
    return isDarkMode ? buttonColor : Colors.black;
  }

  Color? _themeBackgroundColor({required bool isDarkMode}) {
    return isDarkMode ? buttonColor?.withValues(alpha:0.15) : buttonColor;
  }

  Color _defaultBackgroundColor({required bool isDarkMode}) {
    return isDarkMode ? Colors.white.withValues(alpha:0.15) : Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _themeBackgroundColor(isDarkMode: isDarkMode) ?? _defaultBackgroundColor(isDarkMode: isDarkMode),
          shape: BoxShape.circle,
        ),
        child: Text(label,
            textAlign: TextAlign.start,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: _themeForegroundColor(isDarkMode: isDarkMode))),
      ),
    );
  }
}
