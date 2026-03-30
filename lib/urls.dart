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

/// POST /exercise – body { "exercise": "string" } or { "name": "string" }
const exerciseInstructionPath = '/exercise';

/// api.notathletes.com – account and client endpoints.
const apiNotathletesBaseUrl = 'https://api.notathletes.com';
const accountDeletionPath = '/account/delete';
const accountProfilePath = '/account/profile';
/// POST body `{ fullName, email, coachId }` — see [ClientAcquisitionSignupService].
const clientCoachSignupPath = '/client-coach-signup';
const coachClientsPath = '/coach-clients';

/// GET /coach-profiles — list coach profiles; GET /coach-profiles/:id — one profile.
const coachProfilesPath = '/coach-profiles';

/// fcm.notathletes.com — push coach when a client gains subscription (client app).
const fcmNotathletesBaseUrl = 'https://fcm.notathletes.com';
/// POST body `{ "userId": "<client-uuid>" }`, `Authorization: Bearer <Supabase access token>`.
const notifyClientAssignedPath = '/notify-client-assigned';
