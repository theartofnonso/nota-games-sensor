import '../../dtos/coach_dto.dart';

/// Shared [Hero.tag] for the coach photo when opening the subscription paywall
/// from [ClientSubscribePromptCard] (or any screen that uses the same tag).
Object coachPaywallHeroTag(CoachDto? coach) =>
    'trainware_coach_paywall_photo_${coach?.id ?? 'none'}';
