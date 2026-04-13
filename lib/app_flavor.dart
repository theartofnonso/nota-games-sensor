enum AppFlavor {
  coach,
  client,
  /// Internal / unlisted build: same as [client] but no IAP or subscription gate.
  clientUnlisted,
  /// Internal / unlisted build: same as [coach] but no IAP; auto-selects a client.
  coachUnlisted,
}

class AppConfig {
  static AppFlavor _flavor = AppFlavor.client;

  static AppFlavor get flavor => _flavor;

  /// True for both store and unlisted coach builds.
  static bool get isCoach =>
      _flavor == AppFlavor.coach || _flavor == AppFlavor.coachUnlisted;

  /// True for both store and unlisted client builds.
  static bool get isClient =>
      _flavor == AppFlavor.client || _flavor == AppFlavor.clientUnlisted;

  /// App Store / Play store client build (RevenueCat + paywall).
  static bool get isRetailClient => _flavor == AppFlavor.client;

  /// App Store coach build.
  static bool get isRetailCoach => _flavor == AppFlavor.coach;

  /// Unlisted internal distribution (no IAP, no subscription gate).
  static bool get isUnlistedDistribution =>
      _flavor == AppFlavor.clientUnlisted ||
      _flavor == AppFlavor.coachUnlisted;

  static bool get isUnlistedClient => _flavor == AppFlavor.clientUnlisted;

  static bool get isUnlistedCoach => _flavor == AppFlavor.coachUnlisted;

  /// Agora Chat + video calls (retail builds only; unlisted omits messaging/calls UI).
  static bool get supportsChatAndVideoCalls => !isUnlistedDistribution;

  static void setFlavor(AppFlavor flavor) {
    _flavor = flavor;
  }

  static String get appName => switch (_flavor) {
        AppFlavor.coach => 'Not Athletes Coach',
        AppFlavor.coachUnlisted => 'Trainware Coach',
        AppFlavor.clientUnlisted => 'Trainware',
        AppFlavor.client => 'Not Athletes Train',
      };
}
