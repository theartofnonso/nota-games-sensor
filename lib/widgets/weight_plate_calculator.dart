import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
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

/// Bar weights in kg from 1 to 25 (no bar weighs more); 0.5 kg increments.
final List<double> _barWeightOptions = List.generate(49, (i) => 1.0 + i * 0.5);

class _WeightCalculatorState extends State<WeightPlateCalculator> {
  // Available plate types (which plates the user has access to)
  final List<_PlatesEnum> _availablePlates = [];
  double _selectedBarWeight = 20; // Default to 20 kg (Olympic bar)
  late final FixedExtentScrollController _barPickerController;

  // Calculated plate quantities needed to reach target (computed on demand)
  Map<_PlatesEnum, int> get _calculatedPlateQuantities {
    return _calculateOptimalCombination();
  }

  static const double _barPickerItemExtent = 36;

  @override
  void initState() {
    super.initState();
    final initialIndex = ((_selectedBarWeight - 1) / 0.5)
        .round()
        .clamp(0, _barWeightOptions.length - 1);
    _barPickerController =
        FixedExtentScrollController(initialItem: initialIndex);
    _barPickerController.addListener(_syncBarWeightFromScroll);
  }

  void _syncBarWeightFromScroll() {
    if (!_barPickerController.hasClients) return;
    final index = (_barPickerController.offset / _barPickerItemExtent)
        .round()
        .clamp(0, _barWeightOptions.length - 1);
    final newWeight = _barWeightOptions[index];
    if (_selectedBarWeight != newWeight) {
      setState(() => _selectedBarWeight = newWeight);
    }
  }

  @override
  void dispose() {
    _barPickerController.removeListener(_syncBarWeightFromScroll);
    _barPickerController.dispose();
    super.dispose();
  }

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
                    border: _isPlateAvailable(plate: plate)
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

