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

    var body: some View {
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
        ScrollView {
            VStack(spacing: 0) {
                ForEach(results) { result in
                    wordRow(result)
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .frame(maxHeight: 320)
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
