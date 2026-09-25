import UIKit
import UserNotifications

/// A minimal AppDelegate, only to register as `UNUserNotificationCenter`'s
/// delegate -- needed so a tap on the Friday reminder notification (see
/// `NotificationService`) can route straight to that day's test screen
/// instead of just opening to Home like a normal launch.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Show the notification's banner/sound even if the app happens to
    /// already be in the foreground when it fires.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.identifier == NotificationService.fridayReminderIdentifier {
            NotificationRouter.shared.pendingFridayTest = true
        }
        completionHandler()
    }
}

/// Bridges the notification-tap event -- handled by `AppDelegate`, outside
/// any SwiftUI view -- into `ContentView`, which observes
/// `pendingFridayTest` and, when it flips true, navigates straight to
/// Friday's test screen.
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    private init() {}

    @Published var pendingFridayTest = false
}
