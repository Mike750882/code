import Foundation
import SwiftData

// All properties carry defaults and relationships are optional to-many
// arrays, per SwiftData's requirements for CloudKit-backed model schemas.

@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var textScale: Double = 1.0
    /// "system" | "light" | "dark"
    var appearance: String = "system"
    /// Matches a `ColorProfile.id` in `Theme.swift` -- which background/
    /// accent color set the whole app uses for this child.
    var colorProfile: String = "default"
    /// An AVSpeechSynthesisVoice.identifier, or "" to use the device's
    /// default voice for the current locale.
    var voiceIdentifier: String = ""
    /// Used to order profiles in the student switcher.
    var createdAt: Date = Date()

    /// Which `WordInputMode.rawValue` (see `PracticeView.swift`) each
    /// weekday uses for Practice/Test, so a parent can ease a child from
    /// scaffolded tiles up to typing from memory across the week. Defaults
    /// match the built-in progression: some tiles given Monday, all tiles
    /// Tuesday, half tiles/half typed Wednesday, fully typed Thursday.
    /// Four flat fields rather than a dictionary, matching every other
    /// per-child setting on this model.
    var mondayInputMode: String = "tilesScaffolded"
    var tuesdayInputMode: String = "tilesFull"
    var wednesdayInputMode: String = "halfAndHalf"
    var thursdayInputMode: String = "typed"

    @Relationship(deleteRule: .cascade, inverse: \WeekList.child)
    var weekLists: [WeekList]? = []

    @Relationship(deleteRule: .cascade, inverse: \DailyReward.child)
    var dailyRewards: [DailyReward]? = []

    @Relationship(deleteRule: .cascade, inverse: \WeeklyPrize.child)
    var weeklyPrizes: [WeeklyPrize]? = []

    init(name: String) {
        self.name = name
    }
}

extension Child {
    /// weekday matches `Calendar.component(.weekday, from:)`: 2 = Monday
    /// ... 5 = Thursday, same convention Home's daily grade cards use.
    /// Anything else (a weekend) falls back to `.tilesFull` since there's
    /// no weekend slot to configure.
    func inputMode(forWeekday weekday: Int) -> WordInputMode {
        let raw: String
        switch weekday {
        case 2: raw = mondayInputMode
        case 3: raw = tuesdayInputMode
        case 4: raw = wednesdayInputMode
        case 5: raw = thursdayInputMode
        default: raw = WordInputMode.tilesFull.rawValue
        }
        return WordInputMode(rawValue: raw) ?? .tilesFull
    }

    func setInputMode(_ mode: WordInputMode, forWeekday weekday: Int) {
        switch weekday {
        case 2: mondayInputMode = mode.rawValue
        case 3: tuesdayInputMode = mode.rawValue
        case 4: wednesdayInputMode = mode.rawValue
        case 5: thursdayInputMode = mode.rawValue
        default: break
        }
    }

    /// Consecutive Monday-Thursday school days, walking backward from
    /// `now`, with at least one Test-mode attempt recorded that day --
    /// weekends and Fridays are skipped over, neither counting toward nor
    /// breaking the streak, matching the Mon-Thu scope of the daily grade
    /// cards and reward system. Computed live from attempt history rather
    /// than stored/incremented anywhere, so it can never drift out of
    /// sync with what actually happened -- there's no "streak" column on
    /// this model at all.
    ///
    /// Today doesn't break the streak just for not having a test yet,
    /// since the day isn't over: only a *past* school day with no test
    /// stops the count.
    func currentStreak(asOf now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let testDates = Set(
            (weekLists ?? [])
                .flatMap { $0.words ?? [] }
                .flatMap { $0.attempts ?? [] }
                .filter { $0.mode == "test" }
                .map { calendar.startOfDay(for: $0.date) }
        )

        var streak = 0
        var date = calendar.startOfDay(for: now)
        var isFirstSchoolDay = true

        // Bounded to ~10 years of days so this always terminates, even in
        // a pathological case (e.g. a debug seed spanning many years).
        for _ in 0..<3650 {
            let weekday = calendar.component(.weekday, from: date)
            if (2...5).contains(weekday) {
                if testDates.contains(date) {
                    streak += 1
                    isFirstSchoolDay = false
                } else if isFirstSchoolDay && calendar.isDate(date, inSameDayAs: now) {
                    isFirstSchoolDay = false
                } else {
                    break
                }
            }
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previousDay
        }
        return streak
    }
}

@Model
final class WeekList {
    var id: UUID = UUID()
    var weekOf: Date = Date()
    var targetWordCount: Int = 12

    @Relationship(deleteRule: .cascade, inverse: \SpellingWord.weekList)
    var words: [SpellingWord]? = []

    var child: Child?

    init(weekOf: Date, targetWordCount: Int = 12) {
        self.weekOf = weekOf
        self.targetWordCount = targetWordCount
    }
}

@Model
final class SpellingWord {
    var id: UUID = UUID()
    var text: String = ""
    var orderIndex: Int = 0
    /// A parent-recorded pronunciation, played instead of the system voice when present.
    @Attribute(.externalStorage) var customAudioData: Data?

    var weekList: WeekList?

    @Relationship(deleteRule: .cascade, inverse: \PracticeAttempt.word)
    var attempts: [PracticeAttempt]? = []

    init(text: String, orderIndex: Int) {
        self.text = text
        self.orderIndex = orderIndex
    }
}

@Model
final class PracticeAttempt {
    var id: UUID = UUID()
    var date: Date = Date()
    var isCorrect: Bool = false
    /// "practice" | "test" -- which PracticeMode this check happened under.
    /// Home's daily grade cards only count "test" attempts: Practice mode
    /// allows unlimited retries until correct, so mixing it in would make
    /// every day read as 100%.
    var mode: String = "practice"
    /// Shared by every attempt recorded during one PracticeView session
    /// (see PracticeView.sessionID). Lets Home's daily grade compute only
    /// the most recent test session's result for a day, rather than
    /// blending together every time the test was retaken that day.
    var sessionID: UUID = UUID()

    var word: SpellingWord?

    init(isCorrect: Bool, mode: String) {
        self.date = Date()
        self.isCorrect = isCorrect
        self.mode = mode
    }
}

@Model
final class DailyReward {
    var id: UUID = UUID()
    var weekOf: Date = Date()
    /// Calendar.weekday: 2 = Monday ... 5 = Thursday, matching the mockup.
    var weekday: Int = 2
    var rewardText: String = ""
    var thresholdPercent: Int = 70

    var child: Child?

    init(weekOf: Date, weekday: Int, rewardText: String, thresholdPercent: Int) {
        self.weekOf = weekOf
        self.weekday = weekday
        self.rewardText = rewardText
        self.thresholdPercent = thresholdPercent
    }
}

@Model
final class WeeklyPrize {
    var id: UUID = UUID()
    var weekOf: Date = Date()
    var title: String = ""
    var thresholdPercent: Int = 80

    var child: Child?

    init(weekOf: Date, title: String, thresholdPercent: Int) {
        self.weekOf = weekOf
        self.title = title
        self.thresholdPercent = thresholdPercent
    }
}
