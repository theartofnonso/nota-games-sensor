import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/decision_log_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/empty_states/list_empty_state.dart';
import 'package:trainware/widgets/nutrition/calorie_tracking_card.dart';

class NutritionTrackerScreen extends StatefulWidget {
  const NutritionTrackerScreen({super.key});

  @override
  State<NutritionTrackerScreen> createState() => _NutritionTrackerScreenState();
}

class _NutritionTrackerScreenState extends State<NutritionTrackerScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialized) return;
      _initialized = true;
      context.read<NutritionLogController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NutritionLogController>();
    final todayLogs = _logsForToday(controller.logs);
    final sortedLogs = controller.logs.toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final logEntries = _buildLogEntries(sortedLogs);
    final consumedCalories = _sumCaloriesToday(todayLogs);
    final goalCalories = controller.calorieTarget;
    final hasLogsToday = todayLogs.isNotEmpty;
    final remainingCalories = goalCalories > 0
        ? (hasLogsToday
            ? (goalCalories - consumedCalories).clamp(0.0, goalCalories)
            : goalCalories)
        : 0.0;
    final consumedProtein = _sumProteinToday(todayLogs);
    final consumedCarbs = _sumCarbsToday(todayLogs);
    final consumedFats = _sumFatsToday(todayLogs);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: appBarBackgroundColor(context: context),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(0, 56, 0, 24),
              children: [
                NutritionTrackingCarousel(
                  goalCalories: goalCalories,
                  remainingCalories: remainingCalories,
                  proteinTarget: controller.proteinTarget,
                  carbsTarget: controller.carbsTarget,
                  fatsTarget: controller.fatsTarget,
                  consumedProtein: consumedProtein,
                  consumedCarbs: consumedCarbs,
                  consumedFats: consumedFats,
                  hasLogsToday: hasLogsToday,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sortedLogs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 50.0),
                          child: ListEmptyState(
                            message:
                                "It might feel quiet now, but your nutrition logs will soon appear here.",
                          ),
                        )
                      else
                        ...logEntries.map(
                          (entry) => entry.isDivider
                              ? _LogDateDivider(label: entry.label!)
                              : _MacroLogCard(
                                    log: entry.log!,
                                    isDarkMode: isDarkMode,
                                    calorieTarget: controller.calorieTarget,
                                    onDelete: () => _confirmDelete(entry.log!),
                                    onTap: () => _showMacroDetails(entry.log!),
                                  ),
                        ),
                    ],
                  ),
                ),
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
            if (!controller.isCoach)
              Positioned(
                top: 8,
                right: 12,
                child: IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.circlePlus,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 24,
                  ),
                  onPressed: () {
                    _showAddEntrySheet();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Add entry',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(NutritionLogDto log) async {
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

    final nutritionController = context.read<NutritionLogController>();
    if (nutritionController.isClientMode) {
      final clientId = nutritionController.activeUserId;
      if (clientId == null) {
        showSnackbar(
          context: context,
          message: 'Missing client context for decision log.',
        );
        return false;
      }
      final logged = await requireDecisionLog(
        context: context,
        clientId: clientId,
      );
      if (!logged) {
        return false;
      }
    }

    await context.read<NutritionLogController>().removeLog(id: log.id);
    return true;
  }

  Future<void> _showMacroDetails(NutritionLogDto log) async {
    final timeLabel = DateFormat('h:mm a').format(log.loggedAt);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final controller = context.read<NutritionLogController>();
    final calorieTarget = controller.calorieTarget;
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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isDarkMode ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                ),
              ),
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
                                    log.foodName,
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
                                    '${log.caloriesRounded}',
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
                                    '${calorieTarget.toStringAsFixed(0)} kcal goal',
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
                        progress: calorieTarget <= 0
                            ? 0
                            : (log.calories / calorieTarget).clamp(0.0, 1.0),
                        progressColor: Colors.white,
                        trackColor: Colors.white.withValues(alpha: 0.08),
                        knobColor: Colors.white,
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          _showAddEntrySheet(existingLog: log);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isDarkMode ? Colors.white : Colors.black)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MacroDetailRow(
                    label: 'Protein',
                    value: log.protein,
                    target: controller.proteinTarget,
                    barColor: const Color(0xFF22c55e),
                  ),
                  const SizedBox(height: 20),
                  _MacroDetailRow(
                    label: 'Carbs',
                    value: log.carbs,
                    target: controller.carbsTarget,
                    barColor: const Color(0xFF3b82f6),
                  ),
                  const SizedBox(height: 20),
                  _MacroDetailRow(
                    label: 'Fats',
                    value: log.fats,
                    target: controller.fatsTarget,
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

  Future<void> _showAddEntrySheet({NutritionLogDto? existingLog}) async {
    final titleController = TextEditingController(
      text: existingLog?.foodName ?? '',
    );
    final proteinController = TextEditingController(
      text: existingLog?.protein.toString() ?? '',
    );
    final carbsController = TextEditingController(
      text: existingLog?.carbs.toString() ?? '',
    );
    final fatsController = TextEditingController(
      text: existingLog?.fats.toString() ?? '',
    );
    final isEditing = existingLog != null;

    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      child: Builder(
        builder: (ctx) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              left: 26,
              right: 26,
              top: 26,
              bottom: 26 + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? 'Edit entry' : 'What did you eat?',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(
                    left: 20,
                    top: 6,
                    bottom: 6,
                    right: 6,
                  ),
                  child: TextField(
                    controller: titleController,
                    textInputAction: TextInputAction.next,
                    cursorColor: isDarkMode ? Colors.white : Colors.black,
                    decoration: const InputDecoration(
                      hintText: 'Food name',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      _MacroInputField(
                        label: 'protein',
                        controller: proteinController,
                      ),
                      _MacroInputField(
                        label: 'carbs',
                        controller: carbsController,
                      ),
                      _MacroInputField(
                        label: 'fats',
                        controller: fatsController,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OpacityButtonWidgetTwo(
                    onPressed: () async {
                      final nutritionController =
                          context.read<NutritionLogController>();
                      final userId = nutritionController.activeUserId;
                      if (userId == null) {
                        showSnackbar(
                          context: ctx,
                          message: 'Please sign in to log nutrition.',
                        );
                        return;
                      }

                      final name = titleController.text.trim();
                      if (name.isEmpty) {
                        showSnackbar(
                          context: ctx,
                          message: 'Please enter a food name.',
                        );
                        return;
                      }

                      final protein = _parseMacro(proteinController.text);
                      final carbs = _parseMacro(carbsController.text);
                      final fats = _parseMacro(fatsController.text);
                      final now = DateTime.now();

                      if (nutritionController.isClientMode) {
                        final logged = await requireDecisionLog(
                          context: ctx,
                          clientId: userId,
                        );
                        if (!logged) {
                          return;
                        }
                      }

                      final log = NutritionLogDto(
                        id: existingLog?.id ?? const Uuid().v4(),
                        userId: userId,
                        foodName: name,
                        protein: protein,
                        carbs: carbs,
                        fats: fats,
                        loggedAt: existingLog?.loggedAt ?? now,
                        createdAt: existingLog?.createdAt ?? now,
                        updatedAt: now,
                      );

                      await context
                          .read<NutritionLogController>()
                          .addLog(log: log);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                    },
                    label: isEditing ? 'Update log' : 'Log calories',
                    buttonColor: Theme.of(ctx).colors.vibrantAccent,
                    showArrowRight: false,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<NutritionLogDto> _logsForToday(List<NutritionLogDto> logs) {
    final now = DateTime.now();
    return logs
        .where((log) => _isSameDay(log.loggedAt.toLocal(), now))
        .toList();
  }

  List<_LogListEntry> _buildLogEntries(List<NutritionLogDto> logs) {
    final entries = <_LogListEntry>[];
    String? lastLabel;

    for (final log in logs) {
      final label = _dateBucketLabel(log.loggedAt.toLocal());
      if (label != lastLabel) {
        entries.add(_LogListEntry.divider(label));
        lastLabel = label;
      }
      entries.add(_LogListEntry.log(log));
    }

    return entries;
  }

  String _dateBucketLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final logDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (logDate == today) {
      return 'Today';
    }
    if (logDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, d MMM').format(logDate);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  double _sumCaloriesToday(List<NutritionLogDto> logs) {
    return logs.fold(0.0, (sum, log) => sum + log.calories);
  }

  double _sumProteinToday(List<NutritionLogDto> logs) {
    return logs.fold(0.0, (sum, log) => sum + log.protein);
  }

  double _sumCarbsToday(List<NutritionLogDto> logs) {
    return logs.fold(0.0, (sum, log) => sum + log.carbs);
  }

  double _sumFatsToday(List<NutritionLogDto> logs) {
    return logs.fold(0.0, (sum, log) => sum + log.fats);
  }

  double _parseMacro(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }
}

class _MacroInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _MacroInputField({
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                hintText: '0',
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 6),
        ],
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
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);

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
  final NutritionLogDto log;
  final bool isDarkMode;
  final double calorieTarget;
  final Future<bool> Function() onDelete;
  final VoidCallback onTap;

  const _MacroLogCard({
    required this.log,
    required this.isDarkMode,
    required this.calorieTarget,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('h:mm a').format(log.loggedAt);
    final calorieProgress = calorieTarget <= 0
        ? 0.0
        : (log.calories / calorieTarget).clamp(0.0, 1.0);
    final iconData = _iconForHour(log.loggedAt.hour);
    final iconColor = _iconColorForHour(log.loggedAt.hour);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(log.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(),
        background: const SizedBox.shrink(),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
              ),
            ),
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
                            log.foodName,
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
                            '${log.caloriesRounded} / ${calorieTarget.toStringAsFixed(0)} kcal',
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
                  'and ${log.fats.toStringAsFixed(1)}g fat',
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

class _LogListEntry {
  final NutritionLogDto? log;
  final String? label;

  const _LogListEntry.log(this.log) : label = null;
  const _LogListEntry.divider(this.label) : log = null;

  bool get isDivider => label != null;
}

class _LogDateDivider extends StatelessWidget {
  final String label;

  const _LogDateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
