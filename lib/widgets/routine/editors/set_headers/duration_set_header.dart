import 'package:flutter/material.dart';

import '../../../../enums/routine_editor_type_enums.dart';

class DurationSetHeader extends StatelessWidget {
  final RoutineEditorMode editorType;

  const DurationSetHeader({super.key, required this.editorType});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(1),
      },
      children: <TableRow>[
        TableRow(children: [
          const TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: SizedBox.shrink(),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Text("TIME",
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ),
        ]),
      ],
    );
  }
}
