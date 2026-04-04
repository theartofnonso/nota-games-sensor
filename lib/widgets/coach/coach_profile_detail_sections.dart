import 'package:flutter/material.dart';

import '../../dtos/coach_dto.dart';

/// Surface style for [CoachProfileDetailSections].
enum CoachProfileDetailVariant {
  /// Light text on a dark panel (subscribe card body).
  cardInset,

  /// Theme colors on full-screen paywall or sheet-style inset content.
  sheet,
}

/// Full coach profile copy from [CoachDto] (backed by `coaches` +
/// `coach_profiles`), in labeled sections.
class CoachProfileDetailSections extends StatelessWidget {
  const CoachProfileDetailSections({
    super.key,
    required this.coach,
    this.variant = CoachProfileDetailVariant.sheet,
  });

  final CoachDto? coach;
  final CoachProfileDetailVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInset = variant == CoachProfileDetailVariant.cardInset;
    final titleStyle =
        isInset
            ? theme.textTheme.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            )
            : theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            );
    final bodyStyle =
        isInset
            ? theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
            )
            : theme.textTheme.bodyMedium?.copyWith(height: 1.45);
    final mutedStyle =
        isInset
            ? theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            )
            : theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.4,
            );

    if (coach == null) {
      return Text(
        'We couldn’t load your coach’s profile from the server. '
        'You’re still assigned to the trainer you chose on the website — '
        'you can subscribe below. If this persists, check your connection '
        'and try again.',
        style: mutedStyle,
      );
    }

    final c = coach!;
    final hasAbout = c.description?.trim().isNotEmpty == true;
    final hasExp = c.experienceDisplayLine != null;
    final hasSpec = c.specialties?.trim().isNotEmpty == true;
    final hasHobbies = c.interestsHobbies?.trim().isNotEmpty == true;

    if (!hasAbout && !hasExp && !hasSpec && !hasHobbies) {
      final name = c.name.trim().isEmpty ? 'Your coach' : c.name.trim();
      return Text(
        '$name is your assigned trainer. Their full profile will appear here '
        'once it’s completed. You can still subscribe below for app access.',
        style: bodyStyle,
      );
    }

    final chips = _specialtyChips(c.specialties);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          title: 'About',
          body: c.description?.trim(),
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
        ),
        _section(
          title: 'Experience',
          body: c.experienceDisplayLine,
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
        ),
        if (c.specialties != null && c.specialties!.trim().isNotEmpty) ...[
          Text('Specialties', style: titleStyle),
          const SizedBox(height: 8),
          if (chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  chips
                      .map(
                        (s) => Chip(
                          label: Text(
                            s,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  isInset
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : null,
                            ),
                          ),
                          backgroundColor:
                              isInset
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.6),
                          side: BorderSide(
                            color:
                                isInset
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : theme.colorScheme.outline.withValues(
                                      alpha: 0.25,
                                    ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
            )
          else
            Text(c.specialties!.trim(), style: bodyStyle),
          const SizedBox(height: 16),
        ],
        _section(
          title: 'Interests & hobbies',
          body: c.interestsHobbies?.trim(),
          titleStyle: titleStyle,
          bodyStyle: bodyStyle,
        ),
      ],
    );
  }

  static List<String> _specialtyChips(String? raw) {
    if (raw == null) return [];
    final parts =
        raw
            .split(RegExp(r'[,;•\n]'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    return parts.length >= 2 ? parts : [];
  }

  static Widget _section({
    required String title,
    required String? body,
    required TextStyle? titleStyle,
    required TextStyle? bodyStyle,
  }) {
    final t = body?.trim();
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 6),
          Text(t, style: bodyStyle),
        ],
      ),
    );
  }
}
