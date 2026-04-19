import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:trainware/dtos/nutrition/nutrition_template_dto.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/nutrition/calorie_tracking_card.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';
import 'package:trainware/services/nutrition_estimate_service.dart';
import 'package:trainware/widgets/empty_states/illustrated_empty_state.dart';

/// Shows the create/edit nutrition template bottom sheet. Used from Settings
/// (coach, no client logs) and from NutritionTrackerScreen app bar.
Future<void> showNutritionTemplateSheet(BuildContext context) async {
  final nutritionController = context.read<NutritionLogController>();
  final template = nutritionController.nutritionTemplate;

  const maxMacro = 500.0;

  double protein = (template?.protein ?? NutritionTemplateDto.defaultProteinG)
      .clamp(0.0, maxMacro);
  double carbs = (template?.carbs ?? NutritionTemplateDto.defaultCarbsG).clamp(
    0.0,
    maxMacro,
  );
  double fats = (template?.fats ?? NutritionTemplateDto.defaultFatsG).clamp(
    0.0,
    maxMacro,
  );

  await showAppActionBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    child: Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final mutedColor = (isDark ? Colors.white : Colors.black).withValues(
          alpha: 0.6,
        );
        final accent = Theme.of(ctx).colors.vibrantAccent;

        const colorCalories = Color(0xFFF59E0B);
        const colorProtein = Color(0xFFEF4444);
        const colorCarbs = Color(0xFF3B82F6);
        const colorFats = Color(0xFF22C55E);

        Widget buildSliderRow({
          required String label,
          required double value,
          required double max,
          required Color trackColor,
          required ValueChanged<double> onChanged,
          String? unit,
        }) {
          final displayValue =
              value == value.roundToDouble()
                  ? value.round().toString()
                  : value.toStringAsFixed(1);
          final valueLabel = unit != null ? '$displayValue $unit' : displayValue;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                          animation,
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      valueLabel,
                      key: ValueKey<String>(valueLabel),
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: trackColor,
                  inactiveTrackColor: trackColor.withValues(alpha: 0.2),
                  thumbColor: trackColor,
                  overlayColor: trackColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: value.clamp(0.0, max),
                  min: 0,
                  max: max,
                  divisions: 50,
                  onChanged: onChanged,
                ),
              ),
            ],
          );
        }

        Widget buildCalorieTargetFromMacros({
          required double proteinG,
          required double carbsG,
          required double fatsG,
        }) {
          final kcal = NutritionTemplateDto.kcalFromMacroGrams(
            proteinG,
            carbsG,
            fatsG,
          );
          final display =
              kcal == kcal.roundToDouble()
                  ? '${kcal.round()}'
                  : kcal.toStringAsFixed(1);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Calorie target',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  '$display kcal',
                  style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                    color: colorCalories,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          );
        }

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.72;
            return Padding(
              padding: const EdgeInsets.only(
                left: 26,
                right: 26,
                top: 26,
                bottom: 26,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxSheetHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrition template',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set macro targets. Calorie goal updates when you adjust them.',
                        style: Theme.of(
                          ctx,
                        ).textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                      const SizedBox(height: 20),
                      buildCalorieTargetFromMacros(
                        proteinG: protein,
                        carbsG: carbs,
                        fatsG: fats,
                      ),
                      const SizedBox(height: 16),
                      buildSliderRow(
                        label: 'Protein',
                        value: protein,
                        max: maxMacro,
                        trackColor: colorProtein,
                        unit: 'g',
                        onChanged: (v) => setSheetState(() => protein = v),
                      ),
                      const SizedBox(height: 8),
                      buildSliderRow(
                        label: 'Carbs',
                        value: carbs,
                        max: maxMacro,
                        trackColor: colorCarbs,
                        unit: 'g',
                        onChanged: (v) => setSheetState(() => carbs = v),
                      ),
                      const SizedBox(height: 8),
                      buildSliderRow(
                        label: 'Fats',
                        value: fats,
                        max: maxMacro,
                        trackColor: colorFats,
                        unit: 'g',
                        onChanged: (v) => setSheetState(() => fats = v),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OpacityButtonWidgetTwo(
                          buttonColor: accent,
                          label: 'Save template',
                          onPressed: () async {
                            final ownerId =
                                Supabase.instance.client.auth.currentUser?.id;
                            final clientId = nutritionController.activeUserId;
                            if (ownerId == null || clientId == null) {
                              showSnackbar(
                                context: ctx,
                                message: 'Unable to save template.',
                              );
                              return;
                            }

                            final now = DateTime.now();
                            final derivedCalories =
                                NutritionTemplateDto.kcalFromMacroGrams(
                                  protein,
                                  carbs,
                                  fats,
                                );
                            final updated = NutritionTemplateDto(
                              id: template?.id ?? const Uuid().v4(),
                              owner: ownerId,
                              clientId: clientId,
                              calories: derivedCalories,
                              protein: protein,
                              carbs: carbs,
                              fats: fats,
                              createdAt: template?.createdAt ?? now,
                              updatedAt: now,
                            );

                            showCoachLoadingOverlay(ctx);
                            try {
                              await nutritionController.upsertTemplate(
                                template: updated,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                            } finally {
                              if (ctx.mounted) hideCoachLoadingOverlay(ctx);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class NutritionTrackerScreen extends StatefulWidget {
  /// Deep link / push route (local notification nudges).
  static const routeName = '/nutrition-tracker';

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
    final sortedLogs =
        controller.logs.toList()
          ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    final logEntries = _buildLogEntries(sortedLogs);
    final consumedCalories = _sumCaloriesToday(todayLogs);
    final goalCalories = controller.calorieTarget;
    final hasLogsToday = todayLogs.isNotEmpty;
    final remainingCalories =
        goalCalories > 0
            ? (hasLogsToday
                ? (goalCalories - consumedCalories).clamp(0.0, goalCalories)
                : goalCalories)
            : 0.0;
    final consumedProtein = _sumProteinToday(todayLogs);
    final consumedCarbs = _sumCarbsToday(todayLogs);
    final consumedFats = _sumFatsToday(todayLogs);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: themeGradient(context: context).colors.first,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
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
        actions: [
          IconButton(
            icon: FaIcon(
              AppConfig.isCoach
                  ? FontAwesomeIcons.gear
                  : FontAwesomeIcons.circlePlus,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 24,
            ),
            onPressed: () {
              if (AppConfig.isCoach) {
                showNutritionTemplateSheet(context);
              } else {
                _showAddEntrySheet();
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip:
                AppConfig.isCoach
                    ? 'Edit nutrition template'
                    : 'Add entry',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: themeGradient(context: context)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
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
              calorieCardHeroTag: 'nutrition_calorie_card',
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (sortedLogs.isEmpty)
                    IllustratedEmptyState(
                      icon: FontAwesomeIcons.bowlFood,
                      title: 'No nutrition logs yet',
                      body:
                          'Tap + to log a meal or snack. Your entries and macros will show up here.',
                    )
                  else
                    ...logEntries.map((entry) {
                      if (entry.isWeekDivider) {
                        return _LogWeekDivider(label: entry.label!);
                      }
                      if (entry.isDivider) {
                        return _LogDateDivider(
                          label: entry.label!,
                          totals: entry.totals ?? const _MacroTotals(),
                        );
                      }
                      return _MacroLogCard(
                        log: entry.log!,
                        isDarkMode: isDarkMode,
                        calorieTarget: controller.calorieTarget,
                        canDelete: !AppConfig.isCoach,
                        onDelete: () => _confirmDelete(entry.log!),
                        onTap: () => _showMacroDetails(entry.log!),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(NutritionLogDto log) async {
    final shouldDelete = await showAppActionBottomSheet<bool>(
      context: context,
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
              ),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete != true) {
      return false;
    }

    if (!mounted) return false;
    await context.read<NutritionLogController>().removeLog(id: log.id);
    return true;
  }

  Future<void> _showMacroDetails(NutritionLogDto log) async {
    final timeLabel = DateFormat('h:mm a').format(log.loggedAt);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final controller = context.read<NutritionLogController>();
    final calorieTarget = controller.calorieTarget;
    await showAppActionBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      isDarkMode
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
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 140),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.foodName,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.start,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeLabel,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color:
                                            isDarkMode
                                                ? Colors.white.withValues(
                                                  alpha: 0.6,
                                                )
                                                : Colors.black.withValues(
                                                  alpha: 0.5,
                                                ),
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
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.displaySmall?.copyWith(
                                            color:
                                                isDarkMode
                                                    ? Colors.white
                                                    : Colors.black,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ) ??
                                          TextStyle(
                                            color:
                                                isDarkMode
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
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.copyWith(
                                            color:
                                                isDarkMode
                                                    ? Colors.white.withValues(
                                                      alpha: 0.6,
                                                    )
                                                    : Colors.black.withValues(
                                                      alpha: 0.6,
                                                    ),
                                            fontWeight: FontWeight.w500,
                                          ) ??
                                          TextStyle(
                                            color:
                                                isDarkMode
                                                    ? Colors.white.withValues(
                                                      alpha: 0.6,
                                                    )
                                                    : Colors.black.withValues(
                                                      alpha: 0.6,
                                                    ),
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
                              calorieTarget <= 0
                                  ? 0
                                  : (log.calories / calorieTarget).clamp(
                                    0.0,
                                    1.0,
                                  ),
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
                    if (log.summary != null &&
                        log.summary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        log.summary!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: (isDarkMode ? Colors.white : Colors.black)
                              .withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEntrySheet() async {
    await _showLogMealByDescriptionSheet();
  }

  /// New entry: user describes the meal; we call the API and log the returned macros.
  Future<void> _showLogMealByDescriptionSheet() async {
    final mealController = TextEditingController();
    DateTime selectedLoggedAt = DateTime.now();

    await showAppActionBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      child: Builder(
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final maxSheetHeight = MediaQuery.of(context).size.height * 0.42;
              final isDarkMode =
                  Theme.of(context).brightness == Brightness.dark;
              final loggedAtLabel = DateFormat(
                'EEE, MMM d • h:mm a',
              ).format(selectedLoggedAt);

              return Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Log a meal',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Describe what you ate.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: (isDarkMode ? Colors.white : Colors.black)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: mealController,
                          textInputAction: TextInputAction.done,
                          cursorColor: isDarkMode ? Colors.white : Colors.black,
                          minLines: 1,
                          maxLines: 1,
                          decoration: const InputDecoration(
                            hintText:
                                'e.g. two eggs, toast with butter, orange juice',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDateTimePicker(
                              context: context,
                              initialDateTime: selectedLoggedAt,
                              mode: CupertinoDatePickerMode.dateAndTime,
                              onChangedDateTime: (value) {
                                setModalState(() => selectedLoggedAt = value);
                              },
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loggedAtLabel,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: _LogMealButton(
                            mealController: mealController,
                            selectedLoggedAt: selectedLoggedAt,
                            onLogged: () {
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
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
    String? lastWeekKey;
    final totalsByLabel = <String, _MacroTotals>{};

    for (final log in logs) {
      final label = _dateBucketLabel(log.loggedAt.toLocal());
      totalsByLabel[label] = (totalsByLabel[label] ?? const _MacroTotals())
          .addLog(log);
    }

    for (final log in logs) {
      final logDate = log.loggedAt.toLocal();
      final weekKey = _weekKey(logDate);
      final label = _dateBucketLabel(logDate);

      if (weekKey != lastWeekKey) {
        entries.add(_LogListEntry.weekDivider(_weekLabel(logDate)));
        lastWeekKey = weekKey;
      }
      if (label != lastLabel) {
        entries.add(
          _LogListEntry.divider(
            label,
            totalsByLabel[label] ?? const _MacroTotals(),
          ),
        );
        lastLabel = label;
      }
      entries.add(_LogListEntry.log(log));
    }

    return entries;
  }

  /// Week runs Monday–Sunday (Monday first, Sunday last).
  /// Key = Monday that starts the week.
  String _weekKey(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  String _weekLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));
    if (monday == currentMonday) return 'This Week';
    final lastMonday = currentMonday.subtract(const Duration(days: 7));
    if (monday == lastMonday) return 'Last Week';
    return 'Week ending Sun ${DateFormat('d MMM').format(sunday)}';
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
}

/// Empty log list: same for coach and client; matches [CoachFeedbackFeedScreen]
/// / [RoutinesShellPage] (circle icon, title, body).
/// Button that calls the nutrition API with the meal description and logs the result.
class _LogMealButton extends StatefulWidget {
  final TextEditingController mealController;
  final DateTime selectedLoggedAt;
  final VoidCallback onLogged;

  const _LogMealButton({
    required this.mealController,
    required this.selectedLoggedAt,
    required this.onLogged,
  });

  @override
  State<_LogMealButton> createState() => _LogMealButtonState();
}

class _LogMealButtonState extends State<_LogMealButton> {
  bool _isLoading = false;

  Future<void> _logMeal() async {
    final userId = context.read<NutritionLogController>().activeUserId;
    if (userId == null) {
      showSnackbar(
        context: context,
        message: 'Please sign in to log nutrition.',
      );
      return;
    }

    final meal = widget.mealController.text.trim();
    if (meal.isEmpty) {
      showSnackbar(context: context, message: 'Describe what you ate.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final estimate = await estimateFromMealDescription(meal);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (estimate == null) {
      showSnackbar(
        context: context,
        message:
            'Could not estimate nutrition. Try again or check your connection.',
      );
      return;
    }

    final now = DateTime.now();
    final log = NutritionLogDto(
      id: const Uuid().v4(),
      userId: userId,
      foodName: meal,
      protein: estimate.protein,
      carbs: estimate.carbs,
      fats: estimate.fats,
      loggedAt: widget.selectedLoggedAt,
      createdAt: now,
      updatedAt: now,
      summary: estimate.summary,
    );

    await context.read<NutritionLogController>().addLog(log: log);
    if (mounted) widget.onLogged();
  }

  @override
  Widget build(BuildContext context) {
    return OpacityButtonWidgetTwo(
      onPressed: _isLoading ? null : _logMeal,
      label: _isLoading ? 'Estimating…' : 'Log meal',
      buttonColor: Theme.of(context).colors.vibrantAccent,
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
              _MacroProgressBar(progress: progress, barColor: barColor),
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

  const _MacroProgressBar({required this.progress, required this.barColor});

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
  final bool canDelete;
  final Future<bool> Function() onDelete;
  final VoidCallback onTap;

  const _MacroLogCard({
    required this.log,
    required this.isDarkMode,
    required this.calorieTarget,
    required this.canDelete,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeLabel = DateFormat('h:mm a').format(log.loggedAt);
    final calorieProgress =
        calorieTarget <= 0
            ? 0.0
            : (log.calories / calorieTarget).clamp(0.0, 1.0);
    final iconData = _iconForHour(log.loggedAt.hour);
    final iconColor = _iconColorForHour(log.loggedAt.hour);
    final cardContent = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: Icon(iconData, size: 16, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.foodName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${log.caloriesRounded} / ${calorieTarget.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              isDarkMode
                                  ? Colors.white.withValues(alpha: 0.65)
                                  : Colors.black.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        isDarkMode
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: calorieProgress,
                minHeight: 6,
                backgroundColor: const Color(0xFF22c55e).withValues(alpha: 0.2),
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
                color:
                    isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child:
          canDelete
              ? Dismissible(
                key: ValueKey(log.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => onDelete(),
                background: const SizedBox.shrink(),
                child: cardContent,
              )
              : cardContent,
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
  final _MacroTotals? totals;
  final bool isWeekDivider;

  const _LogListEntry.log(this.log)
    : label = null,
      totals = null,
      isWeekDivider = false;
  const _LogListEntry.divider(this.label, this.totals)
    : log = null,
      isWeekDivider = false;
  const _LogListEntry.weekDivider(this.label)
    : log = null,
      totals = null,
      isWeekDivider = true;

  bool get isDivider => label != null;
}

class _MacroTotals {
  final double protein;
  final double carbs;
  final double fats;
  final double calories;

  const _MacroTotals({
    this.protein = 0,
    this.carbs = 0,
    this.fats = 0,
    this.calories = 0,
  });

  _MacroTotals addLog(NutritionLogDto log) {
    return _MacroTotals(
      protein: protein + log.protein,
      carbs: carbs + log.carbs,
      fats: fats + log.fats,
      calories: calories + log.calories,
    );
  }
}

class _LogWeekDivider extends StatelessWidget {
  final String label;

  const _LogWeekDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LogDateDivider extends StatelessWidget {
  final String label;
  final _MacroTotals totals;

  const _LogDateDivider({required this.label, required this.totals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalsLabel =
        'Calories ${totals.calories.toStringAsFixed(0)} • '
        'Protein ${totals.protein.toStringAsFixed(1)}g • '
        'Carbs ${totals.carbs.toStringAsFixed(1)}g • '
        'Fats ${totals.fats.toStringAsFixed(1)}g';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.black.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              totalsLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
