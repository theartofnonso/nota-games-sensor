import 'package:flutter/material.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/coach_selection/coach_list_bottom_sheet.dart';
import 'package:trainware/widgets/coach_selection/coach_profile_bottom_sheet.dart';

import '../../app_flavor.dart';
import '../../dtos/mock_coach_dto.dart';

/// Full-screen shown when client has no coach and hasn't completed the
/// coach selection flow. Lists coaches in a grid; tapping opens profile sheet.
class CoachSelectionScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const CoachSelectionScreen({
    super.key,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isClient) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
                      'Select a coach to get started. They\'ll help you reach your goals.',
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.9,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: mockCoaches.length,
                    itemBuilder: (context, index) {
                      final coach = mockCoaches[index];
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

  void _showCoachProfile(BuildContext context, MockCoachDto coach) {
    showAppBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (context, scrollController) => PopScope(
        canPop: false,
        child: CoachProfileBottomSheetContent(
        coach: coach,
        onChooseCoach: () {
          Navigator.of(context).pop();
          SharedPrefs().coachSelectionComplete = true;
          onComplete();
        },
        ),
      ),
    );
  }
}
