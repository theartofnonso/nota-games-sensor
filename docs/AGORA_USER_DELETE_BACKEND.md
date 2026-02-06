# Agora Chat: delete user (backend spec)

**Audience:** Backend developer implementing the endpoint that deletes a user from Agora Chat when the client deletes their account. The app only sends the request; your backend performs the Agora deletion.

---

## 1. Endpoint you need to implement

| Item | Value |
|------|--------|
| **Base URL** | `https://agora.notathletes.com` (existing Agora backend) |
| **Path** | `POST /user/delete` |
| **Purpose** | Delete the requesting user from Agora Chat so their chat account is removed. |

The Flutter app calls this **before** calling the main account-deletion endpoint (api.notathletes.com). If your endpoint returns an error (e.g. 404), the app still continues with account deletion; a non-2xx response does not block the user.

---

## 2. What the app sends

| Item | Value |
|------|--------|
| **Method** | `POST` |
| **Headers** | `Content-Type: application/json`<br>`Authorization: Bearer <Supabase access token>` |
| **Body** | `{"userId": "<Supabase user id>"}` |

The app sends the current user’s Supabase user id. Your backend must derive the Agora Chat username from it (see below) and then call Agora’s REST API. Validate the JWT and confirm the authenticated user matches the body’s `userId` so only the user can delete their own Agora account.

---

## 3. Agora username derivation (backend must implement)

The Agora Chat username is derived from the Supabase user id using this rule (same as the app’s chat login). **Implement this on the backend** so username logic lives in one place.

**Rule:**

1. **Sanitize:** Replace every character that is **not** `A–Z`, `a–z`, `0–9`, or `_` with `_`.
2. **Prefix if needed:** If the resulting string does **not** start with a letter (`A–Z` or `a–z`), prefix it with `u_`. Otherwise leave it as-is.

**Example:**

- Input: `550e8400-e29b-41d4-a716-446655440000`
- After sanitize: `550e8400_e29b_41d4_a716_446655440000`
- Does not start with a letter → prefix: `u_550e8400_e29b_41d4_a716_446655440000`

**Regex (any language):**

- Sanitize: replace `[^A-Za-z0-9_]` with `_`.
- First character: test `^[A-Za-z]`; if it does not match, prepend `u_`.

**Pseudocode:**

```text
sanitized = replaceAll(userId, /[^A-Za-z0-9_]/g, '_')
if (sanitized does not match /^[A-Za-z]/)
  username = "u_" + sanitized
else
  username = sanitized
```

**Reference (app implementation):** `lib/utils/agora_chat_utils.dart` — function `toAgoraUsername(String userId)`.

---

## 4. What you must do

1. **Validate the JWT and get the user id**  
   Authenticate the request using the Supabase access token. Use the **userId** from the request body and confirm it matches the JWT subject so only the user can delete their own Agora account.

2. **Compute the Agora Chat username**  
   Apply the derivation rule in §3 to the body’s `userId` to get the Agora username.

3. **Call Agora’s REST API to delete the user**  
   - **Method:** `DELETE`  
   - **URL:** `https://{agora_host}/{org_name}/{app_name}/users/{username}`  
     (Use your Agora project’s host, org name, and app name from Agora Console.)  
   - **Header:** `Authorization: Bearer {Agora App Token}`  
     (Server-side Agora App Token with REST API privileges. Do **not** use the user’s token.)

   Official docs: [Agora Chat REST API – User system registration](https://docs.agora.io/en/agora-chat/restful-api/user-system-registration/) (section “Delete a single user”).

4. **Response**  
   - Return **200** or **204** on success.  
   - If Agora returns **404** (user already deleted or never existed), you can treat that as success and still return 200/204.  
   - The app does not fail the overall account deletion if this endpoint returns an error; it continues to call the main account-deletion API.

---

## 5. Summary for your backend

- **Implement:** `POST https://agora.notathletes.com/user/delete`  
  - Auth: Supabase Bearer token (validate request).  
  - Body: `{"userId": "<Supabase user id>"}`.

- **Logic:**  
  - Validate JWT; ensure body `userId` matches authenticated user.  
  - Derive Agora username from `userId` (rule in §3).  
  - Call Agora: `DELETE {agora_base}/users/{username}` with Agora App Token.

- **Respond:** 200 or 204. Non-2xx does not block the client’s account deletion flow.
