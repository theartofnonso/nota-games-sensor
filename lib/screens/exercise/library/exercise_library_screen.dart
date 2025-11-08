import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/widgets/search_bar.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/appsync/exercise_dto.dart';
import '../../../enums/muscle_group_enums.dart';
import '../../../utils/date_utils.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../widgets/buttons/opacity_button_widget.dart';
import '../../../widgets/empty_states/no_list_empty_state.dart';
import '../../../widgets/exercise/exercise_widget.dart';
import '../../editors/exercise_editor_screen.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final bool readOnly;
  final List<ExerciseDto> excludeExercises;
  final ExerciseType? type;

  const ExerciseLibraryScreen(
      {super.key,
      this.readOnly = false,
      this.excludeExercises = const [],
      this.type});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  late TextEditingController _searchController;

  final List<MuscleGroup> _selectedMuscleGroups = [];

  /// Holds a list of [ExerciseDto] when filtering through a search
  List<ExerciseDto> _filteredExercises = [];

  /// Holds a list of [ExerciseDto] that has been recently logged
  late List<ExerciseDto> _recentExercises; // injected

  /// Search through the list of exercises
  ///
  /// Calculates a 'relevance' score for an ExerciseDto based on the query parts.
  double _calculateRelevanceScore(
      ExerciseDto exercise, List<String> queryParts) {
    // Convert exercise name to lowercase for case-insensitive matching
    final exerciseName = exercise.name.toLowerCase();

    // You can split the exercise name on spaces/hyphens if you want more granularity
    final exerciseNameParts = exerciseName.split(RegExp(r'[\s-]+'));

    double score = 0.0;

    for (final queryPart in queryParts) {
      // Exact substring match => add 1 point
      if (exerciseName.contains(queryPart)) {
        score += 1.0;
      }

      //If you want to reward startsWith more strongly, you could do:
      for (final part in exerciseNameParts) {
        if (part.startsWith(queryPart)) {
          score += 0.5; // for instance, half a point for startsWith
        }
      }
    }

    return score;
  }

  void _runSearch() {
    final query = _searchController.text.trim().toLowerCase();
    final exerciseType = widget.type;

    // Split on whitespace or hyphens to handle multiple words/phrases
    final queryParts =
        query.split(RegExp(r'[\s-]+')).where((q) => q.isNotEmpty).toList();

    // Get the list of all exercises (excluding any you want to filter out by default)
    final allExercises = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .exercises
        .where((exercise) => !widget.excludeExercises.contains(exercise))
        .toList();

    // Filter by exercise type if provided
    List<ExerciseDto> filteredExercises;
    if (exerciseType != null) {
      filteredExercises =
          allExercises.where((ex) => ex.type == exerciseType).toList();
    } else {
      filteredExercises = allExercises;
    }

    // Filter by muscle groups if any are selected
    if (_selectedMuscleGroups.isNotEmpty) {
      filteredExercises = filteredExercises
          .where((ex) => _selectedMuscleGroups.contains(ex.primaryMuscleGroup))
          .toList();
    }

    // If the user typed nothing, you can simply show the entire filtered list
    // Or skip ranking and set directly — depends on your UI needs
    if (queryParts.isEmpty) {
      filteredExercises.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _filteredExercises = filteredExercises;
      });
      return;
    }

    // Compute a relevance score for each exercise, then sort descending by score
    final rankedList = filteredExercises
        .map((ex) {
          final score = _calculateRelevanceScore(ex, queryParts);
          return (exercise: ex, score: score);
        })
        .where((tuple) =>
            tuple.score > 0) // optional: only keep those with some match
        .toList();

    rankedList.sort((a, b) => b.score.compareTo(a.score));

    // Extract the exercises from the sorted list
    final sortedExercises = rankedList.map((tuple) => tuple.exercise).toList();

    setState(() {
      _filteredExercises = sortedExercises;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _runSearch();
  }

  /// Select an exercise
  void _navigateBackWithSelectedExercise(ExerciseDto selectedExercise) {
    Navigator.of(context).pop([selectedExercise]);
  }

  void _dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  void _navigateToExerciseEditor() async {
    await navigateWithSlideTransition(
        context: context, child: ExerciseEditorScreen());
    setState(() {
      _loadOrSyncExercises();
    });
  }

  void _navigateToExerciseHistory(ExerciseDto exercise) async {
    _dismissKeyboard(context);
    await navigateToExerciseHome(context: context, exercise: exercise);
    setState(() {
      _loadOrSyncExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final muscleGroups = MuscleGroup.sortedValues
        .map((muscleGroup) => Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: OpacityButtonWidget(
                  onPressed: () =>
                      _onSelectMuscleGroup(newMuscleGroup: muscleGroup),
                  buttonColor: _getMuscleGroup(muscleGroup: muscleGroup) != null
                      ? Theme.of(context).colors.vibrantAccent
                      : null,
                  label: muscleGroup.displayName.toUpperCase()),
            ))
        .toList();

    final muscleGroupScrollViewHalf = MuscleGroup.values.length ~/ 2;

    // —— Partition list into segments ——
    final (recents, others) = _partitionExercises();

    // Build the child list with headers
    final listChildren = <Widget>[];
    if (recents.isNotEmpty) {
      listChildren
        ..add(_buildHeader('Found in recent logs', isDarkMode: isDarkMode))
        ..addAll(recents.map((e) => ExerciseWidget(
              exerciseDto: e,
              onNavigateToExercise: _navigateToExerciseHistory,
              onSelect:
                  widget.readOnly ? null : _navigateBackWithSelectedExercise,
            )));
    }
    if (others.isNotEmpty) {
      listChildren
        ..add(_buildHeader('All Exercises', isDarkMode: isDarkMode))
        ..addAll(others.map((e) => ExerciseWidget(
              exerciseDto: e,
              onNavigateToExercise: _navigateToExerciseHistory,
              onSelect:
                  widget.readOnly ? null : _navigateBackWithSelectedExercise,
            )));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text("Exercise Library".toUpperCase()),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: _navigateToExerciseEditor,
              icon: const FaIcon(FontAwesomeIcons.solidSquarePlus)),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise library nudges removed
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: CSearchBar(
                    hintText: "Search library",
                    onChanged: (_) => _runSearch(),
                    onClear: _clearSearch,
                    controller: _searchController),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ...muscleGroups.sublist(0, muscleGroupScrollViewHalf),
                  ])),
              SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ...muscleGroups.sublist(muscleGroupScrollViewHalf),
                  ])),
              const SizedBox(height: 18),
              listChildren.isNotEmpty
                  ? Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.0),
                        child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 250),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemBuilder: (ctx, idx) => listChildren[idx],
                            separatorBuilder: (ctx, idx) =>
                                (listChildren[idx] is ExerciseWidget)
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14.0),
                                        child: Divider(
                                          height: 0.5,
                                          color: isDarkMode
                                              ? Theme.of(context)
                                                  .colors
                                                  .dividerColor
                                              : Colors.grey.shade200,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                            // no separator after headers
                            itemCount: listChildren.length),
                      ),
                    )
                  : Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const NoListEmptyState(
                            message:
                                "It might feel quiet now, but exercises including yours will soon appear here."),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────
  /// Returns two lists: `recent` and `others` (order preserved inside each).
  (List<ExerciseDto> recents, List<ExerciseDto> others) _partitionExercises() {
    if (_recentExercises.isEmpty) return (<ExerciseDto>[], _filteredExercises);

    final recentIds = _recentExercises.map((e) => e.id).toSet();

    final recent = <ExerciseDto>[];
    final others = <ExerciseDto>[];

    for (final ex in _filteredExercises) {
      (recentIds.contains(ex.id) ? recent : others).add(ex);
    }
    return (recent, others);
  }

  Widget _buildHeader(String label, {required bool isDarkMode}) => Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontSize: 16)
              .copyWith(
                color: isDarkMode ? Colors.white70 : Colors.blueGrey,
              ),
        ),
      );

  void _loadOrSyncExercises() {
    final exerciseType = widget.type;

    _filteredExercises = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .exercises
        .where((exercise) => !widget.excludeExercises.contains(exercise))
        .where((exercise) =>
            exerciseType != null ? exercise.type == widget.type : true)
        .toList();

    _runSearch();
  }

  void _onSelectMuscleGroup({required MuscleGroup newMuscleGroup}) {
    final oldMuscleGroup = _selectedMuscleGroups.firstWhereOrNull(
        (previousMuscleGroup) => previousMuscleGroup == newMuscleGroup);
    setState(() {
      if (oldMuscleGroup != null) {
        _selectedMuscleGroups.remove(oldMuscleGroup);
      } else {
        _selectedMuscleGroups.add(newMuscleGroup);
      }
      _runSearch();
    });
  }

  MuscleGroup? _getMuscleGroup({required MuscleGroup muscleGroup}) =>
      _selectedMuscleGroups.firstWhereOrNull(
          (previousMuscleGroup) => previousMuscleGroup == muscleGroup);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadOrSyncExercises();

    final dateRange = lastQuarterDateTimeRange();

    final allRecentExercises =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
                listen: false)
            .whereLogsIsWithinRange(range: dateRange)
            .expand((log) => log.exerciseLogs)
            .map((exerciseLog) => exerciseLog.exercise);

    // Remove duplicates by converting to Set and back to List based on exercise ID
    final seenIds = <String>{};
    _recentExercises = allRecentExercises
        .where((exercise) => seenIds.add(exercise.id))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Using shared InfoBanner
