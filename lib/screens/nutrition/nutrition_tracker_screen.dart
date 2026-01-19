import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/nutrition/calorie_tracking_card.dart';

class NutritionTrackerScreen extends StatefulWidget {
  const NutritionTrackerScreen({super.key});

  @override
  State<NutritionTrackerScreen> createState() => _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState extends State<NutritionTrackerScreen> {
  final List<_MacroLog> _logs = [
    _MacroLog(
      title: 'Sunrise Bowl',
      time: DateTime.now().subtract(const Duration(minutes: 15)),
      fat: 9.3,
      carbs: 9.4,
      protein: 16.0,
      fatTarget: 24,
      carbsTarget: 60,
      proteinTarget: 30,
      calories: 187,
      calorieTarget: 456,
    ),
    _MacroLog(
      title: 'Citrus Salad',
      time: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
      fat: 14.2,
      carbs: 38.0,
      protein: 28.5,
      fatTarget: 30,
      carbsTarget: 80,
      proteinTarget: 40,
      calories: 412,
      calorieTarget: 680,
    ),
    _MacroLog(
      title: 'Garden Wrap',
      time: DateTime.now().subtract(const Duration(hours: 5, minutes: 40)),
      fat: 6.8,
      carbs: 15.2,
      protein: 10.4,
      fatTarget: 20,
      carbsTarget: 45,
      proteinTarget: 25,
      calories: 145,
      calorieTarget: 280,
    ),
    _MacroLog(
      title: 'Morning Toast',
      time: DateTime.now().subtract(const Duration(hours: 8, minutes: 20)),
      fat: 7.1,
      carbs: 22.5,
      protein: 11.4,
      fatTarget: 18,
      carbsTarget: 50,
      proteinTarget: 28,
      calories: 210,
      calorieTarget: 350,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sortedLogs = _logs.toList()..sort((a, b) => b.time.compareTo(a.time));

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colors;

    return Scaffold(
      backgroundColor: appBarBackgroundColor(context: context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
              children: [
                const CalorieTrackingCard(),
                const SizedBox(height: 16),
                Text(
                  'Today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                ),
                const SizedBox(height: 8),
                ...sortedLogs.map((log) => _MacroLogCard(
                      log: log,
                      colors: colors,
                      isDarkMode: isDarkMode,
                      onDelete: () => _confirmDelete(log),
                      onTap: () => _showMacroDetails(log),
                    )),
              ],
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton(
                icon: FaIcon(
                  FontAwesomeIcons.solidCircleXmark,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 24,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(_MacroLog log) async {
    final shouldDelete = await showAppBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete log?',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.start,
            ),
            Text(
              'Are you sure you want to delete this log?',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                onPressed: () => Navigator.of(context).pop(true),
                label: 'Delete',
                buttonColor: Colors.red,
                showArrowRight: false,
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete != true) {
      return false;
    }

    setState(() {
      _logs.removeWhere((item) => item.id == log.id);
    });
    return true;
  }

  Future<void> _showMacroDetails(_MacroLog log) async {
    final timeLabel = DateFormat('h:mm a').format(log.time);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colors;
    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FrostedCard(
              padding: const EdgeInsets.all(18),
              gradientColors: [
                (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.06),
                (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.03),
                colors.sapphireDark.withValues(alpha: 0.2),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 140,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                    textAlign: TextAlign.start,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: isDarkMode
                                              ? Colors.white
                                                  .withValues(alpha: 0.6)
                                              : Colors.black
                                                  .withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${log.calories}',
                                    style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                            ) ??
                                        TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          height: 1.0,
                                          fontFamily: 'Grift',
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${log.calorieTarget} kcal goal',
                                    style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isDarkMode
                                                  ? Colors.white
                                                      .withValues(alpha: 0.6)
                                                  : Colors.black
                                                      .withValues(alpha: 0.6),
                                              fontWeight: FontWeight.w500,
                                            ) ??
                                        TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                                  .withValues(alpha: 0.6)
                                              : Colors.black
                                                  .withValues(alpha: 0.6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      CalorieGauge(
                        progress:
                            (log.calories / log.calorieTarget).clamp(0.0, 1.0),
                        progressColor: Colors.white,
                        trackColor: Colors.white.withValues(alpha: 0.08),
                        knobColor: Colors.white,
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MacroDetailRow(
                    label: 'Protein',
                    value: log.protein,
                    target: log.proteinTarget,
                    barColor: const Color(0xFF22c55e),
                  ),
                  const SizedBox(height: 20),
                  _MacroDetailRow(
                    label: 'Carbs',
                    value: log.carbs,
                    target: log.carbsTarget,
                    barColor: const Color(0xFF3b82f6),
                  ),
                  const SizedBox(height: 20),
                  _MacroDetailRow(
                    label: 'Fats',
                    value: log.fat,
                    target: log.fatTarget,
                    barColor: const Color(0xFFf59e0b),
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

class _MacroDetailRow extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color barColor;

  const _MacroDetailRow({
    required this.label,
    required this.value,
    required this.target,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / target).clamp(0.0, 1.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${value.toStringAsFixed(1)} / ${target.toStringAsFixed(1)} g',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _MacroProgressBar(
                progress: progress,
                barColor: barColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroProgressBar extends StatelessWidget {
  final double progress;
  final Color barColor;

  const _MacroProgressBar({
    required this.progress,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: clamped,
      minHeight: 8,
      backgroundColor: barColor.withValues(alpha: 0.2),
      valueColor: AlwaysStoppedAnimation<Color>(barColor),
    );
  }
}

class _MacroLogCard extends StatelessWidget {
  final _MacroLog log;
  final TRKRColors colors;
  final bool isDarkMode;
  final Future<bool> Function() onDelete;
  final VoidCallback onTap;

  const _MacroLogCard({
    required this.log,
    required this.colors,
    required this.isDarkMode,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('h:mm a').format(log.time);
    final calorieProgress = (log.calories / log.calorieTarget).clamp(0.0, 1.0);
    final iconData = _iconForHour(log.time.hour);
    final iconColor = _iconColorForHour(log.time.hour);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(log.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(),
        background: const SizedBox.shrink(),
        child: GestureDetector(
          onTap: onTap,
          child: _FrostedCard(
            padding: const EdgeInsets.all(16),
            gradientColors: [
              (isDarkMode ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
              (isDarkMode ? Colors.white : Colors.black)
                  .withValues(alpha: 0.03),
              colors.sapphireDark.withValues(alpha: 0.2),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(
                          alpha: isDarkMode ? 0.25 : 0.15,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        iconData,
                        size: 16,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${log.calories} / ${log.calorieTarget} kcal',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.65)
                                          : Colors.black.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: calorieProgress,
                    minHeight: 6,
                    backgroundColor:
                        const Color(0xFF22c55e).withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF22c55e),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${log.protein.toStringAsFixed(1)}g protein, '
                  '${log.carbs.toStringAsFixed(1)}g carbs, '
                  'and ${log.fat.toStringAsFixed(1)}g fat',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForHour(int hour) {
    if (hour >= 5 && hour < 12) {
      return Icons.wb_sunny_outlined;
    }
    if (hour >= 12 && hour < 17) {
      return Icons.wb_sunny;
    }
    if (hour >= 17 && hour < 21) {
      return Icons.wb_twilight;
    }
    return Icons.nightlight_round;
  }

  Color _iconColorForHour(int hour) {
    if (hour >= 5 && hour < 12) {
      return const Color(0xFFF59E0B);
    }
    if (hour >= 12 && hour < 17) {
      return const Color(0xFFfbbf24);
    }
    if (hour >= 17 && hour < 21) {
      return const Color(0xFFf97316);
    }
    return const Color(0xFF6366f1);
  }
}

class _MacroLog {
  final String id;
  final String title;
  final DateTime time;
  final double fat;
  final double carbs;
  final double protein;
  final double fatTarget;
  final double carbsTarget;
  final double proteinTarget;
  final int calories;
  final int calorieTarget;

  _MacroLog({
    required this.title,
    required this.time,
    required this.fat,
    required this.carbs,
    required this.protein,
    required this.fatTarget,
    required this.carbsTarget,
    required this.proteinTarget,
    required this.calories,
    required this.calorieTarget,
  }) : id = UniqueKey().toString();
}

class _FrostedCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final EdgeInsets padding;

  const _FrostedCard({
    required this.child,
    required this.gradientColors,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
