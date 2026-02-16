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
- If `exists && !is_active`: App shows IAP flow; on success, calls activate
- If `!exists`: App shows survey/signup message

### 2. Activate Client (post-IAP)

**POST** `/account/activate`

**Body:**

```json
{
  "email": "client@example.com",
  "receipt": "<JWS_from_StoreKit2_serverVerificationData>",
  "platform": "ios"
}
```

**Backend must:**

1. Validate receipt with Apple (App Store Server API) or Google Play
2. If valid, `UPDATE public.clients SET is_active = true, updated_at = now() WHERE email = $1`
3. Return 200 or 204 on success

## Flow Summary

1. Client enters email → app calls `GET /account/check-active?email=...`
2. If not active → app runs IAP flow → on success, calls `POST /account/activate`
3. Backend validates receipt and sets `is_active = true`
4. Client proceeds to OTP and sign-in
5. On each auth event, app verifies `clients.is_active` via Supabase; if false, signs out
