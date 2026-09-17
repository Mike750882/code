import SwiftUI

struct WordResult: Identifiable {
    let id = UUID()
    let word: String
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

    private var grade: String {
        switch percent {
        case 90...: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    private var gradeColor: Color {
        percent >= 70 ? Theme.green : Theme.coral
    }

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
                    HStack {
                        Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(result.isCorrect ? Theme.green : Theme.coral)
                        Text(result.word.capitalized)
                            .font(Theme.body(17))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(result.isCorrect ? "Correct" : "Try again next time")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 12)
                    Divider().overlay(Theme.hairline)
                }
            }
        }
        .frame(maxHeight: 320)
    }
}
