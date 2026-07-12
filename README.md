# Gameware

Flutter player app for **NOTA Games** motion sessions.

## What it does

- Join a session by QR scan (one tap after entering your name)
- Auto-assigned to Red or Blue team on join
- Stream device motion data every 5 seconds while `sensorActive`
- Sync session state via Supabase Realtime
- Return to the join screen when a session ends

## Environment

Provide these via `--dart-define` (do not commit secrets):

| Variable | Purpose |
|---|---|
| `SERVER_URL` | Backend REST API base URL |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon public key |

Defaults are in `lib/features/nota_games/core/app_env.dart` for local development.

## Run

```bash
flutter pub get

flutter run \
  --dart-define=SERVER_URL=https://your-server.example.com \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Tests

```bash
flutter test
```
