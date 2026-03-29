# Client subscription access

The **Trainware client app** gates access from **RevenueCat `CustomerInfo` entitlements**:
**`app_access`** (enter app) and **`coach_access`** (coach-tier UI). Subscription purchase UI is a
**custom paywall** that loads **RevenueCat offerings** (packages).
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
