import 'package:flutter/material.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';

/// Primary shareable asset: vertical card with transparent background.
class ShareableRoutineVerticalCard extends StatelessWidget {
  const ShareableRoutineVerticalCard({
    super.key,
    required this.summary,
    this.size = const Size(1080, 1350),
  });

  final ShareableRoutineSummary summary;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(routineName: summary.routineName),
            const Spacer(),
            _MetricGroup(
              summary: summary,
              layout: Axis.vertical,
              alignment: CrossAxisAlignment.start,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.routineName});

  final String routineName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: success.withOpacity(0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: success.withOpacity(0.6), width: 1),
          ),
          child: const Text(
            "trackr / session",
            style: TextStyle(
              fontFamily: 'Grift',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Text(
          routineName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Grift',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            height: 1.0,
            letterSpacing: -1.2,
          ),
        ),
      ],
    );
  }
}

class _MetricGroup extends StatelessWidget {
  const _MetricGroup({
    required this.summary,
    required this.layout,
    required this.alignment,
    this.spaced = false,
  });

  final ShareableRoutineSummary summary;
  final Axis layout;
  final CrossAxisAlignment alignment;
  final bool spaced;

  @override
  Widget build(BuildContext context) {
    final children = [
      _Metric(label: "Exercises", value: "${summary.exerciseCount}"),
      _Metric(label: "Sets", value: "${summary.setCount}"),
      _Metric(label: "Duration", value: summary.durationLabel),
    ];

    // Render exercises + sets on the same horizontal plane, duration below.
    final topRow = Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: spaced ? 24 : 16,
      children: children.take(2).toList(),
    );

    final duration = children.last;

    return Column(
      crossAxisAlignment: alignment,
      spacing: spaced ? 20 : 12,
      children: [
        topRow,
        duration,
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Grift',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textSecondary.withOpacity(0.8),
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Grift',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}
