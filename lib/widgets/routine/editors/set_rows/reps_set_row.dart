import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/widgets/routine/editors/textfields/int_textfield.dart';

import '../../../../enums/routine_editor_type_enums.dart';
import '../../../../utils/theme/color_extensions.dart';

class RepsSetRow extends StatelessWidget {
  final RepsSetDto setDto;
  final VoidCallback onRemoved;
  final VoidCallback onCheck;
  final RoutineEditorMode editorType;
  final void Function() onTapRepsEditor;
  final TextEditingController controller;
  final void Function(int reps) onChangedReps;
  final bool showCheck;

  const RepsSetRow({
    super.key,
    required this.setDto,
    required this.onRemoved,
    required this.onCheck,
    required this.controller,
    required this.onChangedReps,
    required this.onTapRepsEditor,
    required this.editorType,
    required this.showCheck,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;

    int reps = (setDto).reps;

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
          // Reps input field (no icon, no label) – show "reps" suffix
          Expanded(
            child: IntTextField(
              value: reps,
              onChanged: onChangedReps,
              onTap: onTapRepsEditor,
              controller: controller,
              maxLength: 2,
              suffix: 'reps',
            ),
          ),
          const SizedBox(width: 12),
          // Check button on right (fully rounded) - always visible, disabled when showCheck is false
          IgnorePointer(
            ignoring: !showCheck,
            child: Opacity(
              opacity: showCheck ? 1.0 : 0.5,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: showCheck ? onCheck : null,
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
            ),
          ),
        ],
      ),
    );
  }
}
