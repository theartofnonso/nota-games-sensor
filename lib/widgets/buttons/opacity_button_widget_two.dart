import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OpacityButtonWidgetTwo extends StatelessWidget {
  final void Function()? onPressed;
  final void Function()? onLongPress;
  final String label;
  final Color? buttonColor;
  final TextStyle? textStyle;
  final VisualDensity? visualDensity;
  final bool showArrowRight;
  final bool solidBackground;
  final EdgeInsetsGeometry? padding;

  const OpacityButtonWidgetTwo({
    super.key,
    this.onPressed,
    this.onLongPress,
    required this.label,
    this.buttonColor,
    this.textStyle,
    this.visualDensity = VisualDensity.compact,
    this.showArrowRight = true,
    this.solidBackground = false,
    this.padding,
  });

  Color _themeForegroundColor({required bool isDarkMode}) {
    if (solidBackground && buttonColor != null) {
      final brightness = ThemeData.estimateBrightnessForColor(buttonColor!);
      return brightness == Brightness.dark ? Colors.white : Colors.black;
    }
    return isDarkMode ? (buttonColor ?? Colors.white) : Colors.black;
  }

  Color? _themeBackgroundColor({required bool isDarkMode}) {
    if (solidBackground && buttonColor != null) return buttonColor;
    return isDarkMode ? buttonColor?.withValues(alpha: 0.15) : buttonColor;
  }

  Color _defaultBackgroundColor({required bool isDarkMode}) {
    return isDarkMode
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade200;
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
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
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: showArrowRight
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Text(
                  label,
                  textAlign: showArrowRight ? TextAlign.left : TextAlign.center,
                  style: textStyle ??
                      Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                _themeForegroundColor(isDarkMode: isDarkMode),
                            fontWeight: FontWeight.bold,
                          ),
                ),
              ),
              if (showArrowRight)
                FaIcon(
                  FontAwesomeIcons.arrowRight,
                  size: 12,
                  color: _themeForegroundColor(isDarkMode: isDarkMode),
                ),
            ],
          ),
        ));
  }
}
