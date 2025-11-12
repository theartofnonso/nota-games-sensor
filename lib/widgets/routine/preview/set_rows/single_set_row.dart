import 'package:flutter/material.dart';

import 'package:tracker_app/utils/theme/color_extensions.dart';
import '../../../../dtos/pb_dto.dart';
import '../../../pbs/pb_icon.dart';

class SingleSetRow extends StatelessWidget {
  final String label;
  final List<PBDto> pbs;

  const SingleSetRow({super.key, required this.label, this.pbs = const []});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final color = isDarkMode ? Colors.white10 : Colors.black38;

    final pbsForSet = pbs
        .map((pb) => PBIcon(
              label: pb.pb.name,
              size: 12,
            ))
        .toList();

    return Badge(
        alignment: Alignment.topLeft,
        backgroundColor: Colors.transparent,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4),
          decoration: BoxDecoration(
            color: pbs.isNotEmpty ? (isDarkMode ? Theme.of(context).colors.sapphireDark80 : Colors.grey.shade200) : null,
            borderRadius: BorderRadius.circular(5), // Rounded corners
          ),
          child: Row(spacing: 6, children: pbsForSet),
        ),
        child: Table(
            border: TableBorder.all(color: color, borderRadius: BorderRadius.circular(5)),
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
            ]));
  }
}
