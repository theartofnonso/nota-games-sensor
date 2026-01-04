import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../colors.dart';
import '../utils/general_utils.dart';
import 'dividers/label_divider.dart';

class WeightPlateCalculator extends StatefulWidget {
  final double target;

  const WeightPlateCalculator({super.key, required this.target});

  @override
  State<WeightPlateCalculator> createState() => _WeightCalculatorState();
}

class _WeightCalculatorState extends State<WeightPlateCalculator> {
  final List<_PlatesEnum> _selectedPlates = [];
  _BarsEnum _selectedBar = _BarsEnum.twenty;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final plates = _PlatesEnum.values
        .map((plate) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => _onSelectPlate(newPlate: plate),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        const Color(0xFF2A2A2A), // Dark outer
                        const Color(0xFF1A1A1A), // Very dark center
                        const Color(0xFF252525), // Medium dark
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    border: _getPlate(plate: plate) != null
                        ? Border.all(
                            color: vibrantGreen,
                            width: 1,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: WeightPlateIcon(
                      size: 104, // 120 - 16 (8px padding on each side)
                      weightLabel:
                          "${weightWithConversion(value: plate.weight)}",
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
            ))
        .toList();

    final bars = _BarsEnum.values
        .map(
          (bar) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => _onSelectBar(newBar: bar),
              child: Opacity(
                opacity: _selectedBar == bar ? 1.0 : 0.4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Weight label with metallic background
                    Container(
                      width: 100,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFB0B0B0),
                            const Color(0xFF8B8B8B),
                            const Color(0xFF707070),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "${weightWithConversion(value: bar.weight)}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.white,
                                offset: Offset(0.5, 0.5),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Mini bar visualization
                    CustomPaint(
                      size: const Size(15, 40),
                      painter: _BarPainter(),
                    ),
                    // End cap with metallic gradient
                    Container(
                      width: 10,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFB0B0B0),
                            const Color(0xFF8B8B8B),
                            const Color(0xFF707070),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .toList();

    final weightSuggestions =
        _findClosestWeightCombination(targetWeight: widget.target);

    final plateSuggestions =
        weightSuggestions.map((weight) => _PlatesEnum.fromDouble(weight));

    final weightEstimate = (weightSuggestions.sum * 2) + _selectedBar.weight;

    final isExact = weightEstimate == widget.target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
              "${weightWithConversion(value: widget.target)}${weightUnit()}"
                  .toUpperCase(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(
            height: 2,
          ),
          Text("Target Weight".toUpperCase(),
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodyMedium),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: _Bar(
              bar: _selectedBar,
              plates: plateSuggestions
                  .sorted((a, b) => b.weight.compareTo(a.weight)),
            ),
          ),
          if (_selectedPlates.isNotEmpty && !isExact)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                  "Closest estimate is ${weightWithConversion(value: weightEstimate)}${weightUnit()}"
                      .toUpperCase(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelDivider(
                label: "Available Weights (${weightUnit()})".toUpperCase(),
                labelColor: isDarkMode ? Colors.white70 : Colors.black,
                dividerColor: sapphireLighter),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: plates,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LabelDivider(
              label: "Available Bar (${weightUnit()})".toUpperCase(),
              labelColor: isDarkMode ? Colors.white70 : Colors.black,
              dividerColor: sapphireLighter,
              leftToRight: true,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: bars)),
        ],
      ),
    );
  }

  void _onSelectPlate({required _PlatesEnum newPlate}) {
    final oldPlate = _selectedPlates.firstWhereOrNull(
        (previousPlate) => previousPlate.weight == newPlate.weight);
    setState(() {
      if (oldPlate != null) {
        _selectedPlates.remove(oldPlate);
      } else {
        _selectedPlates.add(newPlate);
      }
    });
  }

  void _onSelectBar({required _BarsEnum newBar}) {
    setState(() {
      _selectedBar = newBar;
    });
  }

  _PlatesEnum? _getPlate({required _PlatesEnum plate}) =>
      _selectedPlates.firstWhereOrNull(
          (previousPlate) => previousPlate.weight == plate.weight);

  List<double> _findClosestWeightCombination({required double targetWeight}) {
    // Calculate the weight needed for one side
    double halfTargetWeight = (targetWeight - _selectedBar.weight) / 2;

    // Sort weights in descending order for better efficiency
    _selectedPlates.sort((a, b) => b.weight.compareTo(a.weight));

    List<double> bestCombination = [];
    double bestSum = 0;

    // Recursive function to find the best combination
    void findCombination(
        List<double> currentCombination, double currentSum, int index) {
      if (currentSum > halfTargetWeight) return;

      if (currentSum > bestSum) {
        bestSum = currentSum;
        bestCombination = List.from(currentCombination);
      }

      for (int i = index; i < _selectedPlates.length; i++) {
        currentCombination.add(_selectedPlates[i].weight);
        findCombination(
            currentCombination, currentSum + _selectedPlates[i].weight, i);
        currentCombination.removeLast();
      }
    }

    findCombination([], 0, 0);

    return bestCombination;
  }
}