    // Calculate actual weight from calculated plate quantities and bar
    final actualWeight = _calculatedPlateQuantities.entries.fold(
                0.0, (sum, entry) => sum + (entry.key.weight * entry.value)) *
            2 +
        _selectedBarWeight;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: _buildWeightBreakdown(actualWeight),
              ),
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
            SizedBox(
              height: 120,
              child: CupertinoTheme(
                data: CupertinoTheme.of(context).copyWith(
                  textTheme: CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 20,
                    ),
                  ),
                ),
                child: CupertinoPicker(
                  selectionOverlay: null,
                  itemExtent: _barPickerItemExtent,
                  scrollController: _barPickerController,
                  onSelectedItemChanged: (index) {
                    final newWeight = _barWeightOptions[index];
                    if (_selectedBarWeight != newWeight) {
                      setState(() => _selectedBarWeight = newWeight);
                    }
                  },
                  children: _barWeightOptions.map((w) {
                    final displayValue = weightWithConversion(value: w);
                    return Center(
                      child: Text(
                        displayValue.toStringAsFixed(
                            displayValue == displayValue.roundToDouble()
                                ? 0
                                : 1),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightBreakdown(double totalWeight) {
    final theme = Theme.of(context);
    final greyStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.grey);
    final boldStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final unit = weightUnit();

    // Get plates with quantities, sorted by weight descending
    final platesWithQuantities = _calculatedPlateQuantities.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.key.weight.compareTo(a.key.weight));

    // Weight from plates on one side
    final platesPerSide = platesWithQuantities.fold<double>(
      0,
      (sum, e) => sum + (e.key.weight * e.value),
    );
    final platesBothSides = platesPerSide * 2;
    final metTarget = totalWeight == widget.target;
    final shortfall = (widget.target - totalWeight).clamp(0.0, double.infinity);
    final overshoot = (totalWeight - widget.target).clamp(0.0, double.infinity);

    // Build "per side" description: e.g. "2×25 + 1×10"
    String perSideDesc;
    if (platesWithQuantities.isEmpty) {
      perSideDesc = '0';
    } else {
      perSideDesc = platesWithQuantities.map((e) {
        final w = weightWithConversion(value: e.key.weight);
        final wStr = w == w.roundToDouble()
            ? w.toInt().toString()
            : w.toStringAsFixed(1);
        return e.value > 1 ? '${e.value}×$wStr' : wStr;
      }).join(' + ');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line 1: Plates per side
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(text: 'Plates per side: ', style: greyStyle),
              TextSpan(text: '$perSideDesc $unit', style: boldStyle),
              TextSpan(text: ' = ', style: greyStyle),
              TextSpan(
                text: '${weightWithConversion(value: platesPerSide)} $unit',
                style: boldStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Line 2: Both sides
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(text: 'Both sides: ', style: greyStyle),
              TextSpan(
                text:
                    '${weightWithConversion(value: platesPerSide)} × 2 = ${weightWithConversion(value: platesBothSides)} $unit',
                style: boldStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Line 3: + Bar
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(text: '+ Bar: ', style: greyStyle),
              TextSpan(
                text:
                    '${weightWithConversion(value: _selectedBarWeight)} $unit',
                style: boldStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Line 4: Total
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium,
            children: [
              TextSpan(text: 'Total: ', style: greyStyle),
              TextSpan(
                text: '${weightWithConversion(value: totalWeight)} $unit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: metTarget
                      ? vibrantGreen
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        if (!metTarget) ...[
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: greyStyle,
              children: [
                TextSpan(
                  text:
                      'Target: ${weightWithConversion(value: widget.target)} $unit. ',
                ),
                TextSpan(
                  text: shortfall > 0
                      ? 'Need ${weightWithConversion(value: shortfall)} more (${weightWithConversion(value: shortfall / 2)} per side).'
                      : overshoot > 0
                          ? 'Over by ${weightWithConversion(value: overshoot)}. Use fewer or different plates.'
                          : 'Add plates above to reach target.',
                  style: greyStyle?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _onSelectPlate({required _PlatesEnum newPlate}) {
    setState(() {
      final isAvailable =
          _availablePlates.any((plate) => plate.weight == newPlate.weight);
      if (isAvailable) {
        _availablePlates
            .removeWhere((plate) => plate.weight == newPlate.weight);
      } else {
        _availablePlates.add(newPlate);
      }
    });
  }

  bool _isPlateAvailable({required _PlatesEnum plate}) =>
      _availablePlates.any((p) => p.weight == plate.weight);

  /// Calculates the optimal combination of available plates to reach the target weight
  Map<_PlatesEnum, int> _calculateOptimalCombination() {
    final quantities = <_PlatesEnum, int>{};

    if (_availablePlates.isEmpty) {
      return quantities;
    }

    // Calculate weight needed from plates (on one side)
    // Total weight = (plates on one side × 2) + bar weight
    // So: plates on one side = (target - bar weight) / 2
    final barWeight = _selectedBarWeight;
    final targetPlateWeight = (widget.target - barWeight) / 2;

    if (targetPlateWeight <= 0) {
      // Target is less than or equal to bar weight, no plates needed
      return quantities;
    }

    // Sort available plates by weight descending (greedy approach)
    final sortedAvailablePlates = List<_PlatesEnum>.from(_availablePlates)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    double remainingWeight = targetPlateWeight;

    // Greedy algorithm: use largest plates first
    for (final plate in sortedAvailablePlates) {
      if (remainingWeight <= 0) break;

      final plateWeight = plate.weight;
      if (plateWeight <= remainingWeight) {
        final count = (remainingWeight / plateWeight).floor();
        if (count > 0) {
          quantities[plate] = count;
          remainingWeight -= plateWeight * count;
        }
      }
    }

    return quantities;
  }
}

class WeightPlateIcon extends StatelessWidget {
  const WeightPlateIcon({
    super.key,
    this.size = 160,
    required this.weightLabel,
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
}
