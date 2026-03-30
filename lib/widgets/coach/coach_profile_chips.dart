import 'dart:ui';

import 'package:flutter/material.dart';

import '../../dtos/coach_dto.dart';

/// Splits API list-style strings (comma / semicolon / bullet / newline).
List<String> splitCoachProfileListField(String? raw) {
  if (raw == null) return [];
  return raw
      .split(RegExp(r'[,;•\n]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Short bio on dark coach imagery: plain text (no frosted panel).
class CoachProfileDescriptionPanel extends StatelessWidget {
  const CoachProfileDescriptionPanel({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// One compact frosted chip (blur + translucent fill, no border).
class _CoachFrostChip extends StatelessWidget {
  const _CoachFrostChip({
    required this.label,
    required this.textStyle,
  });

  final String label;
  final TextStyle textStyle;

  static final BorderRadius _pill = BorderRadius.circular(999);
  static const double _blurSigma = 10;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _pill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: _pill,
          ),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}

/// Qualifications, specialties, interests as small frosted chips in one [Wrap].
class CoachProfileChips extends StatelessWidget {
  const CoachProfileChips({super.key, required this.coach});

  final CoachDto coach;

  static bool hasChipsFor(CoachDto? coach) {
    if (coach == null) return false;
    return splitCoachProfileListField(coach.qualifications).isNotEmpty ||
        splitCoachProfileListField(coach.specialties).isNotEmpty ||
        splitCoachProfileListField(coach.interestsHobbies).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final qual = splitCoachProfileListField(coach.qualifications);
    final spec = splitCoachProfileListField(coach.specialties);
    final hobby = splitCoachProfileListField(coach.interestsHobbies);
    if (qual.isEmpty && spec.isEmpty && hobby.isEmpty) {
      return const SizedBox.shrink();
    }

    final chipTextStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.2,
              fontWeight: FontWeight.w300,
              fontSize: 12.5,
            ) ??
            TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.2,
              fontWeight: FontWeight.w300,
              fontSize: 12.5,
            );
    final children = <Widget>[
      for (final item in [...qual, ...spec, ...hobby])
        _CoachFrostChip(label: item, textStyle: chipTextStyle),
    ];

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: children,
    );
  }
}
