import 'package:flutter/material.dart';

import '../../../../enums/routine_editor_type_enums.dart';

class RepsSetHeader extends StatelessWidget {
  final RoutineEditorMode editorType;

  const RepsSetHeader({super.key, required this.editorType});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(1),
        2: FixedColumnWidth(60),
      },
      children: <TableRow>[
        TableRow(children: [
          const TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: SizedBox.shrink(),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Text("REPS",
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ),
          const TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Icon(
                Icons.check,
                size: 12,
              ))
        ]),
      ],
    );
  }
}
