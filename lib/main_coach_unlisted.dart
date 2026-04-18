import 'app_flavor.dart';
import 'main.dart' as app;

/// Internal / unlisted coach: same shell as retail coach; pick a client from the list.
Future<void> main() async {
  await app.mainCommon(AppFlavor.coachUnlisted);
}
