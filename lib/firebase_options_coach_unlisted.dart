// Sync `ios` with `ios/Runner/GoogleService-Info-coach-unlisted.plist` (API_KEY,
// GOOGLE_APP_ID, GCM_SENDER_ID, PROJECT_ID, STORAGE_BUCKET).
// Android matches retail coach until you register separate Firebase Android apps.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA0rrC-YRxrJbSBvrKje8-5Ue3m9fcwRcg',
    appId: '1:160658273085:android:d376149a02d1f1786d0b54',
    messagingSenderId: '160658273085',
    projectId: 'not-athletes',
    storageBucket: 'not-athletes.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD_z88-QkqQ0rDlgffe4DuKraw3ub7VN1g',
    appId: '1:160658273085:ios:dd8077eb9cbc59d86d0b54',
    messagingSenderId: '160658273085',
    projectId: 'not-athletes',
    storageBucket: 'not-athletes.firebasestorage.app',
    iosBundleId: 'com.notathletes.coach.unlisted',
  );
}
