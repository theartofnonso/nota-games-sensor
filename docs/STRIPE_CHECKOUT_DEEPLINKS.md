# Stripe Checkout (Resubscribe)

For the resubscribe flow, the client sends `email` and `price_id` to the backend. The backend creates a Checkout Session and returns `checkout_url`. The client opens it in a browser.

**Success and cancel are handled by the backend**—the user sees a success page in the browser and is told to return to the app and sign in again. Same flow as first-time subscribe after the survey.
