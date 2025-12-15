import 'package:flutter/material.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';

/// Primary shareable asset: vertical card with transparent background.
class ShareableRoutineVerticalCard extends StatelessWidget {
  const ShareableRoutineVerticalCard({
    super.key,
    required this.summary,
    this.size = const Size(1080, 1080),
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
            const Spacer(),
            _Header(routineName: summary.routineName),
            const SizedBox(height: 16),
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
        Text(
          routineName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Grift',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -1.2,
            decoration: TextDecoration.none,
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
  });

  final ShareableRoutineSummary summary;
  final Axis layout;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final children = [
      _Metric(label: "Exercises", value: "${summary.exerciseCount}"),
      _Metric(label: "Sets", value: "${summary.setCount}"),
      _Metric(label: "Duration", value: summary.durationLabel),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: alignment,
      spacing: 16,
      children: children,
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
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 1.6,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Grift',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.6,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
