import SwiftUI

/// A simple, ungated preview of this week's spelling words, reached from
/// Home so a child can study the list before taking the test -- just the
/// words themselves, no right/wrong info (that lives in the results screen
/// and Progress Report).
struct WordListView: View {
    @Environment(\.dismiss) private var dismiss
    let words: [SpellingWord]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("This week's words")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .font(Theme.body(16, weight: .medium))
                    .foregroundStyle(Theme.primary)
            }

            if words.isEmpty {
                Text("No words yet. Ask a grown-up to add this week's spelling list.")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                            HStack {
                                Text("\(index + 1)")
                                    .font(Theme.body(14))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 24, alignment: .leading)
                                // Exact stored case, not .capitalized --
                                // a child studying from this list needs to
                                // see any capitalization (e.g. a proper
                                // noun) that's actually part of the
                                // correct spelling.
                                Text(word.text)
                                    .font(Theme.display(20))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background.ignoresSafeArea())
    }
}
