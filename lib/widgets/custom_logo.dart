import 'package:flutter/material.dart';

/// Custom logo component with concentric circles
/// - Innermost: solid black circle
/// - Middle ring: thick white ring
/// - Outermost ring: thick gray ring
class CustomLogo extends StatelessWidget {
  final double size;
  final Color? innerColor;
  final Color? middleColor;
  final Color? outerColor;

  const CustomLogo({
    super.key,
    this.size = 40,
    this.innerColor,
    this.middleColor,
    this.outerColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    // Use provided colors or defaults based on theme
    final inner = innerColor ?? (isDarkMode ? Colors.black : Colors.black);
    final middle = middleColor ?? Colors.white;
    final outer = outerColor ?? (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade600);

    return CustomPaint(
      size: Size(size, size),
      painter: _LogoPainter(
        innerColor: inner,
        middleColor: middle,
        outerColor: outer,
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color innerColor;
  final Color middleColor;
  final Color outerColor;

  _LogoPainter({
    required this.innerColor,
    required this.middleColor,
    required this.outerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Calculate ring thicknesses (each ring takes about 1/3 of the radius)
    final outerRingThickness = maxRadius * 0.25;
    final middleRingThickness = maxRadius * 0.25;
    final innerRadius = maxRadius - outerRingThickness - middleRingThickness;

    // Draw outermost ring (gray)
    final outerPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, outerPaint);

    // Draw middle ring (white)
    final middlePaint = Paint()
      ..color = middleColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius - outerRingThickness, middlePaint);

    // Draw inner circle (black)
    final innerPaint = Paint()
      ..color = innerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

