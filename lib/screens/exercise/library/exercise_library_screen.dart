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
import '../../../widgets/empty_states/list_empty_state.dart';
import '../../../widgets/exercise/exercise_grid_item.dart';

/// Purpose when selecting an exercise from the library.
enum ExerciseSelectionPurpose {
  /// Add to workout/template (prompts log type).
  addToWorkout,

  /// View-only (settings, etc.) – no selection.
  viewOnly,

  /// Select for AI chat – tap returns exercise immediately for query scoping.
  forAiQuery,
}

class ExerciseLibraryScreen extends StatefulWidget {
  final bool readOnly;
  final List<ExerciseDto> excludeExercises;
  final ExerciseType? type;
  final ExerciseSelectionPurpose selectionPurpose;

  const ExerciseLibraryScreen(
      {super.key,
      this.readOnly = false,
      this.excludeExercises = const [],
      this.type,
      this.selectionPurpose = ExerciseSelectionPurpose.addToWorkout});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  late TextEditingController _searchController;

  /// Exercises from logs, sorted by most recent use. Filtered by search/type/exclude.
  List<ExerciseDto> _recentFromLogs = [];

  /// All other exercises in the library (not in logs). Filtered by search/type/exclude.
  List<ExerciseDto> _libraryOnly = [];
  List<ExerciseDto> _systemExercises = [];

  /// Multi-select: selected exercises for forAiQuery (order preserved).
  final List<ExerciseDto> _selectedExercises = [];

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

    // Library is system-defined only (no custom exercise CRUD).
    final allExercises = _systemExercises
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
    } else {
      final ranked = filteredExercises
          .map((ex) => (
                exercise: ex,
                score: _calculateRelevanceScore(ex, queryParts),
              ))
          .where((e) => e.score > 0)
          .toList();
      ranked.sort((a, b) {
        final cmp = b.score.compareTo(a.score);
        if (cmp != 0) return cmp;
        return a.exercise.name.compareTo(b.exercise.name);
      });
      filteredExercises = ranked.map((e) => e.exercise).toList();
    }

    // Split: exercises from logs (recent first) vs rest of library. No overlap.
    final recentOrdered = controller.exercisesFromLogsOrderedByRecency;
    final recentIds = recentOrdered.map((e) => e.id).toSet();
    final recencyIndex = {
      for (var i = 0; i < recentOrdered.length; i++) recentOrdered[i].id: i,
    };

    final libraryIds = allExercises.map((e) => e.id).toSet();
    final recent = filteredExercises
        .where((e) => recentIds.contains(e.id))
        .where((e) => libraryIds.contains(e.id))
        .toList()
      ..sort((a, b) =>
          (recencyIndex[a.id] ?? 9999).compareTo(recencyIndex[b.id] ?? 9999));
    final library =
        filteredExercises.where((e) => !recentIds.contains(e.id)).toList();

    setState(() {
      _recentFromLogs = recent;
      _libraryOnly = library;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _runSearch();
  }

  /// Return selected exercise(s) to caller. For forAiQuery multi-select, pops
  /// [selectedExercises]. For single-select (addToWorkout), pops [exercise].
  void _navigateBackWithSelectedExercise(ExerciseDto selectedExercise) {
    Navigator.of(context).pop([selectedExercise]);
  }

  void _navigateBackWithSelectedExercises(List<ExerciseDto> selected) {
    Navigator.of(context).pop(selected);
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
    if (!mounted) return;
    setState(() {
      _loadOrSyncExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recentFromLogs = _recentFromLogs;
    final libraryOnly = _libraryOnly;
    final hasAny = recentFromLogs.isNotEmpty || libraryOnly.isNotEmpty;

    return Scaffold(
      appBar: widget.selectionPurpose == ExerciseSelectionPurpose.forAiQuery
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                _selectedExercises.isEmpty
                    ? 'Select exercises'
                    : '${_selectedExercises.length} selected',
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(<ExerciseDto>[]),
              ),
              actions: [
                if (_selectedExercises.isNotEmpty)
                  TextButton(
                    onPressed: () => _navigateBackWithSelectedExercises(
                      List.from(_selectedExercises),
                    ),
                    child: const Text('Done'),
                  ),
              ],
            )
          : null,
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
              hasAny
                  ? Expanded(
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          if (recentFromLogs.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 10, 12),
                                child: Text(
                                  'From your logs',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.9,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final exercise = recentFromLogs[index];
                                    final isSelected = widget
                                                .selectionPurpose ==
                                            ExerciseSelectionPurpose
                                                .forAiQuery &&
                                        _selectedExercises
                                            .any((e) => e.id == exercise.id);
                                    return ExerciseGridItem(
                                      exercise: exercise,
                                      onTap: () => _handleExerciseTap(exercise),
                                      isSelected: isSelected,
                                    );
                                  },
                                  childCount: recentFromLogs.length,
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 24)),
                          ],
                          if (libraryOnly.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 0, 10, 12),
                                child: Text(
                                  'Library',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 0, 10, 250),
                              sliver: SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.9,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final exercise = libraryOnly[index];
                                    final isSelected = widget
                                                .selectionPurpose ==
                                            ExerciseSelectionPurpose
                                                .forAiQuery &&
                                        _selectedExercises
                                            .any((e) => e.id == exercise.id);
                                    return ExerciseGridItem(
                                      exercise: exercise,
                                      onTap: () => _handleExerciseTap(exercise),
                                      isSelected: isSelected,
                                    );
                                  },
                                  childCount: libraryOnly.length,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const ListEmptyState(
                            message: "No exercises found in the library."),
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
  /// - forAiQuery: tap toggles multi-select; use Done to confirm
  /// - addToWorkout/viewOnly: Show "Add to workout" and "View history"
  void _handleExerciseTap(ExerciseDto exercise) {
    _dismissKeyboard(context);
    if (widget.selectionPurpose == ExerciseSelectionPurpose.forAiQuery) {
      setState(() {
        final idx = _selectedExercises.indexWhere((e) => e.id == exercise.id);
        if (idx >= 0) {
          _selectedExercises.removeAt(idx);
        } else {
          _selectedExercises.add(exercise);
        }
      });
      return;
    }
    _showExerciseOptionsBottomSheet(exercise);
  }

  void _showExerciseOptionsBottomSheet(ExerciseDto exercise) {
    // forAiQuery is handled in _handleExerciseTap (direct tap selects)
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
      if (!mounted) return;
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
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
      context,
      listen: false,
    );
    await controller.loadExerciseCatalog();
    _systemExercises = controller.exercises.toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Using shared InfoBanner
