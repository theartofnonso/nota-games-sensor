import 'package:flutter/material.dart';
import 'package:tracker_app/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:tracker_app/widgets/routine/editors/textfields/double_textfield.dart';
import 'package:tracker_app/widgets/routine/editors/textfields/int_textfield.dart';

import '../../../../enums/routine_editor_type_enums.dart';
import '../set_check_button.dart';
import '../set_delete_button.dart';

class WeightsAndRepsSetRow extends StatelessWidget {
  final WeightAndRepsSetDto setDto;
  final VoidCallback onRemoved;
  final VoidCallback onCheck;
  final RoutineEditorMode editorType;
  final void Function(int value) onChangedReps;
  final void Function(double value) onChangedWeight;
  final void Function() onTapWeightEditor;
  final void Function() onTapRepsEditor;
  final (TextEditingController, TextEditingController) controllers;

  const WeightsAndRepsSetRow({
    super.key,
    required this.setDto,
    required this.onRemoved,
    required this.onCheck,
    required this.onChangedReps,
    required this.onChangedWeight,
    required this.onTapWeightEditor,
    required this.onTapRepsEditor,
    required this.controllers, required this.editorType,
  });

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    double weight = setDto.weight;
    int reps = setDto.reps;

    return Table(
      border:
          TableBorder.all(color: isDarkMode ? Colors.white10 : Colors.black38, borderRadius: BorderRadius.circular(5)),
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FixedColumnWidth(60),
      },
      children: [
        TableRow(children: [
          TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Center(child: SetDeleteButton(onDelete: onRemoved))),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: DoubleTextField(
              value: weight,
              onChanged: onChangedWeight,
              onTap: onTapWeightEditor,
              controller: controllers.$1,
            ),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: IntTextField(
              value: reps,
              onChanged: onChangedReps,
              onTap: onTapRepsEditor,
              controller: controllers.$2,
              maxLength: 2,
            ),
          ),
          TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: SetCheckButton(setDto: setDto, onCheck: onCheck))
        ])
      ],
    );
  }
}
