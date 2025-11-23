import 'package:flutter/material.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import 'dialog_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// Shared bottom sheet for capturing a name + optional notes.
///
/// Returns a record with [name] and [notes] when the user confirms,
/// or null if the sheet is dismissed/cancelled.
Future<({String name, String notes})?> showNameNotesBottomSheet({
  required BuildContext context,
  required String title,
  required String primaryButtonLabel,
  String initialName = '',
  String initialNotes = '',
  String emptyNameMessage = 'Please provide a name',
}) async {
  final nameController = TextEditingController(text: initialName);
  final notesController = TextEditingController(text: initialNotes);

  ({String name, String notes})? result;

  await showAppBottomSheet(
    context: context,
    isScrollControlled: true,
    child: Builder(
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            left: 26,
            right: 26,
            top: 26,
            bottom: 26 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                cursorColor: isDark ? Colors.white : Colors.black,
                decoration: const InputDecoration(
                  hintText: "Name",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                cursorColor: isDark ? Colors.white : Colors.black,
                decoration: const InputDecoration(
                  hintText: "Notes (optional)",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  buttonColor: Theme.of(ctx).colors.vibrantAccent,
                  label: primaryButtonLabel,
                  onPressed: () {
                    final name = nameController.text.trim();
                    final notes = notesController.text.trim();

                    if (name.isEmpty) {
                      showSnackbar(context: ctx, message: emptyNameMessage);
                      return;
                    }

                    result = (name: name, notes: notes);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return result;
}



