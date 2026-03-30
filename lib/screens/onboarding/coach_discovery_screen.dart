import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/repositories/supabase/supabase_coaches_repository.dart';
import 'package:trainware/screens/onboarding/coach_profile_onboarding_screen.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// Pre-auth grid of coaches (photo + name). Client acquisition flow.
class CoachDiscoveryScreen extends StatefulWidget {
  const CoachDiscoveryScreen({
    super.key,
    required this.onBack,
    this.onAcquisitionComplete,
    this.onNeedSignIn,
    this.coachesFuture,
  });

  final VoidCallback onBack;
  final VoidCallback? onAcquisitionComplete;
  final VoidCallback? onNeedSignIn;

  /// When provided (e.g. started from welcome), reuses an in-flight or completed fetch.
  final Future<List<CoachDto>>? coachesFuture;

  @override
  State<CoachDiscoveryScreen> createState() => _CoachDiscoveryScreenState();
}

class _CoachDiscoveryScreenState extends State<CoachDiscoveryScreen> {
  final _repo = SupabaseCoachesRepository();
  late Future<List<CoachDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.coachesFuture ?? _repo.fetchCoaches();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.solidCircleXmark,
                        size: 28,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      onPressed: widget.onBack,
                    ),
                    Expanded(
                      child: Text(
                        'Discover coaches',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CoachDto>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Could not load coaches.',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              OpacityButtonWidgetTwo(
                                label: 'Try again',
                                onPressed: () {
                                  setState(() {
                                    _future = _repo.fetchCoaches();
                                  });
                                },
                                buttonColor:
                                    Theme.of(context).colors.vibrantAccent,
                                outlineColor:
                                    Theme.of(context).colors.borderLight,
                                showArrowRight: false,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final coaches = snapshot.data ?? [];
                    if (coaches.isEmpty) {
                      return Center(
                        child: Text(
                          'No coaches available yet.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: coaches.length,
                      itemBuilder: (context, index) {
                        final coach = coaches[index];
                        return _CoachGridTile(
                          coach: coach,
                          onTap: () {
                            Navigator.of(context).push(
                              CoachProfileOnboardingScreen.fadeRoute(
                                coach: coach,
                                onSignupSuccess: widget.onAcquisitionComplete,
                                onEmailAlreadyExists: widget.onNeedSignIn,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachGridTile extends StatelessWidget {
  const _CoachGridTile({
    required this.coach,
    required this.onTap,
  });

  final CoachDto coach;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _gridCoachPhoto(coach, context),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: paywallCoachHeroScrimGradient(
                          context: context,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 12,
                  child: Text(
                    coach.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridCoachPhoto(CoachDto coach, BuildContext context) {
    final url = coach.profileImageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, _, _) => _blankCoachPhotoPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.2),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }
    return _blankCoachPhotoPlaceholder();
  }

  Widget _blankCoachPhotoPlaceholder() {
    return const ColoredBox(color: Colors.transparent);
  }
}
