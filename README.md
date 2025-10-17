### TRKR: Train Better

[![Flutter Tests](https://github.com/theartofnonso/trackr-app/actions/workflows/flutter_tests.yml/badge.svg)](https://github.com/theartofnonso/trackr-app/actions/workflows/flutter_tests.yml)

### Contextual Nudges (Informational Only)

The app includes a lightweight nudge system to surface timely, informational guidance without requiring any action from the user.

#### What it does
The nudge engine analyzes the last 90 days of training and displays a single, concise banner message when relevant:

- Usual training time reminder when it's near your typical hour and no session is logged today.
- Consistency nudge if it's been several days since the last session.
- Weekly reinforcement message when adherence is trending well.

#### Where it lives
- `lib/nudges/nudge_engine.dart`: computes the message string based on user logs.
- `lib/screens/overview_screen.dart`: `_OverviewNudgeBanner` renders the informational banner under the calendar and updates as data streams in.

#### Design principles
- Informational only: no buttons or required actions.
- Context-aware and concise: ≤ 1 sentence, grounded in recent behavior.
- Non-intrusive: only shows when relevant; otherwise hidden.

#### Extending nudges
Add new rules inside `NudgeEngine.buildOverviewNudge`, guarded by simple conditions and returning `null` when not applicable. Keep messages short and specific.

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