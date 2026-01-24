import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  final int count;
  final double fontSize;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color textColor;

  const UnreadBadge({
    super.key,
    required this.count,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    this.backgroundColor = Colors.amber,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
