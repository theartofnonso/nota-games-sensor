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
  String description = 'Add a name and optional notes to continue.',
  String initialName = '',
  String initialNotes = '',
  String emptyNameMessage = 'Please provide a name',
  bool compact = false,
}) async {
  final nameController = TextEditingController(text: initialName);
  final notesController = TextEditingController(text: initialNotes);

  ({String name, String notes})? result;

  final sheetContent = Builder(
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
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color:
                        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                  ),
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
                hintText: "notes (optional)",
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
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
  );

  if (compact) {
    await showAppActionBottomSheet(
      context: context,
      isScrollControlled: true,
      child: sheetContent,
    );
  } else {
    await showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      child: sheetContent,
    );
  }

  return result;
}

/// Shared bottom sheet for a single multiline text field (e.g. session feedback).
/// Uses [Builder] + viewInsets so the sheet stays visible when the keyboard opens.
///
/// Returns the trimmed text when the user taps the primary button, or null if dismissed.
Future<String?> showSingleTextAreaBottomSheet({
  required BuildContext context,
  required String title,
  required String description,
  required String hintText,
  String initialValue = '',
  String primaryButtonLabel = 'Save',
}) async {
  final controller = TextEditingController(text: initialValue);

  final result = await showAppBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    enableDrag: true,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 4,
                cursorColor: isDark ? Colors.white : Colors.black,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  alignLabelWithHint: true,
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  buttonColor: Theme.of(ctx).colors.vibrantAccent,
                  label: primaryButtonLabel,
                  onPressed: () =>
                      Navigator.of(ctx).pop<String?>(controller.text.trim()),
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



