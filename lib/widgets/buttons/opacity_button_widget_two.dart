import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OpacityButtonWidgetTwo extends StatelessWidget {
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final String label;
  final Color? buttonColor;
  final TextStyle? textStyle;
  final VisualDensity? visualDensity;

  const OpacityButtonWidgetTwo({
    super.key,
    this.onPressed,
    this.onLongPress,
    required this.label,
    this.buttonColor,
    this.textStyle,
    this.visualDensity = VisualDensity.compact,
  });

  Color? _themeForegroundColor({required bool isDarkMode}) {
    return isDarkMode ? buttonColor : Colors.black;
  }

  Color? _themeBackgroundColor({required bool isDarkMode}) {
    return isDarkMode ? buttonColor?.withValues(alpha: 0.15) : buttonColor;
  }

  Color _defaultBackgroundColor({required bool isDarkMode}) {
    return isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return TextButton(
        style: ButtonStyle(
          visualDensity: visualDensity,
          backgroundColor: WidgetStateProperty.all(
              _themeBackgroundColor(isDarkMode: isDarkMode) ??
                  _defaultBackgroundColor(isDarkMode: isDarkMode)),
          shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              return Colors.black
                  .withValues(alpha: 0.3); // Defer to the widget's default.
            },
          ),
        ),
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label,
                  textAlign: TextAlign.start,
                  style: textStyle ??
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _themeForegroundColor(isDarkMode: isDarkMode),
                          fontWeight: FontWeight.bold)),
              FaIcon(FontAwesomeIcons.arrowRight,
                  color: buttonColor ?? Colors.white)
            ],
          ),
        ));
  }
}
