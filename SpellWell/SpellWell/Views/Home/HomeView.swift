import SwiftUI

struct HomeView: View {
    let child: Child
    var onOpenGated: (ContentView.GatedDestination) -> Void
    var onStartPractice: (WeekList, PracticeMode) -> Void

    @State private var showNoWordsAlert = false
    @State private var mode: PracticeMode = .practice
    @State private var showTourBanner = AppLaunchTracker.shouldShowTourBanner
    @State private var showTour = false
    @State private var isTourBannerPulsing = false

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
                modeToggle
                practiceCard
                secondaryCards
                dailyGradeCards
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .sheet(isPresented: $showTour) {
            TourView()
        }
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
            if showTourBanner {
                tourBanner
                Spacer()
            }
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

    /// Only shown for the first two app launches (AppLaunchTracker), or
    /// until dismissed -- "Take a Tour" always stays reachable from
    /// Settings for anyone who wants it again later.
    private var tourBanner: some View {
        HStack(spacing: 12) {
            Button {
                showTour = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.purple)
                    Text("Take a Tour")
                        .font(Theme.body(17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .buttonStyle(.plain)

            Button {
                AppLaunchTracker.dismissTourBanner()
                showTourBanner = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.purple, lineWidth: 1.5))
        .shadow(color: Theme.purple.opacity(isTourBannerPulsing ? 0.55 : 0.15), radius: isTourBannerPulsing ? 12 : 4)
        .scaleEffect(isTourBannerPulsing ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isTourBannerPulsing = true
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 14) {
            Picker("Mode", selection: $mode) {
                ForEach(PracticeMode.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Text(mode.description)
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)

            Spacer()
        }
    }

    private var practiceCard: some View {
        Button {
            if let list = thisWeekList, !thisWeekWords.isEmpty {
                onStartPractice(list, mode)
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
                Text(mode == .test ? "Take spelling test" : "Practice spelling list")
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

    private static let weekdayLabels: [(weekday: Int, label: String)] = [
        (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"), (5, "Thursday")
    ]

    private var dailyGradeCards: some View {
        HStack(spacing: 16) {
            ForEach(Self.weekdayLabels, id: \.weekday) { entry in
                DayGradeCard(label: entry.label, percent: testPercent(onWeekday: entry.weekday))
            }
        }
    }

    /// Score for that weekday's Test-mode attempts this week, or nil if the
    /// child hasn't taken a test that day yet. Practice-mode attempts are
    /// excluded on purpose -- see the note on PracticeAttempt.mode. If the
    /// test was taken more than once that day, only the most recent
    /// session (PracticeAttempt.sessionID) counts, not a blend of every
    /// attempt -- retaking a test replaces that day's grade rather than
    /// averaging into it.
    private func testPercent(onWeekday weekday: Int) -> Int? {
        let calendar = Calendar.current
        let now = Date()
        let attempts = thisWeekWords
            .flatMap { $0.attempts ?? [] }
            .filter {
                $0.mode == "test"
                    && calendar.component(.weekday, from: $0.date) == weekday
                    && calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear)
            }
        guard let mostRecentSessionID = attempts.max(by: { $0.date < $1.date })?.sessionID else { return nil }
        let latestSession = attempts.filter { $0.sessionID == mostRecentSessionID }
        guard !latestSession.isEmpty else { return nil }
        let correct = latestSession.filter(\.isCorrect).count
        return Int((Double(correct) / Double(latestSession.count) * 100).rounded())
    }
}

private struct DayGradeCard: View {
    let label: String
    let percent: Int?

    var body: some View {
        VStack(spacing: 10) {
            Text(label)
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
            Text(percent.map { "Grade: \(Grading.letter(forPercent: $0))" } ?? "No test yet")
                .font(Theme.display(percent != nil ? 24 : 19))
                .foregroundStyle(percent != nil ? Theme.textPrimary : Theme.textSecondary)
            Text(percent.map(Grading.caption) ?? "Take a test to see a grade here.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            ProgressView(value: Double(percent ?? 0) / 100)
                .tint(Theme.gold)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .card()
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
