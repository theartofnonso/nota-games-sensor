import 'package:flutter/material.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import 'dialog_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// Dismisses the name/notes sheet. Pass [value] to return it from [showNameNotesBottomSheet].
typedef NameNotesPopSheet = void Function({({String name, String notes})? value});

/// Shared bottom sheet for capturing a name + second field (default: optional notes).
///
/// Use [notesFieldKeyboardType], [notesFieldRequired], and related params to reuse the
/// same layout for e.g. name + email ([showTrainWithCoachSheet]).
///
/// Returns a record with [name] and [notes] when the user confirms (second value is
/// still named [notes] for API stability; it holds email when configured as email).
/// Returns null if the sheet is dismissed/cancelled.
Future<({String name, String notes})?> showNameNotesBottomSheet({
  required BuildContext context,
  required String title,
  required String primaryButtonLabel,
  String description = 'Add a name and optional notes to continue.',
  String initialName = '',
  String initialNotes = '',
  String emptyNameMessage = 'Please provide a name',
  bool compact = false,
  String nameFieldHint = 'Name',
  String notesFieldHint = 'notes (optional)',
  TextInputType notesFieldKeyboardType = TextInputType.multiline,
  int? notesFieldMaxLines,
  bool notesFieldRequired = false,
  String notesFieldInvalidMessage = 'Please enter a valid email',
  /// When set, Continue validates then awaits this. Call [NameNotesPopSheet] to close
  /// the sheet (optionally with a return value). Shows a loading state on the button.
  Future<void> Function(
    ({String name, String notes}) data,
    NameNotesPopSheet popSheet,
  )? onPrimaryAsync,
}) async {
  final nameController = TextEditingController(text: initialName);
  final notesController = TextEditingController(text: initialNotes);

  ({String name, String notes})? result;
  var primarySubmitting = false;

  final isEmailSecondField =
      notesFieldKeyboardType == TextInputType.emailAddress;

  /// Caps multiline height so the sheet can shrink-wrap (same idea as [showSingleTextAreaBottomSheet]).
  int secondFieldMaxLines() {
    final override = notesFieldMaxLines;
    if (override != null) return override;
    if (notesFieldKeyboardType == TextInputType.multiline) return 10;
    return 1;
  }

  bool validateAndMaybeSnack(BuildContext ctx) {
    final name = nameController.text.trim();
    final notes = notesController.text.trim();

    if (name.isEmpty) {
      showSnackbar(context: ctx, message: emptyNameMessage);
      return false;
    }

    if (notesFieldRequired) {
      if (notes.isEmpty ||
          (isEmailSecondField && !notes.contains('@'))) {
        showSnackbar(
          context: ctx,
          message: notesFieldInvalidMessage,
        );
        return false;
      }
    }
    return true;
  }

  final sheetContent = Builder(
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final secondIsPrimaryStyle = notesFieldRequired && isEmailSecondField;

      Widget fieldColumn({required bool fieldsLocked}) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              cursorColor: isDark ? Colors.white : Colors.black,
              decoration: InputDecoration(
                hintText: nameFieldHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.words,
              readOnly: fieldsLocked,
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
              decoration: InputDecoration(
                hintText: notesFieldHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              keyboardType: notesFieldKeyboardType,
              autocorrect: isEmailSecondField ? false : true,
              textCapitalization:
                  isEmailSecondField
                      ? TextCapitalization.none
                      : TextCapitalization.sentences,
              maxLines: secondFieldMaxLines(),
              readOnly: fieldsLocked,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color:
                    secondIsPrimaryStyle
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 14,
              ),
            ),
          ],
        );
      }

      const outerPadding = EdgeInsets.only(
        left: 26,
        right: 26,
        top: 26,
        bottom: 26,
      );

      if (onPrimaryAsync == null) {
        return Padding(
          padding: outerPadding,
          // No [SingleChildScrollView] here: it expands to the modal max height and makes
          // the frosted sheet look full-screen (other input sheets use a plain [Column]).
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fieldColumn(fieldsLocked: false),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  buttonColor: Theme.of(ctx).colors.vibrantAccent,
                  label: primaryButtonLabel,
                  onPressed: () {
                    if (!validateAndMaybeSnack(ctx)) return;
                    final name = nameController.text.trim();
                    final notes = notesController.text.trim();
                    result = (name: name, notes: notes);
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      }

      return StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: outerPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AbsorbPointer(
                  absorbing: primarySubmitting,
                  child: fieldColumn(fieldsLocked: primarySubmitting),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OpacityButtonWidgetTwo(
                    buttonColor: Theme.of(ctx).colors.vibrantAccent,
                    label: primaryButtonLabel,
                    isLoading: primarySubmitting,
                    onPressed: () async {
                      if (!validateAndMaybeSnack(modalCtx)) return;
                      final name = nameController.text.trim();
                      final notes = notesController.text.trim();
                      final data = (name: name, notes: notes);

                      primarySubmitting = true;
                      setModalState(() {});

                      void popSheet({({String name, String notes})? value}) {
                        if (!modalCtx.mounted) return;
                        result = value;
                        Navigator.of(modalCtx).pop();
                      }

                      try {
                        await onPrimaryAsync(data, popSheet);
                      } finally {
                        primarySubmitting = false;
                        if (modalCtx.mounted) setModalState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
/// Keyboard avoidance is handled by [showAppActionBottomSheet] (outer padding).
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
  String? result;
  await showAppActionBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    child: Builder(
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.only(
            left: 26,
            right: 26,
            top: 26,
            bottom: 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: 0.6,
                  ),
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  buttonColor: Theme.of(ctx).colors.vibrantAccent,
                  label: primaryButtonLabel,
                  onPressed: () {
                    result = controller.text.trim();
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
