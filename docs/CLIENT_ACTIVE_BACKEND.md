# Client Subscription Status – api.notathletes.com

Current app behavior is subscription handling from the client Settings entry point.
The legacy `check-active` endpoint is no longer used by the app.

## API Endpoints (api.notathletes.com)

### 1. Subscription Status

**GET** `/subscription/status?email={email}`

Returns:

```json
{ "access": true }
```

- `access` (bool): whether this client should be treated as subscribed

### 2. Activate Client (post-IAP/restore sync)

**POST** `/account/activate`

**Body:**

```json
{
  "email": "client@example.com",
  "first_name": "Jane",
  "last_name": "Doe"
}
```

- `email` (required)
- `first_name`, `last_name` (optional)

This call is best-effort sync after purchase/restore success.

## Flow Summary

1. Client signs in/signs up normally.
2. Client opens Settings → Account → Manage subscription.
3. App checks `GET /subscription/status`.
4. If already active, app shows already-subscribed info.
5. If not active, app offers restore/purchase.
6. On restore/purchase success, app calls `POST /account/activate` in background.
