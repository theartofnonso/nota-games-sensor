import 'package:flutter/material.dart';

/// Horizontal rules with centered **or** (spacing from [SizedBox] around this widget).
class OrSeparator extends StatelessWidget {
  const OrSeparator({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(height: 1, thickness: 1, color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            "If you're new, go discover coaches",
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, thickness: 1, color: color)),
      ],
    );
  }
}
