/// **Sync with RevenueCat → Product catalog** (client app).
///
/// ### Entitlements (access control — source of truth for gating)
/// Identifiers must match **Entitlements → Identifier** exactly.
/// - **app_access** — base subscription (used with coach_access for clients).
/// - **coach_access** — coach-led features (chat, coach selection, feedback, etc.).
///
/// Client builds expect the **coach-led product** to unlock **both** entitlements.
/// Link the subscription product to `app_access` and `coach_access` in RevenueCat.
///
/// ### Purchasing
/// The app uses a **custom paywall** that loads **RevenueCat offerings** (packages / store
/// products).
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const String entitlementAppAccess = 'app_access';
  static const String entitlementCoachAccess = 'coach_access';
}
