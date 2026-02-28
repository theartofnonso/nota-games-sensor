import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/repositories/supabase/supabase_coaches_repository.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/coach_selection/coach_list_bottom_sheet.dart';
import 'package:trainware/widgets/coach_selection/coach_profile_bottom_sheet.dart';

import '../../app_flavor.dart';
import '../../dtos/coach_dto.dart';

/// Full-screen shown when client has no coach and hasn't completed the
/// coach selection flow. Lists coaches from Supabase; tapping opens profile sheet.
class CoachSelectionScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const CoachSelectionScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<CoachSelectionScreen> createState() => _CoachSelectionScreenState();
}

class _CoachSelectionScreenState extends State<CoachSelectionScreen> {
  final _coachesRepo = SupabaseCoachesRepository();
  List<CoachDto> _coaches = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoaches());
  }

  Future<void> _loadCoaches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final coaches = await _coachesRepo.fetchCoaches();
    if (!mounted) return;
    setState(() {
      _coaches = coaches;
      _isLoading = false;
      _error = coaches.isEmpty ? 'No coaches available' : null;
    });
  }

  Future<void> _handleChooseCoach(BuildContext context, CoachDto coach) async {
    final clientId = Supabase.instance.client.auth.currentUser?.id;
    if (clientId == null) return;

    final ok = await _coachesRepo.assignClientToCoach(
      coachId: coach.id,
      clientId: clientId,
    );

    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      SharedPrefs().coachSelectionComplete = true;
      widget.onComplete();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not assign coach. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isClient) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: themeGradient(context: context),
            ),
            child: const TRKRLoadingScreen(),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    children: [
                      Text(
                        'Choose your coach',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your coach creates personalized workout plans, tracks your progress, '
                        'and gives feedback on your sessions. Tap a coach to learn more.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _coaches.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error ?? 'No coaches available',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.88,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                            ),
                            itemCount: _coaches.length,
                            itemBuilder: (context, index) {
                              final coach = _coaches[index];
                              return CoachGridItem(
                                coach: coach,
                                isDarkMode: isDarkMode,
                                onTap: () => _showCoachProfile(context, coach),
                              );
                            },
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

  void _showCoachProfile(BuildContext context, CoachDto coach) {
    showAppActionBottomSheet<void>(
      context: context,
      isDismissible: true,
      child: CoachProfileBottomSheetContent(
        coach: coach,
        onChooseCoach: () => _handleChooseCoach(context, coach),
      ),
    );
  }
}
