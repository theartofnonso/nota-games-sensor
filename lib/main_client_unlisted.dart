import 'app_flavor.dart';
import 'main.dart' as app;

/// Internal / unlisted client: no IAP, no subscription gate, same Firebase as retail client.
Future<void> main() async {
  await app.mainCommon(AppFlavor.clientUnlisted);
}
