import 'package:flutter/material.dart';


class LabelDivider extends StatelessWidget {
  final String label;
  final double fontSize;
  final bool shouldCapitalise;
  final Color labelColor;
  final Color dividerColor;
  final bool leftToRight;
  const LabelDivider({super.key, required this.label, this.fontSize = 12, this.shouldCapitalise = false, required this.labelColor, required this.dividerColor, this.leftToRight = true});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      leftToRight ? Text(
        shouldCapitalise ? label.toUpperCase() : label,
        style: TextStyle(color: labelColor, fontWeight: FontWeight.w700, fontSize: fontSize),
      ) : SizedBox.shrink(),
      Spacer(),
      !leftToRight ? Text(
        shouldCapitalise ? label.toUpperCase() : label,
        style: TextStyle(color: labelColor, fontWeight: FontWeight.w700, fontSize: fontSize),
      ) : SizedBox.shrink()
    ]);
  }
}
