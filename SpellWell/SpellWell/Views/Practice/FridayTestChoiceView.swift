import SwiftUI

/// Landing screen for Friday's test -- reached either by tapping the
/// "Practice For Today's Test" notification or by starting a test
/// normally from Home on a Friday (see `HomeView.onStartFridayTest`).
/// Lets the student review this week's words first, or jump straight into
/// the test, which is always typed from memory on Friday (see
/// `Child.inputMode(forWeekday:)`) rather than whatever the day's normal
/// tile/typed schedule would otherwise say.
struct FridayTestChoiceView: View {
    let weekList: WeekList
    var onStartTest: () -> Void

    @State private var showWordList = false

    private var words: [SpellingWord] {
        (weekList.words ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)
            Text("Today's Spelling Test")
                .font(Theme.display(32))
                .foregroundStyle(Theme.textPrimary)
            Text("Today's test is typed from memory, no letter tiles. Review this week's words first, or jump right in.")
                .font(Theme.body(16))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button("Review the words first") { showWordList = true }
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: 320)
                    .padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.primary, lineWidth: 1.5))

                Button("Start the test", action: onStartTest)
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.action)
                    .frame(maxWidth: 320)
                    .padding(.vertical, 14)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.action, lineWidth: 1.5))
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWordList) {
            WordListView(words: words)
        }
    }
}
