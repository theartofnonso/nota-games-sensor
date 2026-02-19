# Supabase account deletion (backend spec)

**Audience:** Backend developer implementing the endpoint that permanently deletes a **client** user from Supabase Auth (and thus all their data via DB CASCADE). The app only sends the request; your backend performs the deletion.

---

## 1. Endpoint you need to implement

| Item | Value |
|------|--------|
| **URL** | `POST https://api.notathletes.com/account/delete` |
| **Purpose** | Permanently delete the requesting user’s Supabase Auth account. All associated data is removed by the database (ON DELETE CASCADE). **Coach accounts must never be deleted.** |

---

## 2. What the app sends

| Item | Value |
|------|--------|
| **Method** | `POST` |
| **Headers** | `Content-Type: application/json`<br>`Authorization: Bearer <Supabase access token>` |
| **Body** | `{"userId": "<Supabase user id>"}` |

The app sends the current user’s Supabase user id in the body. Validate the JWT and ensure the authenticated user matches the body’s `userId` (so only the user can delete their own account).

---

## 3. What you must do

1. **Validate the JWT**  
   Authenticate the request using the Supabase access token. Resolve the user id from the token (subject) and **confirm it matches the `userId` in the request body**.

2. **Reject coaches**  
   If this user is a coach, do **not** delete them.  
   - Check whether the user id exists in your `public.coaches` table (or equivalent).  
   - If they are a coach, return **403** with a JSON body, e.g. `{"error": "Coach accounts cannot be deleted"}`.  
   - The app will show the `error` (or `message`) value to the user if present.

3. **Delete the Supabase Auth user**  
   Call Supabase Auth Admin to delete the user, e.g.  
   `auth.admin.deleteUser(userId)`  
   (Use your Supabase service role / admin client. The exact API depends on your stack; Supabase exposes this as an admin-only operation.)

4. **Do not delete data manually**  
   All client data (e.g. `clients`, `coach_clients`, `workout_sessions`, `session_exercises`, `session_sets`, `user_device_tokens`, `exercises`, `nutrition_logs`, `nutrition_templates`, `routine_plans`, `routine_templates`) is removed by the database when the auth user is deleted, via **ON DELETE CASCADE** on the foreign keys. Ensure the relevant migrations are applied.

5. **Response**  
   - On success: return **200** or **204** (no body required).  
   - On failure: return an appropriate status (e.g. 400, 403, 500) and optionally a JSON body with `{"error": "..."}` or `{"message": "..."}`; the app may display that to the user.

---

## 4. Response summary

| Scenario | HTTP status | Body (optional) |
|----------|-------------|------------------|
| Success | 200 or 204 | — |
| User is a coach (forbidden) | 403 | `{"error": "Coach accounts cannot be deleted"}` |
| Invalid / missing token | 401 | `{"error": "..."}` |
| userId missing or doesn’t match JWT | 400 | `{"error": "..."}` |
| Deletion failed | 500 | `{"error": "..."}` |

---

## 5. Note on Agora Chat

The **app** also calls `POST https://agora.notathletes.com/user/delete` with `{"userId": "..."}` **before** calling this endpoint. That Agora backend is responsible for deleting the user from Agora Chat. Your api.notathletes.com backend does **not** need to call Agora; it only needs to delete the Supabase Auth user and rely on DB CASCADE for data.
