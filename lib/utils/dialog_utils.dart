import 'package:flutter/material.dart';

import '../colors.dart';

Future<void> showBottomSheetWithSingleAction({
  required BuildContext context,
  required String title,
  required String description,
  required VoidCallback action,
  required String actionLabel,
  bool isDestructive = false,
  Color? actionColor,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final buttonColor = isDestructive
          ? error
          : (actionColor ?? vibrantGreen);

      return Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: action,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      );
    },
  );
}
