# Stripe customer delete / unsubscribe (backend spec)

**Audience:** Backend developer implementing the endpoint that unsubscribes or deletes a Stripe customer when a client deletes their account. The app only sends the request; your backend performs the Stripe logic (cancel subscriptions, delete customer, etc.).

---

## 1. Endpoint you need to implement

| Item | Value |
|------|--------|
| **Base URL** | `https://stripe.notathletes.com` (existing Stripe backend) |
| **Path** | `POST /customer/delete` |
| **Purpose** | Unsubscribe and/or delete the requesting user’s Stripe customer so they are no longer billed and customer data is removed from Stripe. |

The Flutter app calls this during account deletion (after Agora user delete, before the main account/delete call). If your endpoint returns an error, the app still continues with account deletion; a non-2xx response does not block the user.

---

## 2. What the app sends

| Item | Value |
|------|--------|
| **Method** | `POST` |
| **Headers** | `Content-Type: application/json`<br>`Authorization: Bearer <Supabase access token>` |
| **Body** | `{"userId": "<Supabase user id>"}` |

Same pattern as your existing Stripe endpoint (`/checkSubscription` uses `email` in the body). For delete we send **userId** so you can resolve the Stripe customer (e.g. via your DB or by looking up by email from the JWT/user record). Validate the JWT and ensure the authenticated user matches the body’s `userId`.

---

## 3. What you must do

1. **Validate the JWT**  
   Authenticate the request using the Supabase access token. Confirm the authenticated user matches the body’s `userId`.

2. **Resolve the Stripe customer**  
   Use your existing logic (e.g. user id → email → Stripe customer id, or a stored mapping) to find the Stripe customer for this user.

3. **Unsubscribe / delete in Stripe**  
   Implement whatever Stripe logic you need: cancel active subscriptions, delete the customer, etc. This is entirely backend-defined.

4. **Response**  
   - Return **200** or **204** on success.  
   - If the user has no Stripe customer (e.g. never subscribed), you can treat that as success and return 200/204.  
   - The app does not fail account deletion if this endpoint returns an error; it continues to call the main account-deletion API.

---

## 4. Summary for your backend

- **Implement:** `POST https://stripe.notathletes.com/customer/delete`  
  - Auth: Supabase Bearer token (validate request).  
  - Body: `{"userId": "<Supabase user id>"}`.

- **Logic:**  
  - Validate JWT; ensure body `userId` matches authenticated user.  
  - Resolve Stripe customer for that user; cancel subscriptions and/or delete customer as needed.

- **Respond:** 200 or 204. Non-2xx does not block the client’s account deletion flow.
