import 'package:flutter/material.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class ListTileEmptyState extends StatelessWidget {

  const ListTileEmptyState({super.key});

  @override
  Widget build(BuildContext context) {

    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 160,
            height: 10,
            decoration: BoxDecoration(
              color: isDarkMode ? Theme.of(context).colors.sapphireDark : Colors.grey.shade600,
              borderRadius: BorderRadius.circular(10.0), // Adjust the radius as needed
            )),
        const SizedBox(height: 5),
        Container(
            width: 100,
            height: 10,
            decoration: BoxDecoration(
              color: isDarkMode ? Theme.of(context).colors.sapphireDark : Colors.grey.shade600,
              borderRadius: BorderRadius.circular(10.0), // Adjust the radius as needed
            ))
      ],
    );
  }
}
