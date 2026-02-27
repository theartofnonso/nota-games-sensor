import 'package:flutter/material.dart';
import 'package:trainware/dtos/mock_coach_dto.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// Bottom sheet content: coach profile with Choose Coach CTA.
class CoachProfileBottomSheetContent extends StatelessWidget {
  final MockCoachDto coach;
  final VoidCallback onChooseCoach;

  const CoachProfileBottomSheetContent({
    super.key,
    required this.coach,
    required this.onChooseCoach,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.extension<TRKRColors>()?.borderLight ??
                    Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 48,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            coach.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (coach.description != null && coach.description!.isNotEmpty)
            Text(
              coach.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 32),
          OpacityButtonWidgetTwo(
            label: 'Choose Coach',
            buttonColor: theme.extension<TRKRColors>()!.vibrantAccent,
            onPressed: onChooseCoach,
          ),
        ],
      ),
    );
  }
}
