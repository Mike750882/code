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

    /// The whole screen scrolls, not just the word list in a fixed-height
    /// sub-region -- in landscape on an iPhone (much less vertical room
    /// than portrait), the score card alone could take up nearly all the
    /// available height, leaving the word list squeezed down to barely
    /// any of its own 320pt cap and the rest of the words unreachable.
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreCard
                wordList
                Button("Back to Home", action: onDone)
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
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
                .foregroundStyle(result.isCorrect ? Theme.green : Theme.coral)
            Text(result.word.capitalized)
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
                    Text(result.attempt.isEmpty ? "(blank)" : result.attempt.capitalized)
                        .font(Theme.body(15, weight: .medium))
                        .foregroundStyle(Theme.coral)
                }
            }
        }
        .padding(.vertical, 12)
    }
}
