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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _CoachChipScrollRow extends StatelessWidget {
  const _CoachChipScrollRow({
    required this.items,
    required this.chipTextStyle,
    required this.paddingStart,
    required this.paddingEnd,
  });

  final List<String> items;
  final TextStyle chipTextStyle;
  final double paddingStart;
  final double paddingEnd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(paddingStart, 0, paddingEnd, 0),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          return Center(
            child: _CoachFrostChip(
              label: items[i],
              textStyle: chipTextStyle,
            ),
          );
        },
      ),
    );
  }
}

/// Specialties and hobbies as separate full-width horizontal chip rows
/// (no section labels). Order: specialties → hobbies & interests (last).
class CoachProfileChips extends StatelessWidget {
  const CoachProfileChips({
    super.key,
    required this.coach,
    this.horizontalContentPadding = 20,
    this.horizontalContentPaddingStart,
    this.horizontalContentPaddingEnd,
  });

  final CoachDto coach;

  /// Default horizontal inset for chip [ListView] when [horizontalContentPaddingStart]
  /// / [horizontalContentPaddingEnd] are omitted (paywall uses 20).
  final double horizontalContentPadding;

  /// Optional leading inset for horizontal chip scroll; defaults to [horizontalContentPadding].
  final double? horizontalContentPaddingStart;

  /// Optional trailing inset for horizontal chip scroll; defaults to [horizontalContentPadding].
  final double? horizontalContentPaddingEnd;

  static bool hasChipsFor(CoachDto? coach) {
    if (coach == null) return false;
    return splitCoachProfileListField(coach.specialties).isNotEmpty ||
        splitCoachProfileListField(coach.interestsHobbies).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final spec = splitCoachProfileListField(coach.specialties);
    final hobby = splitCoachProfileListField(coach.interestsHobbies);
    if (spec.isEmpty && hobby.isEmpty) {
      return const SizedBox.shrink();
    }

    final chipTextStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.15,
              fontWeight: FontWeight.w300,
              fontSize: 12.5,
            ) ??
            TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.15,
              fontWeight: FontWeight.w300,
              fontSize: 12.5,
            );

    final padStart =
        horizontalContentPaddingStart ?? horizontalContentPadding;
    final padEnd = horizontalContentPaddingEnd ?? horizontalContentPadding;

    final planes = <Widget>[];
    if (spec.isNotEmpty) {
      planes.add(
        _CoachChipScrollRow(
          items: spec,
          chipTextStyle: chipTextStyle,
          paddingStart: padStart,
          paddingEnd: padEnd,
        ),
      );
    }
    if (hobby.isNotEmpty) {
      if (planes.isNotEmpty) planes.add(const SizedBox(height: 4));
      planes.add(
        _CoachChipScrollRow(
          items: hobby,
          chipTextStyle: chipTextStyle,
          paddingStart: padStart,
          paddingEnd: padEnd,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: planes,
    );
  }
}
