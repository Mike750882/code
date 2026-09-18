import SwiftUI
import SwiftData

struct RewardsView: View {
    @Environment(\.modelContext) private var modelContext
    let child: Child

    private let weekdayLabels: [(weekday: Int, label: String)] = [
        (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"), (5, "Thursday")
    ]

    @State private var rewardTexts: [Int: String] = [:]
    @State private var thresholds: [Int: Double] = [:]
    @State private var weeklyPrizeTitle: String = ""
    @State private var weeklyPrizeThreshold: Double = 80

    private enum Field: Hashable {
        case reward(Int)
        case weeklyPrize
    }
    @FocusState private var focusedField: Field?

    var body: some View {
        // Everything shares one ScrollView -- previously only the daily
        // rows scrolled while the header, weekly prize card, and Save
        // button sat in a fixed layout outside it, so nothing could scroll
        // a field out from under the keyboard, especially in landscape
        // where there's much less vertical space to begin with.
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                VStack(spacing: 0) {
                    ForEach(weekdayLabels, id: \.weekday) { entry in
                        dailyRow(weekday: entry.weekday, label: entry.label)
                        Divider().overlay(Theme.hairline)
                    }
                }
                weeklyPrizeCard
                footer
            }
            .padding(28)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear { loadExisting() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rewards")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.textPrimary)
                Text("Set what \(child.name) earns each day, and one prize for the week.")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text("PIN required to edit")
            }
            .font(Theme.body(12))
            .foregroundStyle(Theme.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Theme.blue, lineWidth: 1))
        }
    }

    private func dailyRow(weekday: Int, label: String) -> some View {
        HStack(spacing: 20) {
            Text("\(label)'s reward")
                .font(Theme.body(17))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 160, alignment: .leading)

            TextField("Enter reward", text: bindingForText(weekday))
                .font(Theme.body(16))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline, lineWidth: 1))
                .focused($focusedField, equals: .reward(weekday))

            Slider(value: bindingForThreshold(weekday), in: 0...100, step: 5)
                .tint(Theme.purple)
                .frame(width: 180)

            Text("\(Int(thresholds[weekday] ?? 70))% right")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 70, alignment: .leading)
        }
        .padding(.vertical, 16)
    }

    private var weeklyPrizeCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "star").foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEKLY PRIZE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.gold)
                TextField("Weekly prize", text: $weeklyPrizeTitle)
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($focusedField, equals: .weeklyPrize)
            }
            Spacer()
            Slider(value: $weeklyPrizeThreshold, in: 0...100, step: 5)
                .tint(Theme.purple)
                .frame(width: 220)
            VStack(alignment: .trailing) {
                Text("Earned").font(Theme.body(12)).foregroundStyle(Theme.textSecondary)
                Text("\(Int(weeklyPrizeThreshold))%").font(Theme.display(22)).foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(20)
        .background(Theme.goldFill)
        .overlay(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).stroke(Theme.gold, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }

    private var footer: some View {
        HStack {
            Text("\(child.name) sees that day's reward on the home screen once they reach the goal.")
                .font(Theme.body(13))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Button("Save rewards") { save() }
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.blue)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
        }
    }

    private func bindingForText(_ weekday: Int) -> Binding<String> {
        Binding(get: { rewardTexts[weekday] ?? "" }, set: { rewardTexts[weekday] = $0 })
    }

    private func bindingForThreshold(_ weekday: Int) -> Binding<Double> {
        Binding(get: { thresholds[weekday] ?? 70 }, set: { thresholds[weekday] = $0 })
    }

    private func loadExisting() {
        for reward in child.dailyRewards ?? [] {
            rewardTexts[reward.weekday] = reward.rewardText
            thresholds[reward.weekday] = Double(reward.thresholdPercent)
        }
        if let prize = child.weeklyPrizes?.sorted(by: { $0.weekOf > $1.weekOf }).first {
            weeklyPrizeTitle = prize.title
            weeklyPrizeThreshold = Double(prize.thresholdPercent)
        }
    }

    private func save() {
        let weekOf = Date()
        for (weekday, _) in weekdayLabels {
            let text = (rewardTexts[weekday] ?? "").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let reward = child.dailyRewards?.first(where: { $0.weekday == weekday }) ?? {
                let new = DailyReward(weekOf: weekOf, weekday: weekday, rewardText: text, thresholdPercent: 70)
                new.child = child
                modelContext.insert(new)
                return new
            }()
            reward.rewardText = text
            reward.thresholdPercent = Int(thresholds[weekday] ?? 70)
        }

        let title = weeklyPrizeTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let prize = child.weeklyPrizes?.first ?? {
            let new = WeeklyPrize(weekOf: weekOf, title: title, thresholdPercent: Int(weeklyPrizeThreshold))
            new.child = child
            modelContext.insert(new)
            return new
        }()
        prize.title = title
        prize.thresholdPercent = Int(weeklyPrizeThreshold)
    }
}
