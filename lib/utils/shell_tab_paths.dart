import 'package:trainware/screens/logs/coach_feedback_feed_screen.dart';

/// Client shell tab: primary routine plan (bottom nav "Routines").
const kShellRoutinesPath = '/routines';

/// Client shell tab: workout template detail (still under "Routines" selection).
/// Path param is the template id (see [main.dart] ShellRoute).
const kShellRoutineTemplatePathPrefix = '/routine_template/';

bool isShellRoutineTemplatePath(String path) =>
    path.startsWith(kShellRoutineTemplatePathPrefix);

/// Coach feedback feed as a shell tab (Pro + coach).
bool isShellCoachFeedbackPath(String path) =>
    path == CoachFeedbackFeedScreen.routeName;
