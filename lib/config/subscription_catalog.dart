/// **Sync with RevenueCat → Product catalog** (client app).
///
/// ### Entitlements (access control — source of truth for gating)
/// Identifiers must match **Entitlements → Identifier** exactly.
/// - **app_access** — user may use the app (subscription gate).
/// - **coach_access** — coach-led features (vs solo / self-coaching UX).
///
/// Link each subscription **product** to the right entitlement(s) in RevenueCat
/// (e.g. solo product → `app_access` only; coach product → `app_access` + `coach_access`).
///
/// ### Purchasing
/// The app uses a **custom paywall** that loads **RevenueCat offerings** (packages / store
/// products).
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const String entitlementAppAccess = 'app_access';
  static const String entitlementCoachAccess = 'coach_access';
}
