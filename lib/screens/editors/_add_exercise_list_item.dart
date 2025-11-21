import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/colors.dart';

class AddExerciseListItem extends StatelessWidget {
  final VoidCallback onTap;

  const AddExerciseListItem({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: FloatingActionButton(
          heroTag: null,
          onPressed: onTap,
          backgroundColor: sapphireDark80,
          child: const FaIcon(
            FontAwesomeIcons.plus,
            size: 18,
          ),
        ),
      ),
    );
  }
}
