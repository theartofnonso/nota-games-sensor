# FCM payload spec for app deep links

Handover for backend: structure of the **FCM `data` payload** so that when the user **taps the notification**, the app opens the correct screen (e.g. a specific session / routine log).

---

## 1. General rules

- Use the FCM **`data`** map for tap handling. The app reads this when the user taps the notification and navigates accordingly.
- **All values in `data` must be strings** (FCM requirement).
- Include both **notification** (title, body) and **data** in the message so the device shows a notification and the app can react on tap.

---

## 2. Open a specific session (routine log) — `view_log`

Use this when the tap should open a single session (routine log) screen.

### `data` keys

| Key     | Type   | Required | Description |
|--------|--------|----------|-------------|
| `type` | string | Yes      | Must be `"view_log"`. |
| `logId`| string | Yes      | The routine log UUID (e.g. `550e8400-e29b-41d4-a716-446655440000`). |

### When to send

| Scenario | Recipient | `type`     | `logId` |
|----------|-----------|------------|---------|
| Coach added/updated feedback on a session | **Client** (device tokens for that client) | `view_log` | That session’s routine log ID |
| Client logged a session | **Coach** (device tokens for that coach) | `view_log` | That session’s routine log ID |

### Example FCM payload (conceptual)

```json
{
  "message": {
    "token": "<device FCM token>",
    "notification": {
      "title": "Session feedback",
      "body": "Your coach left feedback on your session."
    },
    "data": {
      "type": "view_log",
      "logId": "550e8400-e29b-41d4-a716-446655440000"
    }
  }
}
```

Minimal **data** only (what the app needs on tap):

```json
{
  "type": "view_log",
  "logId": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## 3. Backend endpoints (request body)

The app calls your backend with the following bodies. Backend should send FCM with the `data` payload in section 2 using the `logId` from the request.

### POST `/notify-coach-feedback`

**Request body:**
```json
{
  "userId": "<client-uuid>",
  "logId": "<routine-log-uuid>"
}
```
- `userId`: client to notify (their device tokens).
- `logId`: routine log ID for the session the coach just added/updated feedback on.

**Backend:** Send FCM to the **client’s** device token(s) with `data: { "type": "view_log", "logId": "<logId from body>" }`.

---

### POST `/notify-workout-log`

**Request body:**
```json
{
  "userId": "<client-uuid>",
  "logId": "<routine-log-uuid>"
}
```
- `userId`: client who logged the session (backend resolves **coach** from this client and notifies the coach).
- `logId`: routine log ID for the session that was just logged.

**Backend:** Resolve coach for that client, then send FCM to the **coach’s** device token(s) with `data: { "type": "view_log", "logId": "<logId from body>" }`.

---

## 4. Other type: `chat`

If the notification is for opening **chat**, use:

```json
{
  "type": "chat"
}
```

No `logId`. (Other params may be required for chat; this doc focuses on session deep links.)

---

## 5. Summary

- **Session deep link:** `data.type = "view_log"` and `data.logId = "<routine_log_uuid>"`.
- **Recipient:** client for “coach feedback”, coach for “client logged session”.
- **All `data` values:** strings only.

If `logId` is missing or empty, the app will not navigate to a session on tap.
