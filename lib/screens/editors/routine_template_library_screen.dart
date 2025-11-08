import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/dtos/appsync/routine_template_dto.dart';
import 'package:tracker_app/widgets/search_bar.dart';

import '../../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../../utils/general_utils.dart';
import '../../../widgets/empty_states/no_list_empty_state.dart';
import '../../widgets/routine/preview/routine_template_grid_item.dart';

class RoutineTemplateLibraryScreen extends StatefulWidget {
  final bool readOnly;
  final List<RoutineTemplateDto> excludeTemplates;

  const RoutineTemplateLibraryScreen(
      {super.key, this.readOnly = false, this.excludeTemplates = const []});

  @override
  State<RoutineTemplateLibraryScreen> createState() =>
      _RoutineTemplateLibraryScreenState();
}

class _RoutineTemplateLibraryScreenState
    extends State<RoutineTemplateLibraryScreen> {
  late TextEditingController _searchController;

  /// Holds a list of [RoutineTemplateDto] when filtering through a search
  List<RoutineTemplateDto> _filteredTemplates = [];

  /// Search through the list of exercises
  ///
  /// Calculates a 'relevance' score for an [RoutineTemplateDto] based on the query parts.
  double _calculateRelevanceScore(
      RoutineTemplateDto template, List<String> queryParts) {
    // Convert exercise name to lowercase for case-insensitive matching
    final templateName = template.name.toLowerCase();

    // You can split the exercise name on spaces/hyphens if you want more granularity
    final templateNameParts = templateName.split(RegExp(r'[\s-]+'));

    double score = 0.0;

    for (final queryPart in queryParts) {
      // Exact substring match => add 1 point
      if (templateName.contains(queryPart)) {
        score += 1.0;
      }

      //If you want to reward startsWith more strongly, you could do:
      for (final part in templateNameParts) {
        if (part.startsWith(queryPart)) {
          score += 0.5; // for instance, half a point for startsWith
        }
      }
    }

    return score;
  }

  void _runSearch() {
    final query = _searchController.text.trim().toLowerCase();

    // Split on whitespace or hyphens to handle multiple words/phrases
    final queryParts =
        query.split(RegExp(r'[\s-]+')).where((q) => q.isNotEmpty).toList();

    // Get the list of all templates (excluding any you want to filter out by default)
    final filteredTemplates =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false)
            .templates
            .where((template) => !widget.excludeTemplates.contains(template))
            .where((template) => template.planId.isEmpty)
            .toList();

    // If the user typed nothing, you can simply show the entire filtered list
    // Or skip ranking and set directly — depends on your UI needs
    if (queryParts.isEmpty) {
      filteredTemplates.sort((a, b) => a.name.compareTo(b.name));
      setState(() {
        _filteredTemplates = filteredTemplates;
      });
      return;
    }

    // Compute a relevance score for each template, then sort descending by score
    final rankedList = filteredTemplates
        .map((template) {
          final score = _calculateRelevanceScore(template, queryParts);
          return (template: template, score: score);
        })
        .where((tuple) =>
            tuple.score > 0) // optional: only keep those with some match
        .toList();

    rankedList.sort((a, b) => b.score.compareTo(a.score));

    // Extract the templates from the sorted list
    final sortedTemplates = rankedList.map((tuple) => tuple.template).toList();

    setState(() {
      _filteredTemplates = sortedTemplates;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _runSearch();
  }

  /// Select a template
  void _navigateBackWithSelectedExercise(RoutineTemplateDto selectedTemplate) {
    Navigator.of(context).pop([selectedTemplate]);
  }

  @override
  Widget build(BuildContext context) {
    final children = _filteredTemplates
        .mapIndexed(
          (index, template) => GestureDetector(
              onTap: () => _navigateBackWithSelectedExercise(template),
              child: RoutineTemplateGridItemWidget(template: template)),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text("Routine Template Library".toUpperCase()),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CSearchBar(
                  hintText: "Search library",
                  onChanged: (_) => _runSearch(),
                  onClear: _clearSearch,
                  controller: _searchController),
              const SizedBox(height: 10),
              _filteredTemplates.isNotEmpty
                  ? Expanded(
                      child: GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          mainAxisSpacing: 10.0,
                          crossAxisSpacing: 10.0,
                          children: children),
                    )
                  : Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const NoListEmptyState(
                            message:
                                "It might feel quiet now, but your templates will soon appear here."),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadTemplates() {
    _filteredTemplates =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false)
            .templates
            .where((template) => !widget.excludeTemplates.contains(template))
            .where((template) => template.planId.isEmpty)
            .toList();

    _runSearch();
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadTemplates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
