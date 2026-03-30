import 'package:flutter/material.dart';

import '../../dtos/coach_dto.dart';
import '../../utils/general_utils.dart';
import '../coach/coach_paywall_hero_tag.dart';
import '../coach/coach_profile_chips.dart';

/// Large coach visual for the subscription paywall: full-bleed photo, bottom
/// scrim tinted with [paywallCoachHeroScrimGradient] to match the paywall
/// [themeGradient]; plain bio; frosted chips.
class PaywallCoachShowcaseCard extends StatelessWidget {
  const PaywallCoachShowcaseCard({
    super.key,
    required this.coach,
    this.height = 520,
    this.useHero = true,
  });

  final CoachDto? coach;
  final double height;

  /// When false, skips [Hero] (e.g. coach discovery → profile) to avoid tag collisions.
  final bool useHero;

  @override
  Widget build(BuildContext context) {
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: useHero
                ? Hero(
                    tag: coachPaywallHeroTag(coach),
                    child: Material(
                      type: MaterialType.transparency,
                      child: _CoachBackdropImage(coach: coach),
                    ),
                  )
                : Material(
                    type: MaterialType.transparency,
                    child: _CoachBackdropImage(coach: coach),
                  ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: paywallCoachHeroScrimGradient(context: context),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(coach),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (coach?.experienceDisplayLine != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          coach!.experienceDisplayLine!,
                          style: bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (coach?.description?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        CoachProfileDescriptionPanel(
                          text: coach!.description!.trim(),
                          maxLines: 8,
                          style: bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.94),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (CoachProfileChips.hasChipsFor(coach) && coach != null) ...[
                  if (coach?.description?.trim().isNotEmpty == true)
                    const SizedBox(height: 12),
                  CoachProfileChips(coach: coach!),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _displayName(CoachDto? c) {
    final n = c?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Your coach';
  }

}

class _CoachBackdropImage extends StatelessWidget {
  const _CoachBackdropImage({required this.coach});

  final CoachDto? coach;

  @override
  Widget build(BuildContext context) {
    final url = coach?.profileImageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _blankBackdrop(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: Theme.of(context).brightness == Brightness.dark
                ? themeGradient(context: context)
                    .colors
                    .last
                    .withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.9),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        },
      );
    }
    return _blankBackdrop();
  }

  Widget _blankBackdrop() {
    return const ColoredBox(color: Colors.transparent);
  }
}
