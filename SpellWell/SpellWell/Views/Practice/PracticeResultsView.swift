import SwiftUI

struct WordResult: Identifiable {
    let id = UUID()
    let word: String
    /// What the child actually spelled, letter tiles as tapped -- shown next
    /// to the correct word for anything marked wrong.
    let attempt: String
    let isCorrect: Bool
}

/// Shown after the last word in a practice session: a test-style score and
/// letter grade, plus a right/wrong breakdown of every word.
struct PracticeResultsView: View {
    let results: [WordResult]
    /// Only Test results count toward the day's reward -- Practice (used
    /// both for open-ended rehearsing and for retaking a day's missed
    /// words) never affects it, same as it never affects the recorded
    /// grade.
    let mode: PracticeMode
    let child: Child?
    var onDone: () -> Void

    private var correctCount: Int {
        results.filter(\.isCorrect).count
    }

    private var percent: Int {
        guard !results.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(results.count) * 100).rounded())
    }

    private var grade: String { Grading.letter(forPercent: percent) }
    private var gradeColor: Color { Grading.color(forPercent: percent) }

    /// Today's reward, if a grown-up has set one for this weekday --
    /// matches the same "keyed by weekday only" lookup Rewards/Home
    /// already use, not scoped to a particular `weekOf`.
    private var todaysReward: DailyReward? {
        guard mode == .test, let child else { return nil }
        let weekday = Calendar.current.component(.weekday, from: Date())
        return child.dailyRewards?.first(where: { $0.weekday == weekday })
    }

    private var earnedTodaysReward: Bool {
        guard let reward = todaysReward else { return false }
        return percent >= reward.thresholdPercent
    }

    /// The whole screen scrolls, not just the word list in a fixed-height
    /// sub-region -- in landscape on an iPhone (much less vertical room
    /// than portrait), the score card alone could take up nearly all the
    /// available height, leaving the word list squeezed down to barely
    /// any of its own 320pt cap and the rest of the words unreachable.
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreCard
                if let reward = todaysReward {
                    rewardStatus(reward)
                }
                wordList
                Button("Back to Home", action: onDone)
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.primary, lineWidth: 1.5))
            }
            .frame(maxWidth: 520)
            .padding(.vertical, 24)
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 8) {
            Text(grade)
                .font(Theme.display(72, weight: .medium))
                .foregroundStyle(gradeColor)
            Text("\(percent)%")
                .font(Theme.display(24))
                .foregroundStyle(Theme.textPrimary)
            Text("\(correctCount) of \(results.count) words correct")
                .font(Theme.body(15))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .card(borderColor: gradeColor, lineWidth: 1.5)
    }

    private func rewardStatus(_ reward: DailyReward) -> some View {
        VStack(spacing: 4) {
            Text(earnedTodaysReward ? "Reward earned!" : "Reward not quite earned yet")
                .font(Theme.body(15, weight: .semibold))
                .foregroundStyle(earnedTodaysReward ? Theme.success : Theme.textPrimary)
            Text(earnedTodaysReward
                ? "\(percent)% meets today's goal of \(reward.thresholdPercent)% -- \(reward.rewardText) is earned!"
                : "\(percent)% is under today's goal of \(reward.thresholdPercent)% needed for \(reward.rewardText).")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .card(borderColor: earnedTodaysReward ? Theme.success : Theme.hairline, lineWidth: earnedTodaysReward ? 1.5 : 1)
    }

    private var wordList: some View {
        // No longer its own nested ScrollView with a fixed height cap --
        // the whole screen scrolls now (see body), so this just lays out
        // the rows directly.
        VStack(spacing: 0) {
            ForEach(results) { result in
                wordRow(result)
                Divider().overlay(Theme.hairline)
            }
        }
    }

    private func wordRow(_ result: WordResult) -> some View {
        HStack {
            Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.isCorrect ? Theme.success : Theme.error)
            // Shown exactly as stored/typed, not .capitalized -- forcing
            // first-letter-capital, rest-lowercase would misrepresent the
            // correct spelling for any word with case elsewhere in it, and
            // would hide a case-only mistake (e.g. "paris" typed for
            // "Paris") from whoever's reviewing this screen.
            Text(result.word)
                .font(Theme.body(17))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if result.isCorrect {
                Text("Correct")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("My spelling")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(result.attempt.isEmpty ? "(blank)" : result.attempt)
                        .font(Theme.body(15, weight: .medium))
                        .foregroundStyle(Theme.error)
                }
            }
        }
        .padding(.vertical, 12)
    }
}
