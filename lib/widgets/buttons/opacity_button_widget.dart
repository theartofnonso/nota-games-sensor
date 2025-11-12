import 'package:flutter/material.dart';

class OpacityButtonWidget extends StatelessWidget {
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final String label;
  final Color? buttonColor;
  final EdgeInsets? padding;
  final TextStyle? textStyle;
  final VisualDensity? visualDensity;
  final Widget? trailing;

  const OpacityButtonWidget(
      {super.key,
      this.onPressed,
      this.onLongPress,
      required this.label,
      this.buttonColor,
      this.textStyle,
      this.padding = const EdgeInsets.symmetric(horizontal: 10),
      this.visualDensity = VisualDensity.compact,
      this.trailing});

  Color? _themeForegroundColor({required bool isDarkMode}) {
    return isDarkMode ? buttonColor : Colors.black;
  }

  Color? _themeBackgroundColor({required bool isDarkMode}) {
    return isDarkMode ? buttonColor?.withValues(alpha: 0.15) : buttonColor;
  }

  Color _defaultBackgroundColor({required bool isDarkMode}) {
    return isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return TextButton(
        style: ButtonStyle(
          visualDensity: visualDensity,
          backgroundColor: WidgetStateProperty.all(
              _themeBackgroundColor(isDarkMode: isDarkMode) ?? _defaultBackgroundColor(isDarkMode: isDarkMode)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              return Colors.black.withValues(alpha: 0.3); // Defer to the widget's default.
            },
          ),
        ),
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Container(
          padding: padding,
          child: Text(label,
              textAlign: TextAlign.start,
              style: textStyle ??
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _themeForegroundColor(isDarkMode: isDarkMode), fontWeight: FontWeight.bold)),
        ));
  }
}
