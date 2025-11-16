import 'package:flutter/material.dart';

// import removed

class DoubleSetRow extends StatelessWidget {
  final String first;
  final String second;
  const DoubleSetRow({super.key, required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final color = isDarkMode ? Colors.white10 : Colors.black38;

    return Table(
          border: TableBorder.all(color: color, borderRadius: BorderRadius.circular(50), width: 1),
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
          },
          children: <TableRow>[
            TableRow(children: [
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(first, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                ),
              ),
              TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(second, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  ))
            ]),
          ]);
  }
}
