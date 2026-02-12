/// trainware
const trackrWebUrl = 'https://notathletes.com';
const instagramUrl = 'https://www.instagram.com/notathletes';

/// Pexels
const pexelsImageUrl =
    'https://www.pexels.com/photo/man-and-woman-doing-push-up-face-to-face-6740308/';

/// API Endpoints
const routineLogs = '/routine-logs';

/// Stripe Endpoints
const stripeBaseUrl = 'https://stripe.notathletes.com';
/// POST /checkSubscription - body: {email}, response: {hasActiveSubscription, isCustomer}
const checkStripeSubscriptionPath = '/checkSubscription';
/// GET /products - returns {products: [{priceId, productId, productName, amount, currency, interval, intervalCount}, ...]}
const stripeProductsPath = '/products';
/// POST /subscription/resubscribe - body: {email, price_id}. Backend handles success page.
/// Response (201): {checkout_url, session_id}. Client opens checkout_url in browser.
const stripeResubscribePath = '/subscription/resubscribe';
/// POST /subscription/cancel - auth required, body: {userId}, response: 204
const stripeSubscriptionCancelPath = '/subscription/cancel';
/// POST /customer/delete - auth required, body: {userId}, response: 204
const stripeCustomerDeletePath = '/customer/delete';

/// Agora Endpoints
const agoraBaseUrl = 'https://agora.notathletes.com';
const agoraTokenPath = '/chat-token';
const agoraVideoTokenPath = '/video-token';

/// Delete current user from Agora Chat (called during account deletion; backend performs the Agora REST delete).
const agoraUserDeletePath = '/user/delete';

/// Nutrition estimate (OpenAI) – POST /nutrition, body { "meal": "string" }
const nutritionEstimateBaseUrl = 'https://openai.notathletes.com';
const nutritionEstimatePath = '/nutrition';

/// Account deletion (client only). Backend deletes auth user and relies on DB CASCADE.
const accountDeletionBaseUrl = 'https://api.notathletes.com';
const accountDeletionPath = '/account/delete';
