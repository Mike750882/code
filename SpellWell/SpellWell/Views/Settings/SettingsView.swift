import SwiftUI
import AVFoundation

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
    @State private var selectedVoiceIdentifier: String = ""
    @State private var showChangePIN = false
    @State private var showTour = false

    var body: some View {
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
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            textScale = child.textScale
            appearance = child.appearance == "system" ? "light" : child.appearance
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Student profiles").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Switch between students, or add another.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

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
        .padding(.vertical, 20)
    }

    private var tourRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("App tour").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("See how spelling practice, tests, and rewards work.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Spacer()

            Button("Take a Tour") { showTour = true }
                .font(Theme.body(15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
        }
        .padding(.vertical, 20)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Text size").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("How big words look while spelling.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Slider(value: $textScale, in: 0.8...1.6)
                .tint(Theme.blue)
                .onChange(of: textScale) { _, newValue in child.textScale = newValue }

            Text("friend")
                .font(Theme.display(17 * textScale))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 160)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline, lineWidth: 1))
        }
        .padding(.vertical, 20)
    }

    private var voiceRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Which voice reads each spelling word.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

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
        .padding(.vertical, 20)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Appearance").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Dark mode is gentler at bedtime.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Picker("", selection: $appearance) {
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            .onChange(of: appearance) { _, newValue in child.appearance = newValue }

            Spacer()
        }
        .padding(.vertical, 20)
    }

    private var pinRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Parent PIN").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Unlocks the word list and rewards.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Text("••••").font(Theme.body(20)).foregroundStyle(Theme.textPrimary)

            Spacer()

            Button("Change PIN") { showChangePIN = true }
                .font(Theme.body(15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
        }
        .padding(.vertical, 20)
    }

    private var syncRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sync").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Keeps word lists, rewards, and progress the same on every family device.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Text(syncStatusText)
                .font(Theme.body(14))
                .foregroundStyle(syncStatusColor)

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
        .padding(.vertical, 20)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress report").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Words correct, week by week.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

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
        .padding(.vertical, 20)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sample data").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Adds 3 past weeks of fake results to preview the report. Debug builds only -- never ships.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Spacer()

            Button("Add sample weeks") { addSampleWeeks() }
                .font(Theme.body(15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
        }
        .padding(.vertical, 20)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tour banner").font(Theme.display(19)).foregroundStyle(Theme.textPrimary)
                Text("Resets the launch count so Home's \"Take a Tour\" banner shows again on the next launch. Debug builds only.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 220, alignment: .leading)

            Spacer()

            Button("Reset for next launch") { AppLaunchTracker.resetForTesting() }
                .font(Theme.body(15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
        }
        .padding(.vertical, 20)
    }
    #endif
}
