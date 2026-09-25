import Foundation
import UserNotifications

/// Schedules (or cancels) the Friday "Practice For Today's Test" reminder
/// -- a local, on-device notification (no server/push involved), fired at
/// a parent-set time from Settings. Requests notification permission the
/// first time a parent turns the reminder on; tapping it is routed to
/// Friday's test screen by `AppDelegate` + `NotificationRouter`.
enum NotificationService {
    static let fridayReminderIdentifier = "fridayTestReminder"

    /// Re-reads `child`'s current settings and either schedules or cancels
    /// the Friday reminder to match -- call this any time
    /// `fridayNotificationEnabled`/Hour/Minute changes, not just once.
    /// `completion` reports whether the reminder is actually active
    /// (always called on the main thread), so a Settings row can show a
    /// "turned off in iOS Settings" hint when permission was denied.
    static func syncFridayReminder(for child: Child, completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        guard child.fridayNotificationEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [fridayReminderIdentifier])
            DispatchQueue.main.async { completion(true) }
            return
        }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                schedule(hour: child.fridayNotificationHour, minute: child.fridayNotificationMinute)
            } else {
                center.removePendingNotificationRequests(withIdentifiers: [fridayReminderIdentifier])
            }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    private static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Practice For Today's Test"
        content.body = "Review this week's words or jump into today's spelling test."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = 6 // Calendar.weekday: 1 = Sunday ... 6 = Friday.
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: fridayReminderIdentifier, content: content, trigger: trigger)
        // Adding a request with an identifier that already has a pending
        // (not yet delivered) request replaces it, so changing the time in
        // Settings doesn't need an explicit remove-then-add.
        UNUserNotificationCenter.current().add(request)
    }
}
