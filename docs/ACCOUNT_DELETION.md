# Account deletion (App Store Guideline 5.1.1(v))

This document describes where and how **client** users can delete their account and **all associated activities**. **Coach accounts are never deleted** (no option in the coach app; the backend must reject deletion for users in `public.coaches`).

---

## Where to find it

- **App:** Client app only (Not Athletes — the client/trainee build).
- **Location:** **Settings** (gear icon on the overview) → scroll down to the **“Delete account”** row (red text with user-minus icon), below the “Loving the app?” card and above the “Weight” setting.
- **Not shown:** In the Coach app (Not Athletes Coach). Coaches are known to the brand; account deletion is only offered to client users.

---

## User flow

1. User taps **Delete account**.
2. A confirmation sheet appears: title **“Delete account”**, message *“Your account and all associated data (workouts, plans, nutrition logs) will be permanently deleted. This cannot be undone.”*
3. User can **Cancel** or **Delete my account** (red button).
4. On **Delete my account**, the app runs **three** steps in order: (1) Agora Chat user delete, (2) Supabase account delete, (3) sign out. **If any step fails, the flow stops** and the user sees an error; the next steps (including sign out) are not run. Sign out happens only after both API calls succeed.
5. If any step fails, the user sees: *“Could not delete account. Something went wrong. Please try again or contact support at notathletes.com.”* (The app may show a backend `error` or `message` if present in the response.)

---

## What gets deleted (all associated activities)

When a **client** account is deleted, the following are removed:

| Area | What is removed |
|------|------------------|
| **Agora Chat** | The user’s Agora Chat account (chat identity and history). Handled by the Agora backend when the app calls `POST …/user/delete`. |
| **Supabase Auth** | The user’s auth account. Handled by the api.notathletes.com backend when the app calls `POST …/account/delete`. |
| **Database (Supabase)** | All data tied to that user is removed by **ON DELETE CASCADE** when the auth user is deleted. See migration `supabase/migrations/20260205000000_account_deletion_cascade.sql`. |

**Data removed by CASCADE (summary):**

- **Client-owned (keyed by auth user id):** `clients`, `routine_logs`, `user_device_tokens`, `exercises`, `nutrition_logs`.
- **Assigned to the client (keyed by client id):** `coach_clients`, `nutrition_templates`, `routine_plans`, `routine_templates` (and templates linked to deleted plans).

Coach-owned data (e.g. plans/templates owned by the coach) is not deleted when a client is removed; only links and rows that belong to or are assigned to that client are removed.

---

## Backend (handoff for backend developer)

The app runs **two** API calls in this order, then signs the user out. **If any call fails (non-2xx or exception), the app stops and does not run the remaining steps or sign out.** Order:

| Order | Endpoint | Purpose |
|-------|----------|---------|
| 1 | `POST https://agora.notathletes.com/user/delete` | Remove user from Agora Chat (compliance). |
| 2 | `POST https://api.notathletes.com/account/delete` | Delete Supabase Auth user (CASCADE removes all client data). |
| 3 | — | Sign out locally (Chat logout + Supabase signOut); only after 1–2 succeed. |

**Request shape (both):**  
- Headers: `Content-Type: application/json`, `Authorization: Bearer <Supabase access token>`  
- Body: `{"userId": "<Supabase user id>"}`  

**Specs:**

1. **Agora user deletion** → [AGORA_USER_DELETE_BACKEND.md](./AGORA_USER_DELETE_BACKEND.md)
2. **Supabase account deletion** → [SUPABASE_ACCOUNT_DELETE_BACKEND.md](./SUPABASE_ACCOUNT_DELETE_BACKEND.md)

**Rules:** Coach accounts must never be deleted (api.notathletes.com must reject with 403 for users in `public.coaches`). Supabase data is removed by DB CASCADE; ensure migration `20260205000000_account_deletion_cascade.sql` is applied.

---

## Reply to App Review

You can reply in App Store Connect with something like:

> Account deletion is supported for **client** users only (not for coaches). To locate it: open the **client** app (Not Athletes) → tap the **Settings** (gear) icon → scroll to **“Delete account”** (red, below the “Loving the app?” section). Tapping it shows a confirmation; confirming permanently deletes the account and all associated data (including chat identity, billing/subscription, and all app data such as workouts, plans, and nutrition logs). This cannot be undone.
