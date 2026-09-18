import SwiftUI

/// Week-by-week breakdown of every spelling list the child has had, reached
/// from Settings' "View report" button. Counts every PracticeAttempt
/// (Practice and Test mode alike) since this is meant as an activity/
/// progress view, not a graded score -- the daily grade cards on Home are
/// the place for Test-only accuracy.
struct ProgressReportView: View {
    let child: Child

    private var rows: [WeeklyReportRow] {
        (child.weekLists ?? [])
            .sorted(by: { $0.weekOf > $1.weekOf })
            .map { list in
                let attempts = (list.words ?? []).flatMap { $0.attempts ?? [] }
                let correct = attempts.filter(\.isCorrect).count
                return WeeklyReportRow(weekOf: list.weekOf, correct: correct, total: attempts.count)
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
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Progress report")
                .font(Theme.display(30))
                .foregroundStyle(Theme.textPrimary)
            Text("\(child.name) · words correct, week by week")
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
                    weekRow(row)
                    Divider().overlay(Theme.hairline)
                }
            }
        }
    }

    private func weekRow(_ row: WeeklyReportRow) -> some View {
        HStack {
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
                        .tint(Theme.gold)
                        .frame(width: 100)
                }
            }
        }
        .padding(.vertical, 16)
    }
}

private struct WeeklyReportRow: Identifiable {
    let id = UUID()
    let weekOf: Date
    let correct: Int
    let total: Int

    var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total) * 100).rounded())
    }
}
