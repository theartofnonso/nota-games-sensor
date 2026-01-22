enum AppFlavor {
  coach,
  client,
}

class AppConfig {
  static AppFlavor _flavor = AppFlavor.client;

  static AppFlavor get flavor => _flavor;
  static bool get isCoach => _flavor == AppFlavor.coach;
  static bool get isClient => _flavor == AppFlavor.client;

  static void setFlavor(AppFlavor flavor) {
    _flavor = flavor;
  }

  static String get appName =>
      _flavor == AppFlavor.coach ? 'Not Athletes Coach' : 'Not Athletes';
}
