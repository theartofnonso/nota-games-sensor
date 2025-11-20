import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/widgets/list_tile.dart';

class AddExerciseListItem extends StatelessWidget {
  final VoidCallback onTap;

  const AddExerciseListItem({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ThemeListTile(
      backgroundColor: Colors.transparent,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        onTap: onTap,
        leading: const FaIcon(
          FontAwesomeIcons.plus,
          size: 18,
          color: Colors.white,
        ),
        title: Text(
          'Add exercises',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
      ),
    );
  }
}


