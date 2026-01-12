import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/search_bar.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/appsync/exercise_dto.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/system_exercises.dart';
import '../../../utils/name_notes_bottom_sheet.dart';
import '../../../widgets/empty_states/list_empty_state.dart';
import '../../../widgets/exercise/exercise_grid_item.dart';

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
  List<ExerciseDto> _systemExercises = [];

  /// Simple relevance scoring:
  /// +2 if name contains the query part
  /// +1 if any token starts with the query part
  double _calculateRelevanceScore(
      ExerciseDto exercise, List<String> queryParts) {
    if (queryParts.isEmpty) return 0;

    final name = exercise.name.toLowerCase();
    final tokens =
        name.split(RegExp(r'[\s-]+')).where((t) => t.isNotEmpty).toList();

    double score = 0;
    for (final part in queryParts) {
      final q = part.toLowerCase();
      if (name.contains(q)) {
        score += 2;
        continue;
      }
      if (tokens.any((t) => t.startsWith(q))) {
        score += 1;
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
    final excludeExerciseIds = widget.excludeExercises.map((e) => e.id).toSet();

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    // Combine system (from JSON) + user (from DB)
    final combined = [
      ..._systemExercises,
      ...controller.exercises,
    ];

    final allExercises = combined
        .where((exercise) => !excludeExerciseIds.contains(exercise.id))
        .toList();

    // Filter by exercise type if provided
    List<ExerciseDto> filteredExercises;
    if (exerciseType != null) {
      filteredExercises =
          allExercises.where((ex) => ex.type == exerciseType).toList();
    } else {
      filteredExercises = allExercises;
    }

    // If the user typed nothing, sort alphabetically
    if (queryParts.isEmpty) {
      filteredExercises.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _filteredExercises = filteredExercises;
      });
      return;
    }

    final ranked = filteredExercises
        .map((ex) => (exercise: ex, score: _calculateRelevanceScore(ex, queryParts)))
        .where((e) => e.score > 0)
        .toList();

    ranked.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.exercise.name.compareTo(b.exercise.name);
    });

    setState(() {
      _filteredExercises = ranked.map((e) => e.exercise).toList();
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

  Future<void> _promptLogTypeAndReturn(ExerciseDto exercise) async {
    final chosen = await showModalBottomSheet<ExerciseType>(
      context: context,
      backgroundColor: Colors.black87,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "How do you want to log this?",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  "Choose how you want to log what you've done for this exercise.",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Image.asset(
                    'icons/dumbbells.png',
                    height: 24,
                    width: 24,
                    color: Colors.white70,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.fitness_center,
                          color: Colors.white70);
                    },
                  ),
                  title: const Text("Weights + Reps"),
                  subtitle: const Text("Log weights and repetitions"),
                  onTap: () => Navigator.pop(context, ExerciseType.weights),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const FaIcon(FontAwesomeIcons.hashtag,
                      color: Colors.white70),
                  title: const Text("Reps only"),
                  subtitle: const Text("Log only reps"),
                  onTap: () => Navigator.pop(context, ExerciseType.bodyWeight),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer, color: Colors.white70),
                  title: const Text("Duration"),
                  subtitle: const Text("Log duration"),
                  onTap: () => Navigator.pop(context, ExerciseType.duration),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (chosen != null) {
      _navigateBackWithSelectedExercise(exercise.copyWith(type: chosen));
    }
  }

  void _dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  void _navigateToExerciseHistory(ExerciseDto exercise) async {
    _dismissKeyboard(context);
    await navigateToExerciseHome(context: context, exercise: exercise);
    setState(() {
      _loadOrSyncExercises();
    });
  }

  Future<void> _showCreateExerciseSheet() async {
    final details = await showNameNotesBottomSheet(
      context: context,
      title: 'Create exercise',
      primaryButtonLabel: 'Create',
      emptyNameMessage: 'Please provide a name for this exercise',
    );
    if (details == null) return;

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
                            context,
                            listen: false);
                    final newExercise = ExerciseDto(
      name: details.name,
      notes: details.notes,
                      type: ExerciseType.weights,
                    );
                    await controller.saveExercise(exerciseDto: newExercise);
                    _loadOrSyncExercises();
  }

  @override
  Widget build(BuildContext context) {
    // Get all exercises for grid
    final allExercises = _filteredExercises;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: UniqueKey(),
        backgroundColor: themeGradient(context: context).colors.first,
        elevation: 8.0,
        onPressed: _showCreateExerciseSheet,
        child: const FaIcon(FontAwesomeIcons.plus, size: 24),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(top: 20),
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
                          // Slightly higher aspect ratio so cards feel a bit
                          // smaller/less tall while keeping readability.
                          childAspectRatio: 0.9,
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
                          );
                        },
                      ),
                    )
                  : Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const ListEmptyState(
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

  /// Handle exercise tap - show bottom sheet with context-aware options
  /// - If readOnly = false (from session/template): Show "Add to workout" and "View history"
  /// - If readOnly = true (from settings): Show only "View history"
  void _handleExerciseTap(ExerciseDto exercise) {
    _dismissKeyboard(context);
    _showExerciseOptionsBottomSheet(exercise);
  }

  void _showExerciseOptionsBottomSheet(ExerciseDto exercise) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                exercise.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (!widget.readOnly) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(FontAwesomeIcons.circlePlus, size: 22),
                horizontalTitleGap: 6,
                title: const Text("Add to workout"),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _promptLogTypeAndReturn(exercise);
                },
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.circleInfo, size: 20),
              horizontalTitleGap: 6,
              title: const Text("View exercise information"),
              onTap: () {
                Navigator.of(context).pop();
                _navigateToExerciseHistory(exercise);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _loadOrSyncExercises() {
    _loadSystemExercises().then((_) {
      final exerciseType = widget.type;
      final excludeExerciseIds =
          widget.excludeExercises.map((e) => e.id).toSet();

      final controller = Provider.of<SupabaseExerciseAndRoutineController>(
          context,
          listen: false);

      final combined = [
        ..._systemExercises,
        ...controller.exercises,
      ];

      _filteredExercises = combined
          .where((exercise) => !excludeExerciseIds.contains(exercise.id))
          .where((exercise) =>
              exerciseType != null ? exercise.type == widget.type : true)
          .toList();

      _runSearch();
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadOrSyncExercises();
  }

  Future<void> _loadSystemExercises() async {
    final seeds = await loadLottieExercises();
    _systemExercises = seeds
        .map(
          (s) => ExerciseDto(
            id: s.id,
            name: s.name,
            type: ExerciseType.weights,
            notes: '',
            isSystem: s.isSystem,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Using shared InfoBanner
