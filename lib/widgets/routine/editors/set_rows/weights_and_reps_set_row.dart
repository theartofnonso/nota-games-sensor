import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/widgets/routine/editors/textfields/double_textfield.dart';
import 'package:trainware/widgets/routine/editors/textfields/int_textfield.dart';

import '../../../../enums/routine_editor_type_enums.dart';
import '../../../../utils/theme/color_extensions.dart';

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
    required this.controllers,
    required this.editorType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;

    double weight = setDto.weight;
    int reps = setDto.reps;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: colors.borderLight,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(left: 6, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          // Delete button on left (fully rounded)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemoved,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  color: Colors.red.withValues(alpha: 0.9),
                  size: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Weight input field (no icon, no label)
          Expanded(
            child: DoubleTextField(
              value: weight,
              onChanged: onChangedWeight,
              onTap: onTapWeightEditor,
              controller: controllers.$1,
              textAlign: TextAlign.center,
            ),
          ),
          // Divider between weight and reps
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.borderLight,
            ),
          ),
          // Reps input field (no icon, no label)
          Expanded(
            child: IntTextField(
              value: reps,
              onChanged: onChangedReps,
              onTap: onTapRepsEditor,
              controller: controllers.$2,
              maxLength: 2,
            ),
          ),
          const SizedBox(width: 12),
          // Check button on right (fully rounded)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCheck,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: setDto.checked
                      ? colors.vibrantAccent
                      : colors.vibrantAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                clipBehavior: Clip.antiAlias,
                child: FaIcon(
                  FontAwesomeIcons.check,
                  color: setDto.checked ? Colors.black : colors.vibrantAccent,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
