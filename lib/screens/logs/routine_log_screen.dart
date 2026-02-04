import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/share/routine_share_service.dart';
import 'package:trainware/share/shareable_routine_renderer.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/share/shareable_routine_templates.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../dtos/viewmodels/routine_log_arguments.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/dialog_utils.dart';
import '../../app_flavor.dart';
import '../../utils/general_utils.dart';
import '../../utils/personal_bests_utils.dart';
import '../../utils/session_duration_selector.dart';
import '../../utils/string_utils.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/chip_one.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/routine/preview/exercise_log_listview.dart';

class RoutineLogScreen extends StatefulWidget {
  static const routeName = '/routine_log_screen';

  final String id;
  final bool isEditable;
  final bool showShareOnLoad;

  const RoutineLogScreen({
    super.key,
    required this.id,
    this.isEditable = true,
    this.showShareOnLoad = false,
  });

  @override
  State<RoutineLogScreen> createState() => _RoutineLogScreenState();
}

class _RoutineLogScreenState extends State<RoutineLogScreen> {
  bool _loading = false;
  final RoutineShareService _shareService = RoutineShareService();

  @override
  Widget build(BuildContext context) {
    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: true);

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackbar(
            context: context,
            message: exerciseAndRoutineController.errorMessage);
      });
    }

    // Reload log from controller on every build (in case it was updated)
    final log = exerciseAndRoutineController.logWhereId(id: widget.id);

    // If the log was deleted while this screen is visible, navigate back quietly
    if (log == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final navigator = Navigator.maybeOf(context);
          if (navigator != null && navigator.canPop()) {
            context.pop();
          }
        }
      });
      return const SizedBox.shrink();
    }

    // We only want to see all logged exercises and sets
    final completedExerciseLogs =
        loggedExercises(exerciseLogs: log.exerciseLogs);

    final updatedLog = log.copyWith(exerciseLogs: completedExerciseLogs);

    // Auto-share on load disabled

    final numberOfCompletedSets =
        completedExerciseLogs.expand((exerciseLog) => exerciseLog.sets);

    // Calculate personal bests
    final allHistoricalExerciseLogs =
        exerciseAndRoutineController.allExerciseLogs;
    final personalBests = calculatePersonalBests(
      currentLog: updatedLog,
      allHistoricalExerciseLogs: allHistoricalExerciseLogs,
    );

    final isCoach = AppConfig.isCoach;

    return Scaffold(
        appBar: AppBar(
            backgroundColor: appBarBackgroundColor(context: context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 28),
              onPressed: context.pop,
            ),
            actions: widget.isEditable && !isCoach
                ? [
                    IconButton(
                        onPressed: _showBottomSheet,
                        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical,
                            size: 22))
                  ]
                : null),
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                        spacing: 12,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              String? attribution;
                              if (updatedLog.templateId.isNotEmpty) {
                                final template = exerciseAndRoutineController
                                    .templateWhere(id: updatedLog.templateId);
                                if (template != null) {
                                  final plan = exerciseAndRoutineController
                                      .planWhere(id: template.planId);
                                  final isSystemTemplate =
                                      plan?.isSystemPlan ?? false;
                                  attribution = isSystemTemplate
                                      ? 'Not Athletes'
                                      : 'Created by you';
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    updatedLog.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      height: 1.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (attribution != null)
                                    Text(
                                      attribution,
                                      style: TextStyle(
                                        fontFamily: 'GroutpixFlow',
                                        color: Colors.blueGrey.shade400,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          ChipOne(
                              label: updatedLog.endTime.formattedDayMonthTime(),
                              child: CustomIcon(FontAwesomeIcons.calendarDay,
                                  color: Colors.deepOrange)),
                          // Removed routine-level notes; rely on per-exercise notes instead
                        ]),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 10,
                      children: [
                        _StatisticWidget(
                          title: "${completedExerciseLogs.length}",
                          subtitle: "Exercises",
                          icon: FontAwesomeIcons.personWalking,
                          information: _StatisticsInformation(
                              title: "Exercises",
                              description:
                                  "The total number of different exercises you completed in a workout session."),
                        ),
                        _StatisticWidget(
                          title: "${numberOfCompletedSets.length}",
                          subtitle: "Sets",
                          icon: FontAwesomeIcons.hashtag,
                          information: _StatisticsInformation(
                              title: "Sets",
                              description:
                                  "The number of rounds you performed for each exercise. A “set” consists of a group of repetitions (reps)."),
                        ),
                        _StatisticWidget(
                          title: volumeInKOrM(log.volume),
                          subtitle: "Volume",
                          icon: FontAwesomeIcons.weightHanging,
                          information: _StatisticsInformation(
                              title: "Volume",
                              description:
                                  "The total amount of work performed during a workout, typically calculated as: Volume = Sets × Reps × Weight."),
                        ),
                        _StatisticWidget(
                          title: updatedLog.duration().hmsDigital(),
                          subtitle: "Duration",
                          icon: FontAwesomeIcons.solidClock,
                          information: _StatisticsInformation(
                              title: "Duration",
                              description:
                                  "The total time you spent on your workout session, from start to finish."),
                        ),
                        if (personalBests.isNotEmpty)
                          _StatisticWidget(
                            title: "${personalBests.length}",
                            subtitle: "PBs",
                            icon: FontAwesomeIcons.trophy,
                            information: _StatisticsInformation(
                                title: "Personal Bests",
                                description:
                                    "The number of personal records you achieved in this workout compared to your previous workouts."),
                            onTap: () => _showPersonalBestsSheet(personalBests),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExerciseLogListView(
                            exerciseLogs: completedExerciseLogs),
                        const SizedBox(
                          height: 60,
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }

  void _showBottomSheet() {
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.share, size: 18),
              horizontalTitleGap: 6,
              title: const Text("Share summary"),
              onTap: () => _showSharePreview(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const FaIcon(FontAwesomeIcons.solidPenToSquare, size: 18),
              horizontalTitleGap: 6,
              title: Text("Edit Log"),
              onTap: _editLog,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.solidClock, size: 18),
              horizontalTitleGap: 6,
              title: Text("Edit duration"),
              onTap: _editDuration,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.trash,
                size: 18,
                color: Colors.red,
              ),
              horizontalTitleGap: 6,
              title: Text("Delete log",
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                      fontSize: 16)),
              onTap: _deleteLog,
            ),
          ]),
        ));
  }

  void _showPersonalBestsSheet(List<PersonalBest> personalBests) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      useBlurredTransparentBackground: true,
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          final pageController = PageController(viewportFraction: 0.9);
          final currentPage = ValueNotifier<int>(0);
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "PBs",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          Expanded(
                            child: PageView.builder(
                              controller: pageController,
                              itemCount: personalBests.length,
                              onPageChanged: (index) {
                                currentPage.value = index;
                              },
                              itemBuilder: (context, index) {
                                final pb = personalBests[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: SizedBox(
                                    child: _PersonalBestCard(pb: pb),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          ValueListenableBuilder<int>(
                            valueListenable: currentPage,
                            builder: (context, page, _) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  personalBests.length,
                                  (index) => Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: page == index
                                          ? Theme.of(context)
                                              .colors
                                              .vibrantAccent
                                          : Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLoadingScreen() {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _editLog() async {
    Navigator.of(context).pop();
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log != null) {
      final copyOfLog = log.copyWith();
      final arguments = RoutineLogArguments(
          log: copyOfLog, editorMode: RoutineEditorMode.edit);
      await navigateToRoutineEditorAndReturnLog(
          context: context, arguments: arguments);
      // No need to update state - controller will notify listeners
      if (mounted) {
        _showBottomSheet();
      }
    }
  }

  void _editDuration() {
    Navigator.of(context).pop();
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log != null) {
      showSessionDurationSelectorBottomSheet(
        context: context,
        initialStartTime: log.startTime,
        initialEndTime: log.endTime,
        onConfirm: (start, end) async {
          final updatedLog = log.copyWith(startTime: start, endTime: end);
          await Provider.of<SupabaseExerciseAndRoutineController>(context,
                  listen: false)
              .updateLog(log: updatedLog);
          if (mounted) {
            _showBottomSheet();
          }
        },
      );
    }
  }

  void _doDeleteLog() async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log != null) {
      if (AppConfig.isCoach) showCoachLoadingOverlay(context);
      try {
        await controller.removeLog(log: log);
        if (mounted) {
          context.pop();
        }
      } catch (_) {
        if (mounted) {
          showSnackbar(
              context: context,
              message: "Oops, we are unable to delete this log");
        }
      } finally {
        if (AppConfig.isCoach) {
          if (mounted) hideCoachLoadingOverlay(context);
        } else {
          _hideLoadingScreen();
        }
      }
    }
  }

  void _deleteLog() {
    Navigator.of(context).pop(); // Close the previous BottomSheet
    showBottomSheetWithSingleAction(
        context: context,
        title: "Delete log?",
        description: "Are you sure you want to delete this log?",
        action: () {
          Navigator.of(context).pop(); // Close current BottomSheet
          if (!AppConfig.isCoach) _showLoadingScreen();
          _doDeleteLog();
        },
        actionLabel: 'Delete',
        isDestructive: true);
  }

  // PBs bottom sheet removed

  Future<bool> _shareLog({
    required RoutineLogDto log,
    ShareVariant variant = ShareVariant.standard,
  }) async {
    try {
      final exerciseAndRoutineController =
          Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false);
      final allHistoricalExerciseLogs =
          exerciseAndRoutineController.allExerciseLogs;
      final completedExerciseLogs =
          loggedExercises(exerciseLogs: log.exerciseLogs);
      final updatedLog = log.copyWith(exerciseLogs: completedExerciseLogs);
      final pbs = calculatePersonalBests(
        currentLog: updatedLog,
        allHistoricalExerciseLogs: allHistoricalExerciseLogs,
      );
      await _shareService.shareRoutineLog(
          context: context, log: log, variant: variant, personalBests: pbs);
      return true;
    } catch (e, st) {
      debugPrint('Share failed: $e\n$st');
      if (mounted) {
        showSnackbar(
          context: context,
          message: "Could not share this session. Please try again.",
        );
      }
      return false;
    }
  }

  void _showSharePreview() {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);
    if (log == null) return;

    final completedExerciseLogs =
        loggedExercises(exerciseLogs: log.exerciseLogs);
    final updatedLog = log.copyWith(exerciseLogs: completedExerciseLogs);
    final allHistoricalExerciseLogs = controller.allExerciseLogs;
    final pbs = calculatePersonalBests(
      currentLog: updatedLog,
      allHistoricalExerciseLogs: allHistoricalExerciseLogs,
    );

    final summary =
        ShareableRoutineSummary.fromRoutineLog(log, personalBests: pbs);
    final pageController = PageController();
    int selectedVariant = 0;
    final isSharing = ValueNotifier<bool>(false);

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      useBlurredTransparentBackground: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Share preview",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: PageView(
                          controller: pageController,
                          onPageChanged: (index) {
                            setModalState(() {
                              selectedVariant = index;
                            });
                          },
                          children: [
                            ShareableRoutineVerticalCard(summary: summary),
                            ShareableRoutineVerticalCardDurationSplit(
                                summary: summary),
                            ShareableRoutineVerticalCardDurationSplitCentered(
                                summary: summary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: List.generate(
                    3,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == selectedVariant
                            ? Theme.of(context).colors.vibrantAccent
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isSharing,
                    builder: (context, sharing, _) {
                      return SizedBox(
                        width: 240,
                        child: OpacityButtonWidgetTwo(
                          solidBackground: true,
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                          showArrowRight: false,
                          label: sharing ? "Sharing…" : "Share",
                          onPressed: sharing
                              ? null
                              : () async {
                                  final variant = switch (selectedVariant) {
                                    0 => ShareVariant.standard,
                                    1 => ShareVariant.durationSplit,
                                    _ => ShareVariant.durationSplitCentered,
                                  };
                                  isSharing.value = true;
                                  try {
                                    final success = await _shareLog(
                                        log: log, variant: variant);
                                    if (!context.mounted) return;
                                    if (success) Navigator.of(context).pop();
                                  } finally {
                                    if (context.mounted) {
                                      isSharing.value = false;
                                    }
                                  }
                                },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PersonalBestCard extends StatelessWidget {
  final PersonalBest pb;

  const _PersonalBestCard({required this.pb});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weightUnitLabel = weightUnit().toUpperCase();

    final gradientColors = [
      Colors.black.withValues(alpha: 0.55),
      Colors.black.withValues(alpha: 0.35),
    ];
    final accent = theme.colors.vibrantAccent;

    return SizedBox(
      width: double.infinity,
      height: 170,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.08,
                    child: Image.asset(
                      'images/1k_Dissolve_Noise_Texture.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            pb.exerciseName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            pb.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _formatPbValue(pb,
                                weightUnitLabel: weightUnitLabel),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w400,
                              color: accent,
                            ),
                          ),
                          Icon(
                            FontAwesomeIcons.trophy,
                            size: 16,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPbValue(
    PersonalBest pb, {
    required String weightUnitLabel, // e.g. "kg" or "lb"
  }) {
    switch (pb.exerciseType) {
      case ExerciseType.weights:
        return _formatWeightPb(pb, weightUnitLabel);

      case ExerciseType.bodyWeight:
        return '${pb.reps ?? 0} reps';

      case ExerciseType.duration:
        return (pb.duration ?? Duration.zero).hmsDigital();

      case ExerciseType.none:
        return '';
    }
  }

  String _formatWeightPb(
    PersonalBest pb,
    String weightUnitLabel,
  ) {
    switch (pb.kind) {
      case PersonalBestKind.heaviestWeight:
        return _formatWeightFromKg(pb.weightKg, weightUnitLabel);

      case PersonalBestKind.heaviestVolume:
        final weight = _formatWeightFromKg(pb.weightKg, weightUnitLabel);
        final reps = pb.reps ?? 0;
        return '$weight × $reps';

      case PersonalBestKind.mostReps:
        return '${pb.reps ?? 0} reps';

      case PersonalBestKind.longestDuration:
        // Should never happen for weights, but keep safe
        return '';
    }
  }

  String _formatWeightFromKg(
    double? weightKg,
    String weightUnitLabel,
  ) {
    if (weightKg == null || weightKg <= 0) return '';

    // Existing helper: converts KG → user unit
    final converted = weightWithConversion(value: weightKg);

    final formatted = converted.truncateToDouble() == converted
        ? converted.toStringAsFixed(0)
        : converted.toStringAsFixed(1);

    return '$formatted $weightUnitLabel';
  }
}

class _StatisticsInformation {
  final String title;
  final String description;

  _StatisticsInformation({required this.title, required this.description});
}

class _StatisticWidget extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final _StatisticsInformation information;
  final VoidCallback? onTap;

  const _StatisticWidget(
      {this.icon,
      required this.title,
      required this.subtitle,
      required this.information,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use the same blue gradient for all statistics cards
    final gradientColors = [
      const Color(0xFF3b82f6).withValues(alpha: 0.3),
      const Color(0xFF60a5fa).withValues(alpha: 0.2),
      Colors.black.withValues(alpha: 0.5),
    ];

    final tapHandler = onTap ??
        () => showBottomSheetWithNoAction(
            context: context,
            title: information.title,
            description: information.description);

    return GestureDetector(
      onTap: tapHandler,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(minWidth: 120),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Stack(
              children: [
                // Texture overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(
                      'images/1k_Dissolve_Noise_Texture.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon and label row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            FaIcon(
                              icon,
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              subtitle.toUpperCase(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                letterSpacing: 0.5,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Large number - no overflow for duration
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
