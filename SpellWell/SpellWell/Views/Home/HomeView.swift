import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let child: Child
    var onOpenGated: (ContentView.GatedDestination) -> Void
    var onStartPractice: (WeekList, PracticeMode) -> Void
    /// Tapping a daily grade card with missed words starts a focused
    /// Practice session on just those words -- doesn't touch the day's
    /// already-recorded Test grade, same as any other Practice session.
    var onReviewMissedWords: (WeekList, [SpellingWord]) -> Void

    /// iPhone portrait (and most iPhone landscape) is "compact"; iPad is
    /// "regular" in both orientations. Several layouts below were built
    /// for the iPad mockups' width and need to reflow -- stacking instead
    /// of sitting side by side, smaller text, cards that wrap to fewer
    /// columns -- to still look right on a much narrower phone screen.
    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var showNoWordsAlert = false
    @State private var mode: PracticeMode = .practice
    @State private var showTourBanner = AppLaunchTracker.shouldShowTourBanner
    @State private var showTour = false
    @State private var isTourBannerPulsing = false
    @State private var showWordList = false

    private var thisWeekList: WeekList? {
        child.weekLists?.sorted(by: { $0.weekOf > $1.weekOf }).first
    }

    private var thisWeekWords: [SpellingWord] {
        (thisWeekList?.words ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var todaysWordInputMode: WordInputMode {
        child.inputMode(forWeekday: Calendar.current.component(.weekday, from: Date()))
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
        .sheet(isPresented: $showWordList) {
            WordListView(words: thisWeekWords)
        }
    }

    /// Streak/word-list pills sit on the right on every device, not just
    /// a wide (`.regular`) one -- `horizontalSizeClass` isn't a reliable
    /// "is this an iPad" check (a large iPhone in landscape also reports
    /// `.regular`), so branching on it here would leave some iPhones with
    /// the old left-aligned layout instead. One consistent right-aligned
    /// layout avoids depending on that distinction at all.
    ///
    /// The tour banner sits under the greeting/pills row, as its own
    /// sibling, rather than nested in a VStack alongside the greeting --
    /// nested that way, it was still proposed only the same narrow width
    /// as that VStack got from sharing its HStack row with the pills (the
    /// pills claim their own space on the right regardless of which row
    /// visually contains them), so its content (an icon, "Take a Tour,"
    /// an X) didn't have room to lay out normally and truncated. As a
    /// direct sibling, it's proposed the full row's width to size itself
    /// in normally.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                greeting
                Spacer()
                streakAndWordListPills
            }
            if showTourBanner { tourBanner }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text("Hello, \(child.name)")
                    .font(Theme.display(isCompact ? 26 : 32))
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
    }

    /// Always stacked vertically, even in compact mode -- two pills side
    /// by side would be tight on the narrowest iPhone widths, and there's
    /// no shortage of vertical room to stack them in instead.
    private var streakAndWordListPills: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "star").foregroundStyle(Theme.primary)
                Text("\(child.currentStreak())-day streak")
                    .font(Theme.body(15, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(Capsule().stroke(Theme.primary, lineWidth: 1))

            Button {
                showWordList = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet").foregroundStyle(Theme.tile)
                    Text("This week's words")
                        .font(Theme.body(15, weight: .medium))
                        .foregroundStyle(Theme.tile)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(Capsule().stroke(Theme.tile, lineWidth: 1))
            }
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
                        .foregroundStyle(Theme.tile)
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
        .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.tile, lineWidth: 1.5))
        .shadow(color: Theme.tile.opacity(isTourBannerPulsing ? 0.55 : 0.15), radius: isTourBannerPulsing ? 12 : 4)
        .scaleEffect(isTourBannerPulsing ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isTourBannerPulsing = true
            }
        }
    }

    private var modeToggle: some View {
        let picker = Picker("Mode", selection: $mode) {
            ForEach(PracticeMode.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 240)

        let description = Text(mode.description)
            .font(Theme.body(14))
            .foregroundStyle(Theme.textSecondary)

        return Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 8) {
                    picker
                    description
                }
            } else {
                HStack(spacing: 14) {
                    picker
                    description
                    Spacer()
                }
            }
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
            VStack(alignment: .leading, spacing: isCompact ? 16 : 24) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: isCompact ? 24 : 33))
                        .foregroundStyle(Theme.action)
                    Spacer()
                    Text("\(todayCompletedCount) of \(thisWeekWords.count) today")
                        .font(Theme.body(isCompact ? 15 : 22))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(mode == .test ? "Take spelling test" : "Practice spelling list")
                    .font(Theme.display(isCompact ? 32 : 60))
                    .foregroundStyle(Theme.textPrimary)
                Text(todaysWordInputMode.homeCardSubtitle)
                    .font(Theme.body(isCompact ? 15 : 26))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(isCompact ? 24 : 42)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(background: Theme.surfaceRaised, borderColor: Theme.action, lineWidth: 1.5)
        }
        .buttonStyle(.plain)
        .alert("No words yet", isPresented: $showNoWordsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ask a grown-up to add this week's spelling words first.")
        }
    }

    /// On a regular-width screen (iPad, any orientation), exactly 3 equal
    /// flexible columns -- same as the original fixed 3-wide HStack, so
    /// the cards spread across the full row instead of `.adaptive`
    /// computing room for more columns than there are cards and leaving
    /// them bunched on the left with empty space on the right. On a
    /// compact screen (iPhone), still adaptive so it wraps down to fewer
    /// columns instead of squeezing all three into a width they don't
    /// fit in.
    private var secondaryCards: some View {
        let columns = isCompact
            ? [GridItem(.adaptive(minimum: 220), spacing: 16)]
            : Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)
        return LazyVGrid(columns: columns, spacing: 16) {
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

    /// Same reasoning as `secondaryCards` -- exactly 4 equal columns on
    /// regular width so the cards spread across the full row like the
    /// original fixed 4-wide HStack, adaptive (wrapping down to two, or
    /// one, per row) on compact.
    private var dailyGradeCards: some View {
        let columns = isCompact
            ? [GridItem(.adaptive(minimum: 150), spacing: 16)]
            : Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Self.weekdayLabels, id: \.weekday) { entry in
                let missed = missedWords(onWeekday: entry.weekday)
                DayGradeCard(label: entry.label, percent: testPercent(onWeekday: entry.weekday), missedCount: missed.count) {
                    guard let list = thisWeekList, !missed.isEmpty else { return }
                    onReviewMissedWords(list, missed)
                }
            }
        }
    }

    /// That weekday's most recent Test-mode session this week, or nil if
    /// the child hasn't taken a test that day yet -- shared by
    /// `testPercent` and `missedWords` so both agree on which session
    /// counts. If the test was taken more than once that day, only the
    /// most recent session (PracticeAttempt.sessionID) counts, not a blend
    /// of every attempt -- retaking a test replaces that day's grade
    /// rather than averaging into it.
    private func latestTestSession(onWeekday weekday: Int) -> [PracticeAttempt]? {
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
        return latestSession.isEmpty ? nil : latestSession
    }

    private func testPercent(onWeekday weekday: Int) -> Int? {
        guard let session = latestTestSession(onWeekday: weekday) else { return nil }
        let correct = session.filter(\.isCorrect).count
        return Int((Double(correct) / Double(session.count) * 100).rounded())
    }

    /// The specific words gotten wrong in that weekday's most recent Test
    /// session -- lets a low grade turn directly into a focused practice
    /// session on exactly what to fix, via `onReviewMissedWords`.
    private func missedWords(onWeekday weekday: Int) -> [SpellingWord] {
        (latestTestSession(onWeekday: weekday) ?? []).filter { !$0.isCorrect }.compactMap(\.word)
    }
}

private struct DayGradeCard: View {
    let label: String
    let percent: Int?
    let missedCount: Int
    var onRetakeMissed: () -> Void

    private var isTappable: Bool { missedCount > 0 }

    var body: some View {
        let card = VStack(spacing: 10) {
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
                .tint(Theme.primary)
            if isTappable {
                Text("Retake \(missedCount) missed word\(missedCount == 1 ? "" : "s")")
                    .font(Theme.body(12, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .card(borderColor: isTappable ? Theme.primary.opacity(0.4) : Theme.hairline)

        return Group {
            if isTappable {
                Button(action: onRetakeMissed) { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
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
                    Image(systemName: icon).foregroundStyle(Theme.tile)
                    Spacer()
                    if let badge {
                        Text(badge.uppercased())
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(Capsule().stroke(Theme.primary.opacity(0.5), lineWidth: 1))
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
                    ProgressView(value: progress).tint(Theme.reward)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}
