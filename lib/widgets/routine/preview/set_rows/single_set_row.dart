import 'package:flutter/material.dart';

// import removed

class SingleSetRow extends StatelessWidget {
  final String label;

  const SingleSetRow({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final color = isDarkMode ? Colors.white10 : Colors.black38;

    return Table(
            border: TableBorder.all(color: color, borderRadius: BorderRadius.circular(50)),
            columnWidths: const <int, TableColumnWidth>{
              0: FlexColumnWidth(),
            },
            children: <TableRow>[
              TableRow(children: [
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ]),
            ]);
  }
}
