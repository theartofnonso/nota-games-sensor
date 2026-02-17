# Client Active Status – api.notathletes.com

The Trackr client app enforces that only **active subscribers** can sign in. Client records are created in another project (e.g. survey/onboarding). This app calls `api.notathletes.com` to check/activate; the backend updates `clients.is_active` after successful IAP.

## Database

The `public.clients` table has:

- `is_active` (boolean NOT NULL DEFAULT false) – true only after successful IAP; inactive clients cannot sign in.

Migration: `supabase/migrations/20260215000000_clients_is_active.sql`

## API Endpoints (api.notathletes.com)

### 1. Check Active (pre-auth)

**GET** `/account/check-active?email={email}`

Returns `{ "exists": bool, "is_active": bool }`.

- `exists`: Client with this email exists in `public.clients`
- `is_active`: `clients.is_active` for that row

**Behavior:**
- If `exists && is_active`: Client may proceed to OTP
- If `!exists` or `exists && !is_active`: App shows IAP flow; on success, calls activate. Backend creates client if new.

### 2. Activate Client (post-IAP)

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

**Behavior:**

1. If client doesn't exist: create auth user (Supabase Admin API) if needed, then `INSERT INTO clients (id, email, name, is_active) VALUES (...)`
2. If client exists: `UPDATE clients SET is_active = true, updated_at = now() WHERE email = $1`
3. Return 200 or 204 on success

### Testing with curl

Minimal:

```bash
curl -X POST http://localhost:3000/account/activate \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

With optional fields:

```bash
curl -X POST http://localhost:3000/account/activate \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","first_name":"Jane","last_name":"Doe"}'
```

## Flow Summary

1. Client enters email → app calls `GET /account/check-active?email=...`
2. If not active → app runs IAP flow → on success, calls `POST /account/activate` (email, first_name, last_name only)
3. Backend creates/updates client and sets `is_active = true`
4. Client proceeds to OTP and sign-in
5. On each auth event, app verifies `clients.is_active` via Supabase; if false, signs out
