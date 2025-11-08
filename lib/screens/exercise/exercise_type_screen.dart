import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/utils/general_utils.dart';

import '../../enums/exercise_type_enums.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class ExerciseTypeScreen extends StatelessWidget {
  final ExerciseType exerciseType;

  const ExerciseTypeScreen({super.key, required this.exerciseType});

  /// Select an muscle group
  void _selectExerciseType(
      {required BuildContext context, required ExerciseType type}) {
    Navigator.of(context).pop(type);
  }

  @override
  Widget build(BuildContext context) {
    final exerciseTypes = ExerciseType.values;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
          onPressed: context.pop,
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(right: 10.0, bottom: 10, left: 10),
          child: Column(
            children: [
              Expanded(
                child: ListView.separated(
                    itemBuilder: (BuildContext context, int index) {
                      final type = exerciseTypes[index];
                      return ListTile(
                          onTap: () => _selectExerciseType(
                              type: exerciseTypes[index], context: context),
                          leading: type == exerciseType
                              ? FaIcon(FontAwesomeIcons.solidSquareCheck,
                                  color: Theme.of(context).colors.vibrantAccent)
                              : const FaIcon(FontAwesomeIcons.solidSquareCheck),
                          trailing: _TrailingWidget(type: exerciseTypes[index]),
                          title: Text(exerciseTypes[index].name),
                          subtitle:
                              Text("${exerciseTypes[index].description} . . ."),
                          dense: true);
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        Divider(color: Colors.white70.withValues(alpha: 0.1)),
                    itemCount: exerciseTypes.length),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailingWidget extends StatelessWidget {
  final ExerciseType type;

  const _TrailingWidget({required this.type});

  @override
  Widget build(BuildContext context) {
    List<String> measurements = switch (type) {
      ExerciseType.weights => ["KG", " | ", "REPS"],
      ExerciseType.bodyWeight => ["REPS"],
      ExerciseType.duration => ["TIME"],
    };

    final itemWidgets = measurements
        .map((measurement) =>
            Text(measurement, style: Theme.of(context).textTheme.bodySmall))
        .toList();

    return SizedBox(
      width: 70,
      child:
          Row(mainAxisAlignment: MainAxisAlignment.end, children: itemWidgets),
    );
  }
}
