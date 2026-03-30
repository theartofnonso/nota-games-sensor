# Client onboarding and coach assignment

Coach choice and client profile creation happen on **notathletes.com**, not in the mobile app.

## Mobile client app

1. User signs in with email (OTP). Supabase session is created.
2. **`ProfileCompletionGate`** checks for a row in `public.clients` for that user id.
   - **Row exists** (created on the web) → continue to subscription gate.
   - **No row** → a **blocking bottom sheet** explains they must finish on the website, with **Open notathletes.com** and **Sign out**.
3. **Subscription (soft gate):** Clients always enter the main shell. Without both RevenueCat entitlements (`app_access` + `coach_access`), the bottom nav only shows **Home** and **Settings**; chat, routines, and coach feedback are hidden. **Home** shows a subscribe card that opens the paywall. After purchase, the full nav and features unlock.
4. Main app loads. Chat and other features still resolve coach assignment from the backend (e.g. `coach_clients`) as before.

There is **no** in-app coach picker.

## Website

Users subscribe, choose a coach, and get their `clients` (and related) rows created before using the app.
