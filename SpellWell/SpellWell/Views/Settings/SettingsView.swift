import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var syncMonitor = CloudSyncMonitor()
    let child: Child

    @State private var textScale: Double = 1.0
    @State private var appearance: String = "light"
    @State private var showChangePIN = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.hairline)
            textSizeRow
            Divider().overlay(Theme.hairline)
            appearanceRow
            Divider().overlay(Theme.hairline)
            pinRow
            Divider().overlay(Theme.hairline)
            syncRow
            Divider().overlay(Theme.hairline)
            progressRow
            Spacer()
        }
        .padding(28)
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            textScale = child.textScale
            appearance = child.appearance == "system" ? "light" : child.appearance
        }
        .sheet(isPresented: $showChangePIN) {
            ChangePINView()
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

            Button("View report") {
                // TODO: build a dedicated week-by-week report screen/chart.
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
}

private struct ChangePINView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Set a new PIN")
                .font(Theme.display(24))
                .foregroundStyle(Theme.textPrimary)
            SecureField("New 4-digit PIN", text: $newPIN)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            SecureField("Confirm PIN", text: $confirmPIN)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                guard newPIN.count == 4, newPIN == confirmPIN else { return }
                KeychainService.savePIN(newPIN)
                dismiss()
            }
            .disabled(newPIN.count != 4 || newPIN != confirmPIN)
            .font(Theme.body(16, weight: .medium))
            .foregroundStyle(Theme.blue)
        }
        .padding(32)
        .frame(maxWidth: 360)
    }
}
