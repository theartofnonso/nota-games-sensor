import UIKit
import Flutter
import AgoraChat
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let lastBoundAPNSTokenKey = "lastBoundAPNSToken"

  private func deviceTokenHexString(from data: Data) -> String {
    return data.map { String(format: "%02.2hhx", $0) }.joined()
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Notification permission + delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // Register with APNs (native)
    application.registerForRemoteNotifications()

    // Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("🔑 APNs device token: \(deviceTokenHexString(from: deviceToken))")
    // Convert token to hex for stable comparison and caching
    let tokenHex = deviceTokenHexString(from: deviceToken)
    let defaults = UserDefaults.standard
    let lastToken = defaults.string(forKey: lastBoundAPNSTokenKey)

    if lastToken != tokenHex {
      // Bind new/changed token to Agora Chat per documentation
      AgoraChatClient.shared().bindDeviceToken(deviceToken)
      defaults.set(tokenHex, forKey: lastBoundAPNSTokenKey)
      print("📮 Bound APNs token to Agora Chat (new or changed).")
    } else {
      print("ℹ️ APNs token unchanged; skipping Agora Chat re-bind.")
    }

    super.application(
      application,
      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
    )
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error)")
  }
}

