import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomIcon extends StatelessWidget {

  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final IconData icon;
  final double? iconSize;

  const CustomIcon(this.icon, {super.key, this.width, this.height, this.padding, required this.color, this.iconSize});

  @override
  Widget build(BuildContext context) {

    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
      width: width ?? 30,
      height: height ?? 30,
      padding: padding ?? const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDarkMode ? color.withValues(alpha: 0.1) : color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: FaIcon(
          icon,
          color: isDarkMode ? color : Colors.black,
          size: iconSize ?? 14,
        ),
      ),
    );
  }
}
