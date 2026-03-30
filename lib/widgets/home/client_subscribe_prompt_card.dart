import 'package:flutter/material.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/services/assigned_coach_service.dart';
import 'package:trainware/widgets/coach/coach_paywall_hero_tag.dart';
import 'package:trainware/widgets/coach/coach_profile_chips.dart';

/// Full-bleed coach photo with a **whole-card** gradient overlay: transparent
/// over the upper ~⅔, ramping to solid black at the bottom; copy sits on the black.
class ClientSubscribePromptCard extends StatelessWidget {
  const ClientSubscribePromptCard({
    super.key,
    required this.onSubscribe,
  });

  final void Function(CoachDto? assignedCoach) onSubscribe;

  static const double _cardHeight = 540;

  /// Top ~⅔ effectively clear; bottom third transitions into solid black.
  static const LinearGradient _fullCardScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x00000000),
      Color(0xCC000000),
      Color(0xFF000000),
    ],
    stops: [0.0, 0.62, 0.78, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;

    return ListenableBuilder(
      listenable: AssignedCoachService.instance.revision,
      builder: (context, _) {
        final coach = AssignedCoachService.instance.profile;
        final coachForChips =
            coach != null && CoachProfileChips.hasChipsFor(coach)
                ? coach
                : null;

        return Semantics(
          button: true,
          label: 'Subscription and coach',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSubscribe(coach),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: _cardHeight,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: Hero(
                          tag: coachPaywallHeroTag(coach),
                          child: Material(
                            type: MaterialType.transparency,
                            child: _CoachCardImage(coach: coach),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: _fullCardScrim,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _coachTitle(coach),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              if (_yearsLine(coach) != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _yearsLine(coach)!,
                                  style: bodyMedium?.copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.88),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                              if (_descriptionText(coach) != null) ...[
                                const SizedBox(height: 6),
                                CoachProfileDescriptionPanel(
                                  text: _descriptionText(coach)!,
                                  maxLines: coachForChips != null ? 2 : 3,
                                  style: bodyMedium?.copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.94),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (coachForChips != null) ...[
                                if (_descriptionText(coach) != null)
                                  const SizedBox(height: 10),
                                CoachProfileChips(coach: coachForChips),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _coachTitle(CoachDto? coach) {
    final n = coach?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Your coach';
  }

  static String? _yearsLine(CoachDto? coach) => coach?.experienceDisplayLine;

  static String? _descriptionText(CoachDto? coach) {
    final d = coach?.description?.trim();
    if (d == null || d.isEmpty) return null;
    return d;
  }
}

class _CoachCardImage extends StatelessWidget {
  const _CoachCardImage({required this.coach});

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
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.75),
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
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
    return _fallback();
  }

  Widget _fallback() {
    return Image.asset(
      'images/background.jpg',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
    );
  }
}
