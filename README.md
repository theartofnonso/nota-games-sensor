# Gameware

Flutter player app for **NOTA Games** motion sessions.

## What it does

- Join a session by code or QR scan
- Wait in the lobby until the session starts
- Stream device motion data during workouts
- Sync session state via Supabase realtime

## Run

```bash
flutter pub get
flutter run
```

Configure the game engine URL in `lib/features/nota_games/core/nota_server_config.dart`.

Supabase credentials live in `lib/supabase_config.dart`.

## Tests

```bash
flutter test
```
