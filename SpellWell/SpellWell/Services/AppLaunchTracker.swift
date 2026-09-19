import Foundation

/// Tracks how many times the app has been launched since install (or
/// reinstall -- UserDefaults resets when the app is deleted), so Home's
/// "Take a Tour" banner can show itself only for the first couple of
/// launches. Also tracks an early dismissal so closing the banner sticks
/// even within those first two launches.
enum AppLaunchTracker {
    private static let launchCountKey = "appLaunchCount"
    private static let tourBannerDismissedKey = "tourBannerDismissed"

    /// Call exactly once per process launch (from SpellWellApp.init()).
    static func recordLaunch() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: launchCountKey) + 1, forKey: launchCountKey)
    }

    static var launchCount: Int {
        UserDefaults.standard.integer(forKey: launchCountKey)
    }

    static var shouldShowTourBanner: Bool {
        launchCount <= 2 && !UserDefaults.standard.bool(forKey: tourBannerDismissedKey)
    }

    static func dismissTourBanner() {
        UserDefaults.standard.set(true, forKey: tourBannerDismissedKey)
    }

    #if DEBUG
    /// Debug builds only: lets the "first two launches" banner be tested
    /// by relaunching without deleting the whole app (which would also
    /// wipe SwiftData test data). Takes effect on the *next* app launch --
    /// AppLaunchTracker.recordLaunch() runs once per process start, so
    /// resetting mid-session doesn't retroactively show the banner on an
    /// already-running HomeView.
    static func resetForTesting() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: launchCountKey)
        defaults.removeObject(forKey: tourBannerDismissedKey)
    }
    #endif
}
