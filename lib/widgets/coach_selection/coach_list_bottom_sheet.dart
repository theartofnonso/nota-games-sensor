import 'package:flutter/material.dart';
import 'package:trainware/dtos/mock_coach_dto.dart';

/// Mock coaches for the coach selection flow.
List<MockCoachDto> get mockCoaches => const [
  MockCoachDto(
    id: 'mock-1',
    name: 'Alex Morgan',
    description: 'Strength & conditioning specialist. 10+ years experience.',
  ),
  MockCoachDto(
    id: 'mock-2',
    name: 'Jordan Lee',
    description: 'CrossFit coach. Focus on functional fitness.',
  ),
  MockCoachDto(
    id: 'mock-3',
    name: 'Sam Taylor',
    description: 'Marathon runner & endurance coach.',
  ),
  MockCoachDto(
    id: 'mock-4',
    name: 'Casey Kim',
    description: 'Powerlifting & Olympic lifting coach.',
  ),
];

/// Reusable coach grid item for the selection flow.
class CoachGridItem extends StatelessWidget {
  final MockCoachDto coach;
  final bool isDarkMode;
  final VoidCallback onTap;

  const CoachGridItem({
    super.key,
    required this.coach,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'images/background.jpg',
                fit: BoxFit.cover,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Text(
                    coach.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
