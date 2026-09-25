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
            let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: [configuration])
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
