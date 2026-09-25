import SwiftUI

/// Week-by-week breakdown of every spelling list the child has had, reached
/// from Settings' "View report" button. Counts every PracticeAttempt, which
/// in practice (no pun intended) means Test-mode attempts only -- Practice
/// mode shows its own results right at the end of the session
/// (PracticeResultsView) but never persists a PracticeAttempt, since it's
/// just for rehearsing and shouldn't follow the child into their permanent
/// progress history. Tapping a week expands it to show every word from
/// that list with its most recent attempt's result.
struct ProgressReportView: View {
    @Environment(\.modelContext) private var modelContext
    let child: Child

    @State private var expandedWeekIDs: Set<UUID> = []
    @State private var weekPendingDeletion: WeeklyReportRow?

    private var rows: [WeeklyReportRow] {
        (child.weekLists ?? [])
            .sorted(by: { $0.weekOf > $1.weekOf })
            .map { list in
                let words = (list.words ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
                // Collapsed to each day's most recent Test session before
                // counting -- otherwise a retaken day's earlier, wrong
                // attempts stayed mixed in with the correct retake that
                // replaced them, dragging this week's percent down even
                // when every one of that week's daily grades was good.
                let attempts = words.flatMap { $0.attempts ?? [] }.latestSessionPerWeekday
                let correct = attempts.filter(\.isCorrect).count
                return WeeklyReportRow(
                    id: list.id,
                    weekList: list,
                    weekOf: list.weekOf,
                    words: words,
                    correct: correct,
                    total: attempts.count
                )
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            if rows.isEmpty {
                emptyState
            } else {
                list
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Remove week of \((weekPendingDeletion?.weekOf ?? Date()).formatted(.dateTime.month(.wide).day()))?",
            isPresented: Binding(
                get: { weekPendingDeletion != nil },
                set: { if !$0 { weekPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { weekPendingDeletion = nil }
            Button("Remove", role: .destructive) { deletePending() }
        } message: {
            Text("This permanently deletes this week's spelling list and progress. This can't be undone.")
        }
    }

    private func deletePending() {
        guard let row = weekPendingDeletion else { return }
        expandedWeekIDs.remove(row.id)
        modelContext.delete(row.weekList)
        weekPendingDeletion = nil
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress report")
                .font(Theme.display(30))
                .foregroundStyle(Theme.textPrimary)
            Text("\(child.name) · tap a week to see each word")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No practice yet")
                .font(Theme.display(20))
                .foregroundStyle(Theme.textPrimary)
            Text("Once \(child.name) starts practicing, weekly results will show up here.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    weekSection(row)
                    Divider().overlay(Theme.hairline)
                }
            }
        }
    }

    private func weekSection(_ row: WeeklyReportRow) -> some View {
        let isExpanded = expandedWeekIDs.contains(row.id)
        return VStack(alignment: .leading, spacing: 0) {
            // A tap gesture on the row (not a Button wrapping it) so the
            // trash button can be a sibling inside it rather than a Button
            // nested inside a Button, which SwiftUI doesn't handle well.
            weekRow(row, isExpanded: isExpanded)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedWeekIDs.remove(row.id)
                        } else {
                            expandedWeekIDs.insert(row.id)
                        }
                    }
                }

            if isExpanded {
                wordBreakdown(row.words)
            }
        }
    }

    private func weekRow(_ row: WeeklyReportRow, isExpanded: Bool) -> some View {
        HStack {
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Week of \(row.weekOf.formatted(.dateTime.month(.wide).day()))")
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.textPrimary)
                Text(row.total > 0 ? "\(row.correct) of \(row.total) correct" : "No words practiced")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if row.total > 0 {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(row.percent)%")
                        .font(Theme.display(20))
                        .foregroundStyle(Grading.color(forPercent: row.percent))
                    ProgressView(value: Double(row.percent) / 100)
                        .tint(Theme.primary)
                        .frame(width: 100)
                }
            }

            Button {
                weekPendingDeletion = row
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.error)
            }
            .padding(.leading, 16)
        }
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func wordBreakdown(_ words: [SpellingWord]) -> some View {
        VStack(spacing: 0) {
            if words.isEmpty {
                Text("No words in this list.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 28)
                    .padding(.bottom, 12)
            } else {
                ForEach(words, id: \.id) { word in
                    wordRow(word)
                }
            }
        }
        .padding(.bottom, 12)
    }

    private func wordRow(_ word: SpellingWord) -> some View {
        let result = mostRecentResult(for: word)
        return HStack {
            Image(systemName: iconName(for: result))
                .foregroundStyle(iconColor(for: result))
            // Exact stored case, not .capitalized -- see the note on
            // PracticeResultsView.wordRow for why.
            Text(word.text)
                .font(Theme.body(15))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(statusLabel(for: result))
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.leading, 28)
        .padding(.vertical, 6)
    }

    /// Most recent attempt's result for this word, in case it was tried
    /// more than once that week -- retries in Practice mode, or retaking a
    /// Test. nil means the word was in the list but never attempted.
    private func mostRecentResult(for word: SpellingWord) -> Bool? {
        (word.attempts ?? []).sorted(by: { $0.date < $1.date }).last?.isCorrect
    }

    private func iconName(for result: Bool?) -> String {
        switch result {
        case true: return "checkmark.circle.fill"
        case false: return "xmark.circle.fill"
        case nil: return "minus.circle"
        }
    }

    private func iconColor(for result: Bool?) -> Color {
        switch result {
        case true: return Theme.success
        case false: return Theme.error
        case nil: return Theme.textSecondary
        }
    }

    private func statusLabel(for result: Bool?) -> String {
        switch result {
        case true: return "Correct"
        case false: return "Incorrect"
        case nil: return "Not practiced"
        }
    }
}

private struct WeeklyReportRow: Identifiable {
    let id: UUID
    let weekList: WeekList
    let weekOf: Date
    let words: [SpellingWord]
    let correct: Int
    let total: Int

    var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total) * 100).rounded())
    }
}
