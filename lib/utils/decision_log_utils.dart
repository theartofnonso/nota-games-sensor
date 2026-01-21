import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/coach_decision_dto.dart';
import 'package:trainware/main.dart';
import 'package:trainware/repositories/supabase/supabase_coach_decision_repository.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/decision_logs/decision_logs_list.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class DecisionLogInput {
  final String summary;

  const DecisionLogInput({required this.summary});
}

Future<bool> requireDecisionLog({
  required BuildContext context,
  required String clientId,
}) async {
  final coachId = Supabase.instance.client.auth.currentUser?.id;
  if (coachId == null) {
    showSnackbar(
      context: context,
      message: 'Please sign in to log decisions.',
    );
    return false;
  }

  final decisionInput = await showDecisionLogBottomSheet(
    context: context,
  );
  if (decisionInput == null) {
    return false;
  }

  final decision = CoachDecisionDto(
    id: '',
    clientId: clientId,
    coachId: coachId,
    summary: decisionInput.summary,
    createdAt: DateTime.now(),
  );

  try {
    await SupabaseCoachDecisionRepository().createDecision(decision: decision);
    return true;
  } catch (e) {
    showSnackbar(
      context: context,
      message: 'Unable to save decision log. Please try again.',
    );
    return false;
  }
}

Future<bool> requireDecisionLogIfClientMode({
  required BuildContext context,
  required bool isClientMode,
  required String? clientId,
}) async {
  if (!isClientMode) {
    return true;
  }
  if (clientId == null) {
    showSnackbar(
      context: context,
      message: 'Missing client context for decision log.',
    );
    return false;
  }
  return requireDecisionLog(
    context: context,
    clientId: clientId,
  );
}

Future<DecisionLogInput?> showDecisionLogBottomSheet({
  required BuildContext context,
}) async {
  final sheetContext = navigatorKey.currentContext ?? context;
  final result = await showAppBottomSheet<dynamic>(
    context: sheetContext,
    isScrollControlled: true,
    isDismissible: true,
    useRootNavigator: true,
    builder: (ctx, _) => const _DecisionLogSheet(),
  );
  if (result is DecisionLogInput) {
    return result;
  }
  return null;
}

Future<void> showDecisionLogsBottomSheet({
  required BuildContext context,
  required String clientId,
  String? clientName,
}) async {
  final sheetContext = navigatorKey.currentContext ?? context;
  await showAppBottomSheet<void>(
    context: sheetContext,
    isScrollControlled: true,
    isDismissible: true,
    useRootNavigator: true,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: DecisionLogsList(
          clientId: clientId,
          clientName: clientName,
          limit: 100,
          showTitle: true,
          showViewAll: false,
        ),
      ),
    ),
  );
}

class _DecisionLogSheet extends StatefulWidget {
  const _DecisionLogSheet();

  @override
  State<_DecisionLogSheet> createState() => _DecisionLogSheetState();
}

class _DecisionLogSheetState extends State<_DecisionLogSheet> {
  late final TextEditingController _summaryController;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 26,
          right: 26,
          top: 26,
          bottom: 26 + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log decision',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _summaryController,
              cursorColor: isDark ? Colors.white : Colors.black,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Summary',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                onPressed: () {
                  final summary = _summaryController.text.trim();
                  if (summary.isEmpty) {
                    showSnackbar(
                      context: context,
                      message: 'Please enter a summary.',
                    );
                    return;
                  }
                  Navigator.of(context, rootNavigator: true).pop(
                    DecisionLogInput(
                      summary: summary,
                    ),
                  );
                },
                label: 'Save decision',
                buttonColor: Theme.of(context).colors.vibrantAccent,
                showArrowRight: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
