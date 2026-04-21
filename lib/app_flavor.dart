enum AppFlavor {
  coach,
  client,
  /// Internal / unlisted build: same as [client] but no IAP or subscription gate.
  clientUnlisted,
}

class AppConfig {
  static AppFlavor _flavor = AppFlavor.client;

  static AppFlavor get flavor => _flavor;

  /// Coach build loads [CoachClientsService] and `/coach`.
  static bool get loadsCoachClientRoster => _flavor == AppFlavor.coach;

  static bool get isCoach => loadsCoachClientRoster;

  /// True for both store and unlisted client builds.
  static bool get isClient =>
      _flavor == AppFlavor.client || _flavor == AppFlavor.clientUnlisted;

  /// App Store / Play store client build (RevenueCat + paywall).
  static bool get isRetailClient => _flavor == AppFlavor.client;

  /// App Store coach build.
  static bool get isRetailCoach => _flavor == AppFlavor.coach;

  /// Unlisted internal distribution (no IAP, no subscription gate).
  static bool get isUnlistedDistribution => _flavor == AppFlavor.clientUnlisted;

  static bool get isUnlistedClient => _flavor == AppFlavor.clientUnlisted;

  /// Agora Chat UI Kit (1:1 messaging). Enabled for retail and unlisted builds.
  static bool get supportsAgoraChat => true;

  /// Agora RTC voice/video and incoming-call UX. Disabled for unlisted (chat-only).
  static bool get supportsVideoCalls => !isUnlistedDistribution;

  static void setFlavor(AppFlavor flavor) {
    _flavor = flavor;
  }

  static String get appName => switch (_flavor) {
        AppFlavor.coach => 'Not Athletes Coach',
        AppFlavor.clientUnlisted => 'Trainware',
        AppFlavor.client => 'Not Athletes Train',
      };
}
