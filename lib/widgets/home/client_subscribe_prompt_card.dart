import 'package:flutter/material.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/services/assigned_coach_service.dart';
import 'package:trainware/widgets/coach/coach_paywall_hero_tag.dart';
import 'package:trainware/widgets/coach/coach_profile_chips.dart';
import 'package:trainware/widgets/coach/coach_profile_photo_backplate.dart';

/// Full-bleed coach photo card for clients who need to subscribe. The **whole card**
/// pulses gently (zoom + opacity, like calendar predicted days); tap opens paywall.
/// Footer line nudges users to start training.
class ClientSubscribePromptCard extends StatefulWidget {
  const ClientSubscribePromptCard({
    super.key,
    required this.onSubscribe,
  });

  final void Function(CoachDto? assignedCoach) onSubscribe;

  @override
  State<ClientSubscribePromptCard> createState() =>
      _ClientSubscribePromptCardState();
}

class _ClientSubscribePromptCardState extends State<ClientSubscribePromptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Subtler than calendar cells (0.8–1.0): less “in your face” on a large card.
    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  static String _coachName(CoachDto? coach) {
    final n = coach?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'your coach';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AssignedCoachService.instance.revision,
      builder: (context, _) {
        final coach = AssignedCoachService.instance.profile;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final t = _pulseAnimation.value;
            return Transform.scale(
              scale: t,
              child: Opacity(
                opacity: 0.88 + (t - 0.94) * 0.2,
                child: child,
              ),
            );
          },
          child: Semantics(
            button: true,
            label: 'Subscription and coach, ${_coachName(coach)}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSubscribe(coach),
              child: _ClientSubscribeCoachCardVisual(coach: coach),
            ),
          ),
        );
      },
    );
  }
}

class _ClientSubscribeCoachCardVisual extends StatelessWidget {
  const _ClientSubscribeCoachCardVisual({required this.coach});

  final CoachDto? coach;

  static const double _cardHeight = 540;

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

  static String _coachTitle(CoachDto? c) {
    final n = c?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Your coach';
  }

  static String? _yearsLine(CoachDto? c) => c?.experienceDisplayLine;

  static String? _descriptionText(CoachDto? c) {
    final d = c?.description?.trim();
    if (d == null || d.isEmpty) return null;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    final coachForChips =
        coach != null && CoachProfileChips.hasChipsFor(coach) ? coach : null;

    return DecoratedBox(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        18,
                        20,
                        18,
                        coachForChips != null ? 0 : 18,
                      ),
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
                                color: Colors.white.withValues(alpha: 0.88),
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
                                color: Colors.white.withValues(alpha: 0.94),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (coachForChips != null) ...[
                      if (_descriptionText(coach) != null)
                        const SizedBox(height: 10),
                      CoachProfileChips(
                        coach: coachForChips,
                        horizontalContentPadding: 0,
                        horizontalContentPaddingStart: 18,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                      child: Text(
                        'Time to start training with your coach.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              shadows: const [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachCardImage extends StatelessWidget {
  const _CoachCardImage({required this.coach});

  final CoachDto? coach;

  @override
  Widget build(BuildContext context) {
    final url = coach?.profileImageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CoachProfilePhotoBackplate.behind(
        context,
        Image.network(
          url,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          width: double.infinity,
          errorBuilder: (ctx, _, _) => _noPhotoPlaceholder(ctx),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return ColoredBox(
              color: CoachProfilePhotoBackplate.plateColor(ctx)
                  .withValues(alpha: 0.92),
              child: const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black26,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return _noPhotoPlaceholder(context);
  }

  Widget _noPhotoPlaceholder(BuildContext context) {
    return ColoredBox(color: CoachProfilePhotoBackplate.plateColor(context));
  }
}
