import Foundation
import SwiftData

// All properties carry defaults and relationships are optional to-many
// arrays, per SwiftData's requirements for CloudKit-backed model schemas.

@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var currentStreak: Int = 0
    var textScale: Double = 1.0
    /// "system" | "light" | "dark"
    var appearance: String = "system"
    /// An AVSpeechSynthesisVoice.identifier, or "" to use the device's
    /// default voice for the current locale.
    var voiceIdentifier: String = ""

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
