#if DEBUG
import Foundation
import SwiftData

/// Seeds a realistic demo profile, word list, and grade history when
/// launched with the `-UITestSeedDemoData` argument -- used by
/// `SpellWellUITests`' screenshot test so App Store screenshots show a
/// populated, good-looking app instead of an empty first-launch state.
/// `#if DEBUG` *and* argument-gated, so this can never run in a real
/// TestFlight/App Store build even by accident -- `fastlane snapshot`
/// builds and runs a Debug (or dedicated Screenshots) configuration on
/// the Simulator, never a release build on a real device.
enum UITestSupport {
    static var isSeedingDemoData: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestSeedDemoData")
    }

    static func seedDemoData(in context: ModelContext) {
        let child = Child(name: "Alex")
        // Every weekday typed from memory rather than the real
        // Mon-Thu tile progression -- the screenshot UI test answers by
        // typing (reliable to automate) regardless of which real-world
        // weekday it happens to run on, and Friday is already always
        // typed, so this just extends that to the rest of the week for
        // this one demo child.
        child.mondayInputMode = WordInputMode.typed.rawValue
        child.tuesdayInputMode = WordInputMode.typed.rawValue
        child.wednesdayInputMode = WordInputMode.typed.rawValue
        context.insert(child)

        let calendar = Calendar.current
        let demoWords = [
            "friend", "because", "thought", "beautiful", "whisper",
            "garden", "shoulder", "quietly", "mountain", "journey"
        ]

        // This week's list, left unanswered -- the UI test itself types
        // through it live, so PracticeResultsView's results (built from
        // the session in memory, not reconstructed from PracticeAttempt)
        // has real content when the screenshot is taken.
        let thisWeek = WeekList(weekOf: Date(), targetWordCount: demoWords.count)
        thisWeek.child = child
        context.insert(thisWeek)
        for (index, text) in demoWords.enumerated() {
            let word = SpellingWord(text: text, orderIndex: index)
            context.insert(word)
            word.weekList = thisWeek
        }

        // A reward for every practice-schedule weekday and a weekly
        // prize, so Rewards and the results screen's reward banner have
        // real content instead of "Set a reward."
        let rewardsByWeekday: [(weekday: Int, text: String)] = [
            (2, "Pick a movie for movie night"),
            (3, "Extra dessert"),
            (4, "Stay up 15 minutes later"),
            (5, "Choose what's for dinner")
        ]
        for (weekday, text) in rewardsByWeekday {
            let reward = DailyReward(weekOf: Date(), weekday: weekday, rewardText: text, thresholdPercent: 80)
            reward.child = child
            context.insert(reward)
        }
        let prize = WeeklyPrize(weekOf: Date(), title: "Trip to the park", thresholdPercent: 85)
        prize.child = child
        context.insert(prize)

        // Three past weeks with improving accuracy, dated to this
        // week's Monday minus N weeks (not just "N weeks before
        // whatever today happens to be") so they land solidly within
        // Mon-Fri regardless of which real-world weekday the
        // screenshots are taken on -- same shape as Settings' own
        // DEBUG "Add sample weeks" helper, just weekday-safe.
        let todayWeekday = calendar.component(.weekday, from: Date())
        let daysSinceMonday = (todayWeekday - 2 + 7) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: calendar.startOfDay(for: Date())) ?? Date()

        let pastWeekResults: [(weeksAgo: Int, correctCount: Int)] = [(3, 6), (2, 8), (1, 9)]
        for (weeksAgo, correctCount) in pastWeekResults {
            guard let weekOf = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisMonday) else { continue }
            let list = WeekList(weekOf: weekOf, targetWordCount: demoWords.count)
            list.child = child
            context.insert(list)
            for (index, text) in demoWords.enumerated() {
                let word = SpellingWord(text: text, orderIndex: index)
                context.insert(word)
                word.weekList = list
                let attempt = PracticeAttempt(isCorrect: index < correctCount, mode: "test")
                attempt.date = weekOf
                attempt.word = word
                context.insert(attempt)
            }
        }

        // Hide the "Take a Tour" banner so Home's screenshot shows the
        // real cards, not an onboarding prompt.
        AppLaunchTracker.dismissTourBanner()

        try? context.save()
    }
}
#endif
