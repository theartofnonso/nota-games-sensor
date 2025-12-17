import 'package:flutter/material.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';

/// Primary shareable asset: vertical card with transparent background.
class ShareableRoutineVerticalCard extends StatelessWidget {
  const ShareableRoutineVerticalCard({
    super.key,
    required this.summary,
    this.size,
  });

  final ShareableRoutineSummary summary;
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(routineName: summary.routineName),
          const SizedBox(height: 16),
          _MetricGroup(
            summary: summary,
            layout: Axis.vertical,
            alignment: CrossAxisAlignment.start,
          ),
        ],
      ),
    );

    if (size == null) return content;

    return SizedBox(
      width: size!.width,
      height: size!.height,
      child: content,
    );
  }
}

/// Alternate shareable asset: duration on its own line beneath metrics.
class ShareableRoutineVerticalCardDurationSplit extends StatelessWidget {
  const ShareableRoutineVerticalCardDurationSplit({
    super.key,
    required this.summary,
    this.size,
  });

  final ShareableRoutineSummary summary;
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(routineName: summary.routineName),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              _Metric(label: "Exercises", value: "${summary.exerciseCount}"),
              _Metric(label: "Sets", value: "${summary.setCount}"),
              if (summary.personalBests.isNotEmpty)
                _Metric(
                  label: "PBs",
                  value: "${summary.personalBests.length}",
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Metric(label: "Duration", value: summary.durationLabel),
        ],
      ),
    );

    if (size == null) return content;

    return SizedBox(
      width: size!.width,
      height: size!.height,
      child: content,
    );
  }
}

/// Centered variant: duration on its own line, all content centered.
class ShareableRoutineVerticalCardDurationSplitCentered
    extends StatelessWidget {
  const ShareableRoutineVerticalCardDurationSplitCentered({
    super.key,
    required this.summary,
    this.size,
  });

  final ShareableRoutineSummary summary;
  final Size? size;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Colors.transparent,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Header(
            routineName: summary.routineName,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _Metric(
            label: "Duration",
            value: summary.durationLabel,
            textAlign: TextAlign.center,
            crossAxis: CrossAxisAlignment.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              _Metric(label: "Exercises", value: "${summary.exerciseCount}"),
              _Metric(label: "Sets", value: "${summary.setCount}"),
              if (summary.personalBests.isNotEmpty)
                _Metric(
                  label: "PBs",
                  value: "${summary.personalBests.length}",
                ),
            ],
          ),
        ],
      ),
    );

    if (size == null) return content;

    return SizedBox(
      width: size!.width,
      height: size!.height,
      child: content,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.routineName, this.textAlign});

  final String routineName;
  final TextAlign? textAlign;

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
          textAlign: textAlign,
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
      if (summary.personalBests.isNotEmpty)
        _Metric(label: "PBs", value: "${summary.personalBests.length}"),
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
  const _Metric({
    required this.label,
    required this.value,
    this.textAlign,
    this.crossAxis,
  });

  final String label;
  final String value;
  final TextAlign? textAlign;
  final CrossAxisAlignment? crossAxis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxis ?? CrossAxisAlignment.start,
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
          textAlign: textAlign,
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
