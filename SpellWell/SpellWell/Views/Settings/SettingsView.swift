import SwiftUI
import AVFoundation

/// One label+control row shared by every Settings section. Side-by-side
/// with a fixed-width label on a regular-width screen (iPad), or stacked
/// (label above control, using the row's full width) on a compact-width
/// one (iPhone portrait) -- there isn't room for both a 220pt label and a
/// control next to it on a phone-width screen.
private struct SettingsRow<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    label
                    content
                }
            } else {
                HStack {
                    label.frame(width: 220, alignment: .leading)
                    content
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
            Text(subtitle)
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncMonitor = CloudSyncMonitor()
    @StateObject private var previewSpeech = SpeechService()
    let child: Child
    /// Called after switching or removing the active profile in
    /// "Student profiles," so ContentView can pop back to Home and show
    /// whichever student is now active.
    var onProfileSwitched: () -> Void

    @State private var textScale: Double = 1.0
    @State private var appearance: String = "light"
    @State private var selectedColorProfile: String = "default"
    @State private var selectedVoiceIdentifier: String = ""
    @State private var showChangePIN = false
    @State private var showTour = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().overlay(Theme.hairline)
                profilesRow
                Divider().overlay(Theme.hairline)
                tourRow
                Divider().overlay(Theme.hairline)
                textSizeRow
                Divider().overlay(Theme.hairline)
                voiceRow
                Divider().overlay(Theme.hairline)
                appearanceRow
                Divider().overlay(Theme.hairline)
                colorProfileRow
                Divider().overlay(Theme.hairline)
                practiceScheduleRow
                Divider().overlay(Theme.hairline)
                pinRow
                Divider().overlay(Theme.hairline)
                syncRow
                Divider().overlay(Theme.hairline)
                progressRow
                #if DEBUG
                Divider().overlay(Theme.hairline)
                debugSampleDataRow
                Divider().overlay(Theme.hairline)
                debugResetTourRow
                #endif
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            textScale = child.textScale
            appearance = child.appearance == "system" ? "light" : child.appearance
            selectedColorProfile = child.colorProfile
            selectedVoiceIdentifier = child.voiceIdentifier
        }
        .sheet(isPresented: $showChangePIN) {
            SetPINView(
                title: "Change your PIN",
                subtitle: "Enter a new 4-digit PIN.",
                onSet: { pin in
                    KeychainService.savePIN(pin)
                    showChangePIN = false
                }
            )
        }
        .sheet(isPresented: $showTour) {
            TourView()
        }
    }

    private var profilesRow: some View {
        SettingsRow(title: "Student profiles", subtitle: "Switch between students, or add another.") {
            HStack {
                Spacer()
                NavigationLink {
                    ProfilesView(onSwitchedProfile: onProfileSwitched)
                } label: {
                    Text("Manage")
                }
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.blue)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
            }
        }
    }

    private var tourRow: some View {
        SettingsRow(title: "App tour", subtitle: "See how spelling practice, tests, and rewards work.") {
            HStack {
                Spacer()
                Button("Take a Tour") { showTour = true }
                    .font(Theme.body(15))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(Theme.display(30))
                .foregroundStyle(Theme.textPrimary)
            Text("\(child.name)'s iPad")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 16)
    }

    private var textSizeRow: some View {
        SettingsRow(title: "Text size", subtitle: "How big words look while spelling.") {
            HStack {
                Slider(value: $textScale, in: 0.8...1.6)
                    .tint(Theme.blue)
                    .onChange(of: textScale) { _, newValue in child.textScale = newValue }

                Text("friend")
                    .font(Theme.display(17 * textScale))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private var voiceRow: some View {
        SettingsRow(title: "Voice", subtitle: "Which voice reads each spelling word.") {
            HStack {
                Picker("", selection: $selectedVoiceIdentifier) {
                    Text("Default").tag("")
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text(voiceLabel(voice)).tag(voice.identifier)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedVoiceIdentifier) { _, newValue in child.voiceIdentifier = newValue }

                Spacer()

                Button {
                    previewSpeech.speak("Spell Well", voiceIdentifier: selectedVoiceIdentifier)
                } label: {
                    Label("Preview", systemImage: "play.circle")
                }
                .font(Theme.body(15))
                .foregroundStyle(Theme.blue)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
            }
        }
    }

    /// The only voices offered in the picker, in this specific order.
    /// Apple ships hundreds of voices across every language/locale, so this
    /// is a deliberately curated shortlist rather than "every installed
    /// voice."
    private static let allowedVoiceNames: [String] = [
        "Tessa", "Superstar", "Samantha", "Rishi", "Moira",
        "Kathy", "Karen", "Junior", "Fred", "Daniel"
    ]

    /// Whichever of `allowedVoiceNames` are actually installed on this
    /// device, in that same order -- a name missing from the device (the
    /// Simulator ships far fewer voices than a real device) is simply
    /// skipped rather than shown as broken.
    private var availableVoices: [AVSpeechSynthesisVoice] {
        let installed = AVSpeechSynthesisVoice.speechVoices()
        return Self.allowedVoiceNames.compactMap { name in
            installed.first(where: { $0.name == name })
        }
    }

    private func voiceLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .enhanced: return "\(voice.name) (Enhanced)"
        case .premium: return "\(voice.name) (Premium)"
        default: return voice.name
        }
    }

    private var appearanceRow: some View {
        SettingsRow(title: "Appearance", subtitle: "Dark mode is gentler at bedtime.") {
            HStack {
                Picker("", selection: $appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)
                .onChange(of: appearance) { _, newValue in child.appearance = newValue }

                Spacer()
            }
        }
    }

    private var colorProfileRow: some View {
        SettingsRow(title: "Color theme", subtitle: "Changes the colors used throughout the whole app.") {
            // Horizontally scrollable rather than assuming every swatch
            // fits in one row -- keeps this from overflowing on a narrow
            // screen as more color themes get added.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ColorProfile.all) { profile in
                        colorProfileSwatch(profile)
                    }
                }
            }
        }
    }

    private func colorProfileSwatch(_ profile: ColorProfile) -> some View {
        let isSelected = selectedColorProfile == profile.id
        return VStack(spacing: 6) {
            ZStack {
                if isSelected {
                    Circle()
                        .strokeBorder(Theme.textPrimary, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
                Circle()
                    .fill(Color(hex: profile.coral))
                    .frame(width: 36, height: 36)
            }
            Text(profile.name)
                .font(Theme.body(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedColorProfile = profile.id
            child.colorProfile = profile.id
        }
    }

    private static let scheduleWeekdays: [(weekday: Int, label: String)] = [
        (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"), (5, "Thursday")
    ]

    /// Reads/writes straight through to the model with a computed Binding
    /// rather than a local @State mirror (unlike appearance/voice above) --
    /// there's no shared "the schedule" value to keep in sync with an
    /// onAppear, just four independent per-day pickers, so a direct
    /// Binding per day is simpler and can't drift out of sync.
    private func inputModeBinding(forWeekday weekday: Int) -> Binding<WordInputMode> {
        Binding(
            get: { child.inputMode(forWeekday: weekday) },
            set: { child.setInputMode($0, forWeekday: weekday) }
        )
    }

    private var practiceScheduleRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Practice schedule").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Choose how spelling words are practiced each day.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(Self.scheduleWeekdays, id: \.weekday) { entry in
                HStack {
                    Text(entry.label)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 100, alignment: .leading)

                    Picker("", selection: inputModeBinding(forWeekday: entry.weekday)) {
                        ForEach(WordInputMode.allCases) { inputMode in
                            Text(inputMode.label).tag(inputMode)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var pinRow: some View {
        SettingsRow(title: "Parent PIN", subtitle: "Unlocks the word list and rewards.") {
            HStack {
                Text("••••").font(Theme.body(20)).foregroundStyle(Theme.textPrimary)

                Spacer()

                Button("Change PIN") { showChangePIN = true }
                    .font(Theme.body(15))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private var syncRow: some View {
        SettingsRow(title: "Sync", subtitle: "Keeps word lists, rewards, and progress the same on every family device.") {
            HStack {
                Text(syncStatusText)
                    .font(Theme.body(14))
                    .foregroundStyle(syncStatusColor)
                    .lineLimit(2)

                Spacer()

                Button {
                    syncMonitor.requestSync(modelContext: modelContext)
                } label: {
                    if syncMonitor.status == .syncing {
                        ProgressView()
                            .frame(width: 44)
                    } else {
                        Text("Sync now")
                    }
                }
                .disabled(syncMonitor.status == .syncing)
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.blue)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
            }
        }
    }

    private var syncStatusText: String {
        switch syncMonitor.status {
        case .idle: return "Not synced yet"
        case .syncing: return "Syncing…"
        case .upToDate(let date): return "Up to date · \(date.formatted(.relative(presentation: .named)))"
        case .failed(let message): return "Couldn't sync: \(message)"
        }
    }

    private var syncStatusColor: Color {
        if case .failed = syncMonitor.status { return Theme.coral }
        return Theme.textSecondary
    }

    private var progressRow: some View {
        SettingsRow(title: "Progress report", subtitle: "Words correct, week by week.") {
            HStack {
                Text(progressSummary)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                NavigationLink {
                    ProgressReportView(child: child)
                } label: {
                    Text("View report")
                }
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.blue)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
            }
        }
    }

    private var progressSummary: String {
        let attempts = (child.weekLists ?? [])
            .flatMap { $0.words ?? [] }
            .flatMap { $0.attempts ?? [] }
        let thisWeek = attempts.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
        let correct = thisWeek.filter(\.isCorrect).count
        return "This week · \(correct) of \(thisWeek.count) correct"
    }

    #if DEBUG
    private var debugSampleDataRow: some View {
        SettingsRow(title: "Sample data", subtitle: "Adds 3 past weeks of fake results to preview the report. Debug builds only -- never ships.") {
            HStack {
                Spacer()
                Button("Add sample weeks") { addSampleWeeks() }
                    .font(Theme.body(15))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    /// Debug-only helper to preview the progress report with real-looking
    /// data. Seeds 3 *past* weeks (1, 2, 3 weeks ago) with their own words
    /// and attempts -- it never touches the current week, so it won't
    /// disturb whatever real list/results are already set up. Tapping it
    /// more than once adds another batch rather than replacing the last.
    private func addSampleWeeks() {
        let calendar = Calendar.current
        let sampleWords = [
            "friend", "because", "thought", "beautiful", "whisper",
            "garden", "shoulder", "quietly", "mountain", "journey"
        ]
        // (weeks ago, how many of the 10 sample words were correct) --
        // oldest first, with accuracy improving over time for a nice demo.
        let weekResults: [(weeksAgo: Int, correctCount: Int)] = [(3, 6), (2, 8), (1, 9)]

        for (weeksAgo, correctCount) in weekResults {
            guard let weekOf = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: Date()) else { continue }

            let list = WeekList(weekOf: weekOf, targetWordCount: sampleWords.count)
            list.child = child
            modelContext.insert(list)

            for (index, text) in sampleWords.enumerated() {
                let word = SpellingWord(text: text, orderIndex: index)
                modelContext.insert(word)
                word.weekList = list

                let attempt = PracticeAttempt(isCorrect: index < correctCount, mode: "test")
                attempt.date = weekOf
                modelContext.insert(attempt)
                attempt.word = word
            }
        }

        try? modelContext.save()
    }

    private var debugResetTourRow: some View {
        SettingsRow(title: "Tour banner", subtitle: "Resets the launch count so Home's \"Take a Tour\" banner shows again on the next launch. Debug builds only.") {
            HStack {
                Spacer()
                Button("Reset for next launch") { AppLaunchTracker.resetForTesting() }
                    .font(Theme.body(15))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }
    #endif
}
