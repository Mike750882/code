import SwiftUI
import SwiftData

@main
struct SpellWellApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
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
