import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/services/exercise_instruction_service.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/cards/frosted_card.dart';

/// Bottom sheet content showing exercise instructions (setup, movement, etc.).
/// Fetches from API on open; shows loading, error, or content.
class ExerciseInstructionSheetContent extends StatefulWidget {
  final String exerciseName;
  final String? exerciseId;

  const ExerciseInstructionSheetContent({
    super.key,
    required this.exerciseName,
    this.exerciseId,
  });

  @override
  State<ExerciseInstructionSheetContent> createState() =>
      _ExerciseInstructionSheetContentState();
}

class _ExerciseInstructionSheetContentState
    extends State<ExerciseInstructionSheetContent> {
  ExerciseInstruction? _instruction;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await fetchExerciseInstruction(widget.exerciseName);
    if (!mounted) return;
    setState(() {
      _instruction = result;
      _loading = false;
      _error = result == null ? 'Could not load instructions' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: FutureBuilder<String?>(
                  future: widget.exerciseId != null
                      ? LottieExerciseRegistry.lottieFor(widget.exerciseId!)
                      : LottieExerciseRegistry.randomLottie(),
                  builder: (context, snapshot) {
                    final asset = snapshot.data;
                    if (asset != null) {
                      return Lottie.asset(
                        asset,
                        fit: BoxFit.contain,
                        repeat: true,
                      );
                    }
                    return const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white70,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading instructions...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _instruction == null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.circleExclamation,
                size: 36,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Could not load instructions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _fetch,
                child: Text(
                  'Try again',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.extension<TRKRColors>()?.vibrantAccent ??
                        vibrantGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final inst = _instruction!;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: widget.exerciseId != null
                        ? FutureBuilder<String?>(
                            future: LottieExerciseRegistry.lottieFor(
                                widget.exerciseId!),
                            builder: (context, snapshot) {
                              final asset = snapshot.data;
                              if (asset != null) {
                                return Lottie.asset(
                                  asset,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                );
                              }
                              return _buildDumbbellFallback();
                            },
                          )
                        : _buildDumbbellFallback(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inst.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (inst.difficulty != null &&
                            inst.difficulty!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              inst.difficulty!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inst.setup != null && inst.setup!.isNotEmpty)
                      _SectionCard(
                        label: 'Setup',
                        items: inst.setup!,
                      ),
                    if (inst.movement != null && inst.movement!.isNotEmpty)
                      _SectionCard(
                        label: 'Movement',
                        items: inst.movement!,
                        numbered: true,
                      ),
                    if (inst.feel != null && inst.feel!.isNotEmpty)
                      _FeelFrostedCard(text: inst.feel!),
                    if (inst.avoid != null && inst.avoid!.isNotEmpty)
                      _AvoidFrostedCard(items: inst.avoid!),
                    if (inst.proTip != null && inst.proTip!.isNotEmpty)
                      _ProTipCard(text: inst.proTip!),
                    if (inst.regression != null && inst.regression!.isNotEmpty)
                      _SectionCard(
                        label: 'Easier',
                        items: inst.regression!,
                      ),
                    if (inst.progression != null &&
                        inst.progression!.isNotEmpty)
                      _SectionCard(
                        label: 'Harder',
                        items: inst.progression!,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDumbbellFallback() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: FaIcon(
          FontAwesomeIcons.dumbbell,
          size: 18,
          color: Colors.white70,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String label;
  final List<String> items;
  final bool numbered;

  const _SectionCard({
    required this.label,
    required this.items,
    this.numbered = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sapphireDark80.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 10),
            ...items.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final prefix = numbered ? '${i + 1}. ' : '• ';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: numbered ? 24 : 12,
                      child: Text(
                        prefix,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: numbered ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FeelFrostedCard extends StatelessWidget {
  final String text;

  const _FeelFrostedCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FrostedCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        gradientColors: [
          sapphireDark80.withValues(alpha: 0.4),
          sapphireDark80.withValues(alpha: 0.2),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feel',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvoidFrostedCard extends StatelessWidget {
  final List<String> items;

  const _AvoidFrostedCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FrostedCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        gradientColors: [
          Colors.orange.withValues(alpha: 0.25),
          Colors.orange.withValues(alpha: 0.12),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avoid',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade200,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.withValues(alpha: 0.9),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProTipCard extends StatelessWidget {
  final String text;

  const _ProTipCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.extension<TRKRColors>()?.vibrantAccent ?? vibrantGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FrostedCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(16),
        gradientColors: [
          accent.withValues(alpha: 0.25),
          accent.withValues(alpha: 0.12),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FaIcon(
              FontAwesomeIcons.lightbulb,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pro tip',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
