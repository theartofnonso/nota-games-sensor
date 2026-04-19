import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';

import 'package:trainware/colors.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';

/// Square tile for one alternative (or `exercise == null` for the “add” slot).
class ExerciseAlternativeCard extends StatelessWidget {
  final ExerciseDto? exercise;
  final double dimension;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRemove;

  const ExerciseAlternativeCard({
    super.key,
    this.exercise,
    this.dimension = 80,
    this.onTap,
    this.onLongPress,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final d = dimension;
    final lottieSize = (d * 0.7).clamp(28.0, 56.0);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: d,
        height: d,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: d,
              height: d,
              decoration: exercise != null
                  ? BoxDecoration(
                      color: sapphireDark80,
                      borderRadius: BorderRadius.circular(12),
                    )
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
              padding: const EdgeInsets.all(8),
              child: Center(
                child: exercise == null
                    ? FaIcon(
                        FontAwesomeIcons.circlePlus,
                        size: (d * 0.3).clamp(18.0, 24.0),
                        color: Colors.white70,
                      )
                    : exercise!.isSystem
                        ? FutureBuilder<String?>(
                            future:
                                LottieExerciseRegistry.lottieFor(exercise!.id),
                            builder: (context, snapshot) {
                              final asset = snapshot.data;
                              if (asset != null) {
                                return SizedBox(
                                  width: lottieSize,
                                  height: lottieSize,
                                  child: Lottie.asset(
                                    asset,
                                    fit: BoxFit.contain,
                                    repeat: true,
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  exercise!.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                ),
                              );
                            },
                          )
                        : Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              exercise!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: Colors.black87,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: (d * 0.2).clamp(12.0, 16.0),
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