class _Bar extends StatelessWidget {
  final _BarsEnum bar;
  final List<_PlatesEnum> plates;

  const _Bar({required this.bar, required this.plates});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        SizedBox(width: 16),
        // Weight label with metallic background
        Container(
          width: 100,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFB0B0B0),
                const Color(0xFF8B8B8B),
                const Color(0xFF707070),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Text(
              "${weightWithConversion(value: bar.weight)}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A1A), // Very dark gray for better contrast
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.white,
                    offset: Offset(0.5, 0.5),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Main bar with metallic gradient
        CustomPaint(
          size: const Size(15, 40),
          painter: _BarPainter(),
        ),
        ...plates.map((plate) => _Plate(plate: plate)),
        // End cap with metallic gradient
        Container(
          width: 10,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(5),
              bottomRight: Radius.circular(5),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFB0B0B0),
                const Color(0xFF8B8B8B),
                const Color(0xFF707070),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        SizedBox(width: 16)
      ]),
    );
  }
}

class _BarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Metallic gradient for the bar (darker for contrast)
    final barGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF707070), // Darker silver
        const Color(0xFF5A5A5A), // Dark gray
        const Color(0xFF4A4A4A), // Very dark gray
        const Color(0xFF555555), // Medium dark
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final barPaint = Paint()
      ..shader = barGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Create RRect with completely square edges (no rounded corners)
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.zero,
      bottomLeft: Radius.zero,
      topRight: Radius.zero,
      bottomRight: Radius.zero,
    );

    // Draw main bar body
    canvas.drawRRect(rrect, barPaint);

    // Add border
    final borderPaint = Paint()
      ..color = const Color(0xFF404040)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(rrect, borderPaint);

    // Add highlight on top for 3D effect
    final highlightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.center,
      colors: [
        Colors.white.withValues(alpha: 0.25),
        Colors.white.withValues(alpha: 0.0),
      ],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final highlightRect = Rect.fromLTWH(0, 0, size.width, size.height / 2);
    final highlightRrect = RRect.fromRectAndCorners(
      highlightRect,
      topLeft: Radius.zero,
      bottomLeft: Radius.zero,
      topRight: Radius.zero,
      bottomRight: Radius.zero,
    );
    canvas.drawRRect(highlightRrect, highlightPaint);

    // Add subtle shadow on bottom
    final shadowGradient = LinearGradient(
      begin: Alignment.center,
      end: Alignment.bottomCenter,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.2),
      ],
    );

    final shadowPaint = Paint()
      ..shader = shadowGradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final shadowRect = Rect.fromLTWH(
      0,
      size.height / 2,
      size.width,
      size.height / 2,
    );
    final shadowRrect = RRect.fromRectAndCorners(
      shadowRect,
      topLeft: Radius.zero,
      bottomLeft: Radius.zero,
      topRight: Radius.zero,
      bottomRight: Radius.zero,
    );
    canvas.drawRRect(shadowRrect, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Plate extends StatelessWidget {
  final _PlatesEnum plate;

  const _Plate({
    required this.plate,
  });

  @override
  Widget build(BuildContext context) {
    final weightLabel = "${weightWithConversion(value: plate.weight)}";
    return Container(
      width: 120,
      height: 120,
      margin: EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12), color: sapphireDark),
      child: WeightPlateIcon(
        size: 120,
        weightLabel: weightLabel,
        color: sapphireDark,
        strokeWidth: 3,
      ),
    );
  }
}

