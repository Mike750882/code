import SwiftUI

struct HomeView: View {
    let child: Child
    var onOpenGated: (ContentView.GatedDestination) -> Void
    var onStartPractice: (WeekList) -> Void

    @State private var showNoWordsAlert = false

    private var thisWeekList: WeekList? {
        child.weekLists?.sorted(by: { $0.weekOf > $1.weekOf }).first
    }

    private var thisWeekWords: [SpellingWord] {
        (thisWeekList?.words ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var todayCompletedCount: Int {
        let calendar = Calendar.current
        let correctToday = Set(
            thisWeekWords
                .flatMap { $0.attempts ?? [] }
                .filter { $0.isCorrect && calendar.isDateInToday($0.date) }
                .compactMap { $0.word?.id }
        )
        return correctToday.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                practiceCard
                secondaryCards
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Text("Hello, \(child.name)")
                        .font(Theme.display(32))
                        .foregroundStyle(Theme.textPrimary)
                    Button {
                        onOpenGated(.editName)
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let list = thisWeekList {
                    Text("Week of \(list.weekOf.formatted(.dateTime.month(.wide).day())) · \(thisWeekWords.count) words")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "star").foregroundStyle(Theme.blue)
                Text("\(child.currentStreak)-day streak")
                    .font(Theme.body(15, weight: .medium))
                    .foregroundStyle(Theme.blue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(Capsule().stroke(Theme.blue, lineWidth: 1))
        }
    }

    private var practiceCard: some View {
        Button {
            if let list = thisWeekList, !thisWeekWords.isEmpty {
                onStartPractice(list)
            } else {
                showNoWordsAlert = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 33))
                        .foregroundStyle(Theme.coral)
                    Spacer()
                    Text("\(todayCompletedCount) of \(thisWeekWords.count) today")
                        .font(Theme.body(22))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text("Practice spelling list")
                    .font(Theme.display(60))
                    .foregroundStyle(Theme.textPrimary)
                Text("Listen, then build each word from letter tiles.")
                    .font(Theme.body(26))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(42)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(borderColor: Theme.coral, lineWidth: 1.5)
        }
        .buttonStyle(.plain)
        .alert("No words yet", isPresented: $showNoWordsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ask a grown-up to add this week's spelling words first.")
        }
    }

    private var secondaryCards: some View {
        HStack(spacing: 16) {
            SecondaryCard(
                icon: "line.3.horizontal",
                badge: "Grown-ups",
                title: "Add spelling list",
                subtitle: "Type this week's words and set the rewards."
            ) { onOpenGated(.addList) }

            SecondaryCard(
                icon: "star",
                badge: "This week",
                title: weeklyPrizeTitle,
                subtitle: weeklyPrizeSubtitle,
                progress: weeklyPrizeProgress
            ) { onOpenGated(.rewards) }

            SecondaryCard(
                icon: "slider.horizontal.3",
                badge: nil,
                title: "Settings",
                subtitle: "Text size, appearance, PIN and progress."
            ) { onOpenGated(.settings) }
        }
    }

    private var latestWeeklyPrize: WeeklyPrize? {
        child.weeklyPrizes?.sorted(by: { $0.weekOf > $1.weekOf }).first
    }

    private var weeklyPrizeTitle: String {
        latestWeeklyPrize?.title ?? "Set a weekly prize"
    }

    private var weeklyPrizeSubtitle: String {
        guard let prize = latestWeeklyPrize else {
            return "Set this week's prize and how it's earned."
        }
        let earnedPercent = Int((weeklyPrizeProgress * 100).rounded())
        return "Earned at \(prize.thresholdPercent)% for the week. You are at \(earnedPercent)%."
    }

    /// Correct-answer rate across this week's attempts, used as a stand-in
    /// for "progress toward the weekly prize" until a dedicated scoring rule
    /// is defined.
    private var weeklyPrizeProgress: Double {
        let calendar = Calendar.current
        let attemptsThisWeek = thisWeekWords
            .flatMap { $0.attempts ?? [] }
            .filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        guard !attemptsThisWeek.isEmpty else { return 0 }
        let correct = attemptsThisWeek.filter(\.isCorrect).count
        return Double(correct) / Double(attemptsThisWeek.count)
    }
}

private struct SecondaryCard: View {
    let icon: String
    let badge: String?
    let title: String
    let subtitle: String
    var progress: Double?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).foregroundStyle(Theme.purple)
                    Spacer()
                    if let badge {
                        Text(badge.uppercased())
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Theme.blue.opacity(0.5), lineWidth: 1))
                    }
                }
                Text(title)
                    .font(Theme.display(19))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                if let progress {
                    ProgressView(value: progress).tint(Theme.gold)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}
