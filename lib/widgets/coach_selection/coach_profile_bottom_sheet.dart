import 'package:flutter/material.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// Bottom sheet content: coach profile with Choose Coach CTA.
class CoachProfileBottomSheetContent extends StatelessWidget {
  final CoachDto coach;
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
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: coach.profileImageUrl != null &&
                    coach.profileImageUrl!.trim().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      coach.profileImageUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildPlaceholderAvatar(context),
                    ),
                  )
                : _buildPlaceholderAvatar(context),
          ),
          const SizedBox(height: 12),
          Text(
            coach.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (coach.description != null && coach.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              coach.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          OpacityButtonWidgetTwo(
            label: 'Choose Coach',
            buttonColor: theme.extension<TRKRColors>()!.vibrantAccent,
            onPressed: onChooseCoach,
          ),
        ],
      ),
    );
  }

  static Widget _buildPlaceholderAvatar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color:
            theme.extension<TRKRColors>()?.borderLight ?? Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person,
        size: 32,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}
