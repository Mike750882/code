import SwiftUI
import SwiftData

@main
struct SpellWellApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        // A fresh install/reinstall clears UserDefaults but not the
        // Keychain -- Keychain items are tied to the device, not to a
        // particular install, by iOS design (deliberate, so the PIN
        // survives an app update; see KeychainService's doc comment).
        // Without this, deleting and reinstalling to get a clean slate
        // would keep silently accepting the old PIN forever, with no way
        // to set a new one short of remembering the old one to reach
        // "Change PIN" in Settings. Detected via AppLaunchTracker's own
        // launch count (0 only on a genuinely fresh install, since it's
        // UserDefaults-backed and resets on delete) -- if that's 0 but a
        // PIN still exists, it's stale, left over from before this install.
        if AppLaunchTracker.launchCount == 0 && KeychainService.hasPIN() {
            KeychainService.clearPIN()
        }
        AppLaunchTracker.recordLaunch()
        do {
            let schema = Schema([
                Child.self, WeekList.self, SpellingWord.self,
                PracticeAttempt.self, DailyReward.self, WeeklyPrize.self
            ])

            var configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            #if DEBUG
            // Screenshot runs (fastlane snapshot / SpellWellUITests) use
            // an in-memory, non-CloudKit store instead -- fast,
            // deterministic, and independent of whether the Simulator
            // has an iCloud account signed in, unlike the real app's
            // persistent CloudKit-backed store.
            if UITestSupport.isSeedingDemoData {
                configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            }
            #endif

            container = try ModelContainer(for: schema, configurations: [configuration])

            #if DEBUG
            if UITestSupport.isSeedingDemoData {
                UITestSupport.seedDemoData(in: container.mainContext)
            }
            #endif
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
