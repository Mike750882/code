import SwiftUI

private struct TourPage {
    let icon: String
    let color: Color
    let title: String
    let body: String
}

/// A swipeable walkthrough of the app. Pages are icon-based illustrations
/// rather than real screenshots -- this project has no way to capture
/// actual running-app screenshots to ship as static images, so each page
/// pairs a large SF Symbol with a short explanation instead.
///
/// Opened from Home's dismissible first-two-launches banner
/// (AppLaunchTracker) and from Settings' "Take a Tour" row, any time.
struct TourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pageIndex = 0

    private let pages: [TourPage] = [
        TourPage(
            icon: "hand.wave.fill",
            color: Theme.coral,
            title: "Welcome to SpellWell",
            body: "A quick look at how spelling practice, tests, and rewards work."
        ),
        TourPage(
            icon: "speaker.wave.2.fill",
            color: Theme.blue,
            title: "Hear it, then spell it",
            body: "Tap the speaker to hear a word, then tap scrambled letters to build it. \"Take one back\" undoes your last letter."
        ),
        TourPage(
            icon: "checkmark.seal.fill",
            color: Theme.purple,
            title: "Practice or Test",
            body: "Practice mode lets you try a word again and again until you get it. Test mode is one try per word -- then you get a real grade at the end."
        ),
        TourPage(
            icon: "chart.bar.fill",
            color: Theme.gold,
            title: "Grades and progress",
            body: "After a test, see which words you got right and wrong. Daily grade cards on Home, and a full weekly report, track how you're doing over time."
        ),
        TourPage(
            icon: "lock.fill",
            color: Theme.blue,
            title: "Grown-ups only",
            body: "A parent PIN protects the spelling list, rewards, and settings, so only a grown-up can change them."
        ),
        TourPage(
            icon: "star.fill",
            color: Theme.gold,
            title: "Earn rewards",
            body: "Grown-ups can set a reward for each day and a bigger prize for the week, based on how well you do."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: { dismiss() })
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.textSecondary)
                    .padding()
            }

            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    tourPageView(page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if pageIndex == pages.count - 1 {
                    dismiss()
                } else {
                    withAnimation { pageIndex += 1 }
                }
            } label: {
                Text(pageIndex == pages.count - 1 ? "Done" : "Next")
                    .frame(minWidth: 100)
            }
            .font(Theme.body(16, weight: .medium))
            .foregroundStyle(Theme.blue)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func tourPageView(_ page: TourPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(page.color)
            }
            Text(page.title)
                .font(Theme.display(28))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(Theme.body(16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
            Spacer()
            Spacer()
        }
    }
}