class WeightPlateIcon extends StatelessWidget {
  const WeightPlateIcon({
    super.key,
    this.size = 160,
    this.weightLabel = '5 kg',
    this.color = Colors.black,
    this.strokeWidth = 4,
  });

  final double size;
  final String weightLabel;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WeightPlatePainter(
          color: color,
          strokeWidth: strokeWidth,
          label: weightLabel,
        ),
      ),
    );
  }
}

class _WeightPlatePainter extends CustomPainter {
  _WeightPlatePainter({
    required this.color,
    required this.strokeWidth,
    required this.label,
  });

  final Color color;
  final double strokeWidth;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    // Enhanced metallic base gradient with more realistic depth
    final baseGradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.4,
      colors: [
        const Color(0xFF6A6A6A), // Dark shadow at outer edge
        const Color(0xFF7A7A7A), // Medium dark
        const Color(0xFF9A9A9A), // Medium gray
        const Color(0xFFC8C8C8), // Bright highlight
        const Color(0xFFE0E0E0), // Very bright center
        const Color(0xFFB8B8B8), // Medium bright
        const Color(0xFF8B8B8B), // Back to medium dark
      ],
      stops: const [0.0, 0.2, 0.4, 0.55, 0.65, 0.8, 1.0],
    );

    // Main plate fill with gradient
    final plateFill = Paint()
      ..shader = baseGradient.createShader(
        Rect.fromCircle(center: center, radius: r * 0.92),
      )
      ..style = PaintingStyle.fill;

    // Draw main plate background
    canvas.drawCircle(center, r * 0.92, plateFill);

    // Enhanced inner ring area with more depth
    final innerGradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 0.9,
      colors: [
        const Color(0xFF7A7A7A), // Darker outer
        const Color(0xFF9A9A9A), // Medium
        const Color(0xFFB8B8B8), // Lighter
        const Color(0xFFD0D0D0), // Bright highlight
        const Color(0xFFA0A0A0), // Back to medium
      ],
      stops: const [0.0, 0.3, 0.6, 0.75, 1.0],
    );

    final innerFill = Paint()
      ..shader = innerGradient.createShader(
        Rect.fromCircle(center: center, radius: r * 0.78),
      )
      ..style = PaintingStyle.fill;

    // Draw inner ring background
    canvas.drawCircle(center, r * 0.78, innerFill);

    // Enhanced stroke for outer ring with subtle gradient effect
    final stroke = Paint()
      ..color = const Color(0xFF505050) // Darker for more contrast
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Outer ring border
    canvas.drawCircle(center, r * 0.92, stroke);

    // Enhanced inner ring border
    final innerStroke = Paint()
      ..color = const Color(0xFF606060) // Darker for depth
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r * 0.78, innerStroke);

    // Enhanced arc accents with more realistic shading
    final accentPaint = Paint()
      ..color = const Color(0xFF707070) // Slightly lighter for subtle accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round;

    final accentRect = Rect.fromCircle(center: center, radius: r * 0.70);
    // Left accent
    canvas.drawArc(
        accentRect, math.pi * 0.65, math.pi * 0.35, false, accentPaint);
    // Right accent
    canvas.drawArc(
        accentRect, -math.pi * 0.00, math.pi * 0.35, false, accentPaint);

    // Enhanced center hole with more realistic depth
    final holeGradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 0.7,
      colors: [
        const Color(0xFF1A1A1A), // Very dark center (deep shadow)
        const Color(0xFF2A2A2A), // Dark
        const Color(0xFF3A3A3A), // Medium dark
        const Color(0xFF2F2F2F), // Slightly lighter
        const Color(0xFF252525), // Darker edge
      ],
      stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
    );

    final holeFill = Paint()
      ..shader = holeGradient.createShader(
        Rect.fromCircle(center: center, radius: r * 0.30),
      )
      ..style = PaintingStyle.fill;

    // Draw center hole fill
    canvas.drawCircle(center, r * 0.30, holeFill);

    // Center hole border
    final holeStroke = Paint()
      ..color = const Color(0xFF202020)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r * 0.30, holeStroke);

    // Inner ring for hole thickness
    final innerHoleStroke = Paint()
      ..color = const Color(0xFF252525)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.9
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r * 0.22, innerHoleStroke);

    // Enhanced highlight on top for more realistic 3D effect
    final highlightGradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 0.8,
      colors: [
        Colors.white.withValues(alpha: 0.5), // Bright highlight
        Colors.white.withValues(alpha: 0.3), // Medium highlight
        Colors.white.withValues(alpha: 0.1), // Subtle
        Colors.white.withValues(alpha: 0.0), // Fade out
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    );

    // Add secondary highlight for more depth
    final secondaryHighlight = RadialGradient(
      center: Alignment.topRight,
      radius: 0.5,
      colors: [
        Colors.white.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.0),
      ],
    );

    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(
        Rect.fromCircle(center: center, radius: r * 0.92),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, r * 0.92, highlightPaint);

    // Draw secondary highlight
    final secondaryHighlightPaint = Paint()
      ..shader = secondaryHighlight.createShader(
        Rect.fromCircle(center: center, radius: r * 0.92),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, r * 0.92, secondaryHighlightPaint);

    // Add subtle shadow gradient on bottom for more depth
    final shadowGradient = RadialGradient(
      center: Alignment.bottomRight,
      radius: 0.7,
      colors: [
        Colors.black.withValues(alpha: 0.0),
        Colors.black.withValues(alpha: 0.15),
        Colors.black.withValues(alpha: 0.25),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final shadowPaint = Paint()
      ..shader = shadowGradient.createShader(
        Rect.fromCircle(center: center, radius: r * 0.92),
      )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, r * 0.92, shadowPaint);

    // Label (above center circle) - make it more visible with white text
    _drawText(canvas, size, text: label, dy: -r * 0.40, fontSize: r * 0.18);
  }

  void _drawText(
    Canvas canvas,
    Size size, {
    required String text,
    required double dy,
    required double fontSize,
  }) {
    // Use black text with white shadow for better visibility on metallic background
    final textStyle = TextStyle(
      color: Colors.black,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      shadows: [
        Shadow(
          color: Colors.white.withValues(alpha: 0.8),
          offset: const Offset(1, 1),
          blurRadius: 2,
        ),
      ],
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle,
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final offset = Offset(
      (size.width - tp.width) / 2,
      (size.height - tp.height) / 2 + dy - tp.height / 2,
    );

    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _WeightPlatePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.label != label;
  }
}

enum _PlatesEnum {
  twentyFive(weight: 25, height: 120, width: 120),
  twenty(weight: 20, height: 120, width: 120),
  fifteen(weight: 15, height: 120, width: 120),
  ten(weight: 10, height: 120, width: 120),
  five(weight: 5, height: 120, width: 120),
  twoFive(weight: 2.5, height: 120, width: 120),
  oneTwoFive(weight: 1.25, height: 120, width: 120),
  zeroFive(weight: 0.5, height: 120, width: 120);

  final double weight;
  final double height;
  final double width;

  const _PlatesEnum(
      {required this.weight, required this.height, required this.width});

  static _PlatesEnum fromDouble(double weight) {
    return _PlatesEnum.values.firstWhere((value) => value.weight == weight);
  }
}

enum _BarsEnum {
  twenty(weight: 20),
  fifteen(weight: 15),
  ten(weight: 10),
  sevenFive(weight: 7.5),
  five(weight: 5);

  final double weight;

  const _BarsEnum({required this.weight});
}
