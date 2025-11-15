import 'package:flutter/material.dart';

import 'package:tracker_app/dtos/set_dtos/duration_set_dto.dart';
import 'package:tracker_app/extensions/duration_extension.dart';

import '../../../../enums/routine_editor_type_enums.dart';
import '../set_delete_button.dart';

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
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Table(
      border: TableBorder.all(
          color: isDarkMode ? Colors.white10 : Colors.black38,
          borderRadius: BorderRadius.circular(5)),
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(1),
      },
      children: [
        TableRow(children: [
          TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Center(child: SetDeleteButton(onDelete: onRemoved))),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: SizedBox(
              height: 50,
              child: Center(
                child: Text(setDto.duration.hmsDigital(),
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ])
      ],
    );
  }
}
