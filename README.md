### TRKR: Train Better

[![Flutter Tests](https://github.com/theartofnonso/trackr-app/actions/workflows/flutter_tests.yml/badge.svg)](https://github.com/theartofnonso/trackr-app/actions/workflows/flutter_tests.yml)

### Contextual Nudges (Informational Only)

The app includes a lightweight, modular nudge system that surfaces timely, informational guidance without requiring any action from the user.

#### What it does
Analyses the last 4–12 weeks of training and displays a single, concise banner message when relevant:

- Usual training time reminder when it's near your typical hour and no session is logged today.
- Consistency nudge if it's been several days since the last session.
- Weekly reinforcement message when adherence is trending well.
- In‑session target context, post‑session volume guidance, plans adherence encouragement, and library variety suggestions.

#### Project structure
- `lib/nudges/widgets/info_banner.dart`: Shared informational banner UI.
- `lib/nudges/overview_nudges.dart`: Overview screen nudges.
- `lib/nudges/in_session_nudges.dart`: Routine log editor (in‑session) nudges.
- `lib/nudges/post_summary_nudges.dart`: Post‑session summary nudges.
- `lib/nudges/plans_nudges.dart`: Plans screen nudges.
- `lib/nudges/exercise_library_nudges.dart`: Exercise library nudges.

#### Where they are rendered
- `lib/screens/overview_screen.dart`: `_OverviewNudgeBanner` under the calendar.
- `lib/screens/editors/routine_log_editor_screen.dart`: banner above timer/grid when applicable.
- `lib/screens/logs/routine_log_summary_screen.dart`: banner above shareables.
- `lib/screens/routines/routine_plans_screen.dart`: banner at the top of content.
- `lib/screens/exercise/library/exercise_library_screen.dart`: banner under the search bar.

#### Design principles
- Informational only: no buttons or required actions.
- Context-aware and concise: ≤ 1 sentence, grounded in recent behavior.
- Non-intrusive: only shows when relevant; otherwise hidden.

#### Extending nudges
- Add rules in the corresponding module (e.g., `OverviewNudges.build`).
- Return `null` when conditions don’t apply so the UI hides automatically.
- Keep messages short, neutral, and specific.

### Suggested additional places for contextual nudges

- Routine Log Editor (in-session)
  - Show a mini banner above the set list: last session’s top set and today’s suggested target (informational only).
  - Gentle fatigue cue: if the previous set was RPE 10 or reps dropped sharply, suggest holding load on the next set.

- Post-Session Summary Screen
  - “PR recap” and a one-line next-time target suggestion (e.g., hold load or +2.5%).
  - Density reminder if rests ran long (e.g., “Next time aim for ≤ 120s average rest on compounds”).

- Routine Plans Screen
  - Subtle banner when weekly adherence is below target: “Two short 30‑minute sessions can keep momentum this week.”

- Calendar View
  - When a gap of ≥ 3 days is detected between sessions, show a discreet consistency nudge at the top of the view.

- Exercise Library
  - If a user repeatedly logs the same 2–3 movements, suggest one complementary accessory (informational note only).

#### Implementation tips
- All nudges should be derived from already-available data in `ExerciseAndRoutineController`.
- Keep copy consistent and neutral; avoid prescriptive language.
- Ensure banners are dismissible by simply navigating away or when conditions no longer apply.