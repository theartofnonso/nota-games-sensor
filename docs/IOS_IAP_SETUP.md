# iOS In-App Purchase Setup

This document describes the steps to get the monthly IAP subscription working fully for the client app on iOS.

---

## Coach App: No IAP

The **coach app** (Not Athletes Coach, `com.notathletes.coach`) must **not** have In-App Purchase:

- **Entitlements**: Coach builds use `RunnerDebug-coach.entitlements` and `RunnerRelease-coach.entitlements`, which do not include any IAP entitlement.
- **Apple Developer Portal**: Ensure the coach App ID (`com.notathletes.coach`) does **not** have the In-App Purchase capability enabled. Go to [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers → select the coach App ID → ensure In-App Purchase is **unchecked**.
- **App Store Connect**: Do not create or configure any In-App Purchase products for the coach app.
- **Code**: `ClientSubscriptionService` and `iap_service` are never invoked when `AppConfig.isCoach` is true.

---

## Current Implementation

- **Client app**: Uses Apple In-App Purchase (IAP) for iOS and Google Play Billing for Android.
- **Product IDs**: coach-led subscription only (e.g. `notathletes_monthly`); must unlock **app_access** and **coach_access** in RevenueCat.
- **Client Bundle ID**: `com.notathletes.client` – products in App Store Connect must be under this app.
- **Flow**: User enters email → restore purchases → if none, paywall shows products → subscribe via App Store → sign in with OTP.
- **Code locations**: 
  - `lib/services/iap_service.dart` – IAP service (logs product load errors to console)
  - `lib/utils/client_access_utils.dart` – client access + IAP

---

## Steps to Complete

### 1. App Store Connect – Agreement & Tax

- [ ] **Paid Applications Agreement** signed in App Store Connect
- [ ] **Tax forms** completed
- [ ] **Banking** info added for payouts

---

### 2. App Store Connect – Create the Subscription Product

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → select the client app
2. Go to **Subscriptions** (or **In-App Purchases** under Features)
3. Create a **Subscription Group** (e.g. "Not Athletes Membership") if you don’t have one
4. Create a **Subscription** in that group:
   - **Reference name**: e.g. "Monthly"
   - **Product ID**: `notathletes_monthly` (must match exactly; update code if you use a different ID)
   - **Subscription duration**: 1 month
   - **Price**: Set base price and any localized prices
5. **Review Information**: Add screenshot, description, etc. as required
6. Submit for review with the app (or as part of an app update)

---

### 3. Xcode – Enable In-App Purchase

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Open **Signing & Capabilities**
4. Click **+ Capability**
5. Add **In-App Purchase**

---

### 4. Verify Product ID in Code

Ensure the product ID in the app matches App Store Connect:

**File**: `lib/services/iap_service.dart`

```dart
const Set<String> _iapProductIds = <String>{
  'notathletes_monthly',  // Must match App Store Connect product ID
};
```

If you used a different product ID in App Store Connect, update this constant.

---

### 5. Test with Sandbox

1. In App Store Connect → **Users and Access** → **Sandbox** → create a **Sandbox Tester** account
2. On your iOS device: **Settings** → **App Store** → **Sandbox Account** → sign in with the sandbox tester
3. Build and run the client app (`flutter run --flavor client -t lib/main_client.dart`)
4. Run through the flow: enter email → purchase sheet should appear → Subscribe → complete purchase in sandbox
5. Confirm you can sign in after a successful purchase

**Note**: Sandbox subscriptions renew on a shorter schedule (e.g. 1 month ≈ 5 minutes) for testing.

---

### 6. (Optional) Server-Side Receipt Validation

Right now the app validates subscriptions on-device only. For stronger security and cross-device consistency:

- Add a backend endpoint that receives `verificationData.serverVerificationData` from the client
- Validate the JWS with Apple’s [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- Store/update subscription status per user (e.g. in Supabase)
- Optionally, let the client call your backend to confirm active subscription before sign-in

---

## Checklist Summary

| Step | Status |
|------|--------|
| Paid agreement, tax, banking in App Store Connect | |
| Subscription product created (`notathletes_monthly`) | |
| In-App Purchase capability in Xcode | |
| Product ID matches in code | |
| Sandbox testing completed | |
| (Optional) Backend receipt validation | |

---

## Troubleshooting

- **Products not loading**: Confirm product ID spelling, that the product is submitted/approved (or at least available for testing), and that the app’s Bundle ID matches the app in App Store Connect.
- **"Store not available"**: Usually means the device is not signed in to an Apple ID or there’s a sandbox/network issue.
- **Restore returns nothing**: Normal for a brand new user with no prior purchases.
- **Purchase fails in sandbox**: Ensure the sandbox tester account is signed in under Settings → App Store → Sandbox Account.
