import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/extensions/duration_extension.dart';

import '../../../../enums/routine_editor_type_enums.dart';
import '../../../../utils/theme/color_extensions.dart';

class DurationSetRow extends StatelessWidget {
  final DurationSetDto setDto;
  final VoidCallback onRemoved;
  final VoidCallback onCheck;
  final RoutineEditorMode editorType;
  final DateTime startTime;
  final void Function(Duration duration, bool shouldCheck) onUpdateDuration;

  const DurationSetRow({
    super.key,
    required this.setDto,
    required this.onRemoved,
    required this.onCheck,
    required this.onUpdateDuration,
    required this.startTime,
    required this.editorType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;

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
          // Duration display (single text field)
          Expanded(
            child: Center(
              child: Text(
                setDto.duration.hmsDigital(),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                  borderRadius: BorderRadius.circular(50),
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
