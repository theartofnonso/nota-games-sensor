import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/widgets/search_bar.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/appsync/exercise_dto.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../widgets/empty_states/no_list_empty_state.dart';
import '../../../widgets/exercise/exercise_grid_item.dart';
import '../../editors/exercise_editor_screen.dart';

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

  /// Holds a list of [ExerciseDto] when filtering through a search
  List<ExerciseDto> _filteredExercises = [];

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
    // Get all exercises for grid
    final allExercises = _filteredExercises;

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
              const SizedBox(height: 18),
              allExercises.isNotEmpty
                  ? Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 250),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: allExercises.length,
                        itemBuilder: (context, index) {
                          final exercise = allExercises[index];
                          return ExerciseGridItem(
                            exercise: exercise,
                            onTap: () => _handleExerciseTap(exercise),
                            onLongPress: widget.readOnly
                                ? null
                                : () => _navigateToExerciseHistory(exercise),
                          );
                        },
                      ),
                    )
                  : Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const NoListEmptyState(
                            message:
                                "No exercises yet. Create your first exercise to get started."),
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

  /// Handle exercise tap based on context
  /// - If readOnly = false (from session/template):
  ///   * Tap = Add to selection
  ///   * Long press = View exercise history
  /// - If readOnly = true (from settings):
  ///   * Tap = Navigate to exercise history
  void _handleExerciseTap(ExerciseDto exercise) {
    _dismissKeyboard(context);

    if (widget.readOnly) {
      // From settings - tap navigates to exercise history
      _navigateToExerciseHistory(exercise);
    } else {
      // From session/template - tap adds exercise to selection
      _navigateBackWithSelectedExercise(exercise);
    }
  }

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadOrSyncExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Using shared InfoBanner
