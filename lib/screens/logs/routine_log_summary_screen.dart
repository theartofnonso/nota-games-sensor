import 'package:collection/collection.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:tracker_app/enums/routine_preview_type_enum.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/general_utils.dart';
import 'package:tracker_app/widgets/shareables/pbs_shareable.dart';
import 'package:tracker_app/widgets/shareables/routine_log_shareable_lite.dart';
import 'package:tracker_app/widgets/shareables/session_milestone_shareable.dart';

import '../../colors.dart';
import '../../controllers/exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../urls.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/routine_utils.dart';
import '../../utils/shareables_utils.dart';
import '../../widgets/dividers/label_divider.dart';

class RoutineLogSummaryScreen extends StatefulWidget {
  static const routeName = '/routine_log_summary_screen';

  final RoutineLogDto log;

  const RoutineLogSummaryScreen({super.key, required this.log});

  @override
  State<RoutineLogSummaryScreen> createState() =>
      _RoutineLogSummaryScreenState();
}

class _RoutineLogSummaryScreenState extends State<RoutineLogSummaryScreen> {
  bool _hasImage = false;

  Image? _image;

  final _pageController = PageController(viewportFraction: 1);

  final _confettiController = ConfettiController();

  bool isMultipleOfFive(int number) {
    return number == 0 ? false : number % 5 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final updatedExerciseLogs =
        loggedExercises(exerciseLogs: widget.log.exerciseLogs);

    final updatedLog = widget.log.copyWith(exerciseLogs: updatedExerciseLogs);

    final exerciseAndRoutineController =
        Provider.of<ExerciseAndRoutineController>(context, listen: true);
    List<RoutineLogDto> routineLogsForTheYear = exerciseAndRoutineController
        .whereLogsIsSameYear(dateTime: DateTime.now().withoutTime());

    final muscleGroupFamilyFrequencyData =
        muscleGroupFrequency(exerciseLogs: updatedLog.exerciseLogs);

    List<Widget> pbShareAssets = [];
    final pbShareAssetsKeys = [];

    for (final exerciseLog in updatedLog.exerciseLogs) {
      final pastExerciseLogs =
          exerciseAndRoutineController.whereExerciseLogsBefore(
              exercise: exerciseLog.exercise, date: exerciseLog.createdAt);
      final pbs = calculatePBs(
          pastExerciseLogs: pastExerciseLogs,
          exerciseType: exerciseLog.exercise.type,
          exerciseLog: exerciseLog);
      final setAndPBs = groupBy(pbs, (pb) => pb.set);
      for (final setAndPB in setAndPBs.entries) {
        final pbs = setAndPB.value;
        for (final pb in pbs) {
          final key = GlobalKey();
          final shareable = PBsShareable(
              set: setAndPB.key, pbDto: pb, globalKey: key, image: _image);
          pbShareAssets.add(shareable);
          pbShareAssetsKeys.add(key);
        }
      }
    }

    final pages = [
      if (isMultipleOfFive(routineLogsForTheYear.length))
        SessionMilestoneShareable(
            label: "${routineLogsForTheYear.length}th", image: _image),
      ...pbShareAssets,
      RoutineLogShareableLite(
          log: updatedLog,
          frequencyData: muscleGroupFamilyFrequencyData,
          pbs: pbShareAssets.length,
          image: _image),
    ];

    final pagesKeys = [
      if (isMultipleOfFive(routineLogsForTheYear.length))
        sessionMilestoneGlobalKey,
      ...pbShareAssetsKeys,
      routineLogGlobalKey,
    ];

    return Stack(alignment: Alignment.topCenter, children: [
      Scaffold(
        floatingActionButton: FloatingActionButton(
            heroTag: "routine_log_screen",
            onPressed: () {
              final index = _pageController.page!.toInt();
              final key = pagesKeys[index];
              _showShareAction(key: key);
            },
            child: const FaIcon(FontAwesomeIcons.rocket)),
        appBar: AppBar(
          backgroundColor: appBarBackgroundColor(context: context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.squareXmark, size: 28),
            onPressed: context.pop,
          ),
          title: Text("Share".toUpperCase()),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.camera, size: 24),
              onPressed: _showBottomSheet,
            ),
            IconButton(
              icon: const FaIcon(Icons.copy_rounded, size: 24),
              onPressed: _showCopyBottomSheet,
            )
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: themeGradient(context: context)),
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                AspectRatio(
                  aspectRatio: 1,
                  child: PageView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: _pageController,
                    itemCount: pages.length,
                    itemBuilder: (_, index) {
                      return pages[index % pages.length];
                    },
                  ),
                ),
                const Spacer(),
                SmoothPageIndicator(
                  controller: _pageController,
                  count: pages.length,
                  effect:
                      const ExpandingDotsEffect(activeDotColor: vibrantGreen),
                ),
              ],
            ),
          ),
        ),
      ),
      ConfettiWidget(
          minBlastForce: 10,
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive)
    ]);
  }

  void _showShareAction({required GlobalKey key}) {
    captureImage(key: key, pixelRatio: 3.5).then((result) {
      if (context.mounted) {
        if (result.status == ShareResultStatus.success) {
          Posthog().capture(
              eventName:
                  PostHogAnalyticsEvent.shareRoutineLogSummary.displayName);
          if (mounted) {
            showSnackbar(context: context, message: "Content Shared");
          }
        }
      }
    });
  }

  void _showCopyBottomSheet() {
    final listOfCompletedExercises =
        loggedExercises(exerciseLogs: widget.log.exerciseLogs);

    final updatedLog =
        widget.log.copyWith(exerciseLogs: listOfCompletedExercises);

    final workoutLogLink = "$shareableRoutineLogUrl/${updatedLog.id}";
    final workoutLogText = copyRoutineAsText(
        routineType: RoutinePreviewType.log,
        name: updatedLog.name,
        notes: updatedLog.notes,
        exerciseLogs: updatedLog.exerciseLogs);

    displayBottomSheet(
        context: context,
        isScrollControlled: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.link,
              size: 18,
            ),
            horizontalTitleGap: 10,
            title: Text(
              "Copy as Link",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    overflow: TextOverflow.ellipsis,
                  ),
              maxLines: 1,
            ),
            subtitle: Text(workoutLogLink),
            onTap: () {
              Posthog().capture(
                  eventName:
                      PostHogAnalyticsEvent.shareRoutineLogAsLink.displayName);
              HapticFeedback.heavyImpact();
              final data = ClipboardData(text: workoutLogLink);
              Clipboard.setData(data).then((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                  showSnackbar(
                      context: context, message: "Workout log link copied");
                }
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.copy,
              size: 18,
            ),
            horizontalTitleGap: 6,
            title: Text("Copy as Text",
                style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text("${updatedLog.name}..."),
            onTap: () {
              Posthog().capture(
                  eventName:
                      PostHogAnalyticsEvent.shareRoutineLogAsText.displayName);
              HapticFeedback.heavyImpact();
              final data = ClipboardData(text: workoutLogText);
              Clipboard.setData(data).then((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                  showSnackbar(context: context, message: "Workout log copied");
                }
              });
            },
          ),
        ]));
  }

  void _showBottomSheet() {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    displayBottomSheet(
        context: context,
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.camera, size: 18),
            horizontalTitleGap: 6,
            title: Text("Camera"),
            onTap: () => _pickFromLibrary(camera: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.images, size: 18),
            horizontalTitleGap: 6,
            title: Text("Library"),
            onTap: () => _pickFromLibrary(camera: false),
          ),
          if (_hasImage)
            Column(children: [
              const SizedBox(
                height: 10,
              ),
              LabelDivider(
                label: "Don't like the vibe?",
                labelColor: isDarkMode ? Colors.white70 : Colors.black,
                dividerColor: sapphireLighter,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Remove Image",
                    style: GoogleFonts.ubuntu(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 16)),
                onTap: _removeImage,
              ),
            ])
        ]));
  }

  void _pickFromLibrary({required bool camera}) async {
    Navigator.of(context).pop();
    final ImagePicker picker = ImagePicker();
    final XFile? xFile = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery);
    if (xFile != null) {
      final Uint8List bytes = await xFile.readAsBytes();
      setState(() {
        _image = Image.memory(bytes);
        _hasImage = true;
      });
    }
  }

  void _removeImage() {
    Navigator.of(context).pop();
    setState(() {
      _image = null;
      _hasImage = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}
