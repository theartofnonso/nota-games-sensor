import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:trainware/utils/general_utils.dart';

import '../../dtos/exercise_log_dto.dart';

class ReOrderExercisesScreen extends StatefulWidget {
  final List<ExerciseLogDto> exercises;

  const ReOrderExercisesScreen({super.key, required this.exercises});

  @override
  State<ReOrderExercisesScreen> createState() => _ReOrderExercisesScreenState();
}

class _ReOrderExercisesScreenState extends State<ReOrderExercisesScreen> {
  bool _hasReOrdered = false;
  late List<ExerciseLogDto> _exercises;

  void _reOrderProcedures({required int oldIndex, required int newIndex}) {
    setState(() {
      _hasReOrdered = true;

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final ExerciseLogDto item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }

  /// Navigate to previous screen
  void _saveReOrdering() {
    Navigator.of(context).pop(_exercises);
  }

  @override
  Widget build(BuildContext context) {
    final widgets = _exercises
        .mapIndexed((index, exercise) => ListTile(
              key: Key("$index"),
              title: Text(exercise.exercise.name),
              trailing: const Icon(
                Icons.drag_handle,
              ),
            ))
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
          onPressed: context.pop,
        ),
        title: Text("Reorder Exercises".toUpperCase()),
        centerTitle: true,
        actions: [
          _hasReOrdered
              ? IconButton(
                  icon:
                      const FaIcon(FontAwesomeIcons.solidSquareCheck, size: 28),
                  onPressed: _saveReOrdering,
                )
              : const SizedBox.shrink(),
          const SizedBox(width: 12)
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(10.0),
          child: ReorderableListView(
              buildDefaultDragHandles: true,
              children: widgets,
              onReorder: (int oldIndex, int newIndex) =>
                  _reOrderProcedures(oldIndex: oldIndex, newIndex: newIndex)),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.exercises);
  }
}
