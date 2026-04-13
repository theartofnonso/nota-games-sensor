import 'app_flavor.dart';
import 'main.dart' as app;

/// Internal / unlisted coach: no client picker (auto-selects first / [UnlistedDistributionConfig]).
Future<void> main() async {
  await app.mainCommon(AppFlavor.coachUnlisted);
}
