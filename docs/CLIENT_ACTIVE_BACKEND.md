# Client subscription access

The **Trainware client app** uses **RevenueCat `CustomerInfo` entitlements** for **both**
**`app_access`** and **`coach_access`** (coach-led product). Users without both can still open the
app: navigation and home surface a **subscribe** path; the paywall is a **full-screen route**
(fade) opened from the home card (not a gate before the shell).
Subscription purchase UI loads **RevenueCat offerings** (packages).
The app does **not** call `api.notathletes.com`
for subscription status.

Other `api.notathletes.com` endpoints (e.g. account profile, account deletion, coach-clients) may
still be used where referenced in code.

## Flow summary

1. Client signs in; `Purchases.logIn` uses the Supabase user id.
2. On startup / refresh, the app loads `CustomerInfo` and sets access from RevenueCat.
3. Purchases use the RevenueCat SDK (`getOfferings`, `purchase(package)`).

If you need server-side subscription truth (e.g. webhooks, support tools), configure **RevenueCat
webhooks** to your backend rather than a separate subscription-status API for the mobile client.
