/// trainware
const trackrWebUrl = 'https://notathletes.com';
const instagramUrl = 'https://www.instagram.com/notathletes';

/// Pexels
const pexelsImageUrl =
    'https://www.pexels.com/photo/man-and-woman-doing-push-up-face-to-face-6740308/';

/// API Endpoints
const routineLogs = '/routine-logs';

/// Agora Endpoints
const agoraBaseUrl = 'https://agora.notathletes.com';
const agoraTokenPath = '/chat-token';
const agoraVideoTokenPath = '/video-token';

/// Delete current user from Agora Chat (called during account deletion; backend performs the Agora REST delete).
const agoraUserDeletePath = '/user/delete';

/// OpenAI (openai.notathletes.com)
const openAiBaseUrl = 'https://openai.notathletes.com';

/// POST /nutrition – body { "meal": "string" }
const nutritionEstimatePath = '/nutrition';

/// POST /query – body { "query", "client_id", optional filters }.
/// Response is a final backend-computed answer: { "answer": "..." }.
const aiQueryPath = '/query';

/// api.notathletes.com – account and client endpoints.
const apiNotathletesBaseUrl = 'https://api.notathletes.com';
const accountDeletionPath = '/account/delete';
const subscriptionStatusPath = '/subscription/status';
const accountActivatePath = '/account/activate';
