# App Store Review – Demo Account Setup (Guideline 2.1)

If Apple rejects with **Guideline 2.1 – Information Needed**, it usually means reviewers could not sign in or see useful content. Use this guide to fix it.

---

## 1. Create Demo Users in Supabase

1. Open **Supabase Dashboard** → **Authentication** → **Users** → **Add user**
2. Create these users (if not already present):

| Email | Password | Role |
|-------|----------|------|
| coach@ware.health | demo123456 | Coach |
| client@ware.health | demo123456 | Client |

3. Ensure **Email confirmation** is disabled for these users, or confirm them manually.

---

## 2. Seed Demo Data

1. Run the seed script in Supabase **SQL Editor**:
   - Open `supabase/seed_demo_accounts.sql`
   - Copy and run the full script

2. Confirm it completes without errors.

---

## 3. App Store Connect – App Review Information

1. Go to **App Store Connect** → Your App → **App Review** → **App Review Information**
2. Fill in **Sign-in required**:

**Client app (Not Athletes):**
```
Email: client@ware.health
Password: demo123456
```

**Coach app (Not Athletes Coach):**
```
Email: coach@ware.health
Password: demo123456
```

3. Add **Notes**:
```
This account has pre-populated workout programs, nutrition logs, and messaging access. Reviewers can complete a sandbox purchase to access the app and test all core features.
```

---

## 4. Test Before Resubmitting

1. **On an iPad** (Apple tested on iPad Air 11-inch):
   - Install the client build
   - Enter `client@ware.health`
   - App should auto-login (no OTP)
   - Confirm you see workouts, nutrition, and can navigate without paywall

2. Check layout on iPad: buttons, modals, and navigation should work correctly.

---

## 5. Resubmit

1. Reply to the rejection in Resolution Center (optional):
   ```
   Hello,
   We have added a fully functional demo account with pre-populated content in the App Review Information section.
   Please let us know if anything further is needed.
   Best regards,
   [Your name]
   ```

2. Submit a new build for review.

---

## What Was Fixed

- **Demo email detection** – entering `client@ware.health` or `coach@ware.health` triggers auto-login with the stored password (no OTP)
- **Pre-populated data** – workout logs, nutrition entries, coach-assigned plans, etc.
- **Subscription flow** – demo accounts go through the normal paywall so Apple can test purchase/restore during review

---

## User Journey: Demo vs Real Accounts

### Client app

| Step | Demo account | Real account |
|------|--------------|--------------|
| **1. Auth screen** | Enter `client@ware.health` → tap Continue → **auto sign-in** (password used internally, no OTP) | Enter email → tap Continue → OTP sent → enter 6-digit code → tap Verify |
| **2. ProfileCompletionGate** | Profile already exists (seeded in `clients` table) → pass through | New user: auto-create profile from email → pass through |
| **3. CoachSelectionGate** | Coach already assigned (seeded in `coach_clients`) → pass through | No coach: show CoachSelectionScreen until they select/complete |
| **4. SubscriptionGate** | Same as real: check backend subscription status | Check backend → if no subscription, show paywall |
| **5. Post-gates** | Pre-populated workouts, nutrition, plans (from seed) | Empty or their own data |

### Coach app

| Step | Demo account | Real account |
|------|--------------|--------------|
| **1. Auth screen** | Enter `coach@ware.health` → tap Continue → **auto sign-in** (no OTP) | Enter email → OTP flow (same as client) |
| **2. Pre-OTP check** | `requireCoachAccess` – coach@ware.health is in `coaches` table (seeded) → proceed | `requireCoachAccess` – email must be in `coaches` table or access denied |
| **3. Post-auth gates** | ProfileCompletionGate (skips – coach), CoachSelectionGate (skips – coach), SubscriptionGate (skips – coach) | Same gate logic |
| **4. Main app** | Pre-populated client (Demo Client) with workout data | Their actual clients |

### Summary of differences

- **Only difference in flow:** Demo accounts skip OTP – they go straight to sign-in with password. Everything else (subscription check, coach selection, profile) is the same.
- **Demo advantage:** Faster login for testing; pre-seeded data so reviewers see content without creating it.

---

## Troubleshooting

| Problem | Solution |
|--------|----------|
| "Demo account login failed" | Ensure the user exists in Supabase Auth with the correct password |
| Empty screens after login | Re-run `seed_demo_accounts.sql` |
| Paywall shows | Complete a sandbox purchase or use Restore if the account has a prior subscription |
| Coach access denied | Ensure `coach@ware.health` is in the `coaches` table and linked via `coach_clients` |
