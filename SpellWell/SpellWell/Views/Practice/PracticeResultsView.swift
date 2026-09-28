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

    /// Drives the grade letter's entrance bounce and the confetti burst --
    /// starts false so both animate in from `scoreCard`'s `.onAppear`
    /// rather than the animated state ever being true on first render.
    @State private var hasAppeared = false

    private var correctCount: Int {
        results.filter(\.isCorrect).count
    }

    private var percent: Int {
        guard !results.isEmpty else { return 0 }
        return Int((Double(correctCount) / Double(results.count) * 100).rounded())
    }

    private var grade: String { Grading.letter(forPercent: percent) }
    private var gradeColor: Color { Grading.color(forPercent: percent) }
    /// A or B (80% and up, matching Grading.letter's B- cutoff) -- the
    /// threshold for celebrating with a confetti burst on top of the
    /// grade letter's entrance bounce, which every grade gets.
    private var isTopGrade: Bool { percent >= 80 }

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

    /// A Speagle cheer tiered by score -- generic and grade-based only,
    /// same as Practice's encouragement tips, not tied to which specific
    /// words were missed.
    private var cheerMessage: String {
        switch percent {
        case 90...: return "Amazing job! You're a spelling star!"
        case 70..<90: return "Great work! You're getting really good at this!"
        case 50..<70: return "Nice effort! A little more practice and you'll have it."
        default: return "That's okay -- every mistake helps you learn. Let's try again soon!"
        }
    }

    /// Cheer pose only for a genuinely good result -- matches `isTopGrade`'s
    /// own 80% (A/B) bar for the confetti burst, so Speagle's wings only
    /// go up alongside the confetti, not for an "okay" score that just
    /// happens to clear a lower bar.
    private var cheerPose: SpeaglePose { isTopGrade ? .cheer : .think }

    /// The whole screen scrolls, not just the word list in a fixed-height
    /// sub-region -- in landscape on an iPhone (much less vertical room
    /// than portrait), the score card alone could take up nearly all the
    /// available height, leaving the word list squeezed down to barely
    /// any of its own 320pt cap and the rest of the words unreachable.
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreCard
                SpeagleTip(message: cheerMessage, pose: cheerPose)
                if let reward = todaysReward {
                    rewardStatus(reward)
                }
                wordList
                Button("Back to Home", action: onDone)
                    .accessibilityIdentifier("backToHomeButton")
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
            ZStack {
                if isTopGrade {
                    ConfettiBurst()
                }
                Text(grade)
                    .font(Theme.display(72, weight: .medium))
                    .foregroundStyle(gradeColor)
                    .scaleEffect(hasAppeared ? 1 : 0.4)
                    .opacity(hasAppeared ? 1 : 0)
            }
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                hasAppeared = true
            }
        }
    }

    /// A shower of colored confetti pieces that fall and tumble past the
    /// grade letter -- pure SwiftUI, no image assets or third-party
    /// library. Uses a fixed festive palette rather than a theme color:
    /// confetti's whole appeal is being multicolored, the same way
    /// `Theme.success`/`Theme.error` are fixed regardless of theme for a
    /// different reason (a consistent right/wrong meaning).
    private struct ConfettiBurst: View {
        private struct Piece: Identifiable {
            let id = UUID()
            let color: Color
            let startX: CGFloat
            let delay: Double
            let duration: Double
            let rotation: Double
            let size: CGFloat
        }

        private static let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

        // A default @State initial value is computed once, when this
        // view's identity first appears -- not recomputed on every parent
        // re-render -- so each piece's random path stays stable for the
        // whole animation instead of jumping mid-fall.
        @State private var pieces: [Piece] = (0..<24).map { index in
            Piece(
                color: colors[index % colors.count],
                startX: CGFloat.random(in: -110...110),
                delay: Double.random(in: 0...0.25),
                duration: Double.random(in: 1.0...1.5),
                rotation: Double.random(in: 200...600) * (Bool.random() ? 1 : -1),
                size: CGFloat.random(in: 7...12)
            )
        }
        @State private var isAnimating = false

        var body: some View {
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.45)
                        .rotationEffect(.degrees(isAnimating ? piece.rotation : 0))
                        .offset(x: piece.startX, y: isAnimating ? 170 : -30)
                        .opacity(isAnimating ? 0 : 1)
                        .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: isAnimating)
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                isAnimating = true
            }
        }
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
