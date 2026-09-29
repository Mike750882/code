import SwiftUI

/// Shown when a parent taps the "Reward Earned!" badge on today's
/// day-grade card -- the same header/background/Speagle-corner treatment
/// as `WordListView`, rather than a plain system alert, so it feels like
/// part of the app instead of a generic iOS dialog box.
struct RewardEarnedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let rewardText: String

    private var isCompact: Bool { horizontalSizeClass == .compact }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Today's Reward")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }

            // Same rewardFill/reward-bordered card treatment
            // RewardsView's own weekly-prize card uses, so this reads as
            // the same kind of "reward" content, not a different style.
            VStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.rewardIcon)
                Text(rewardText)
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(Theme.rewardFill)
            .overlay(RoundedRectangle(cornerRadius: Theme.cardCornerRadius).stroke(Theme.reward, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            .padding(.top, 24)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .speagleBackground()
        .overlay(alignment: .bottomTrailing) {
            Speagle(pose: .cheer, size: isCompact ? 120 : 200)
                .allowsHitTesting(false)
                .padding(20)
        }
    }
}
