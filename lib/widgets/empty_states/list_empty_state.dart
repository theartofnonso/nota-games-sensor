import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../utils/lottie_exercise_registry.dart';

/// A reusable empty state widget for lists with a Lottie animation.
/// The animation size is reduced to 120x120 (smaller than the previous 160x160).
class ListEmptyState extends StatelessWidget {
  final String message;
  final Future<String?>? lottieFuture;

  const ListEmptyState({
    super.key,
    required this.message,
    this.lottieFuture,
  });

  @override
  Widget build(BuildContext context) {
    final lottieFuture =
        this.lottieFuture ?? LottieExerciseRegistry.randomLottie();

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: FutureBuilder<String?>(
                future: lottieFuture,
                builder: (context, snapshot) {
                  final asset = snapshot.data;
                  if (asset != null) {
                    return Lottie.asset(
                      asset,
                      fit: BoxFit.contain,
                      repeat: true,
                    );
                  }
                  return const Icon(
                    Icons.self_improvement,
                    size: 72,
                    color: Colors.white38,
                  );
                },
              ),
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
