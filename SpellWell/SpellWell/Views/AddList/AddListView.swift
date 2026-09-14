import SwiftUI
import SwiftData

struct AddListView: View {
    @Environment(\.modelContext) private var modelContext
    let child: Child

    @State private var wordCount: Int = 12
    @State private var wordFields: [String] = Array(repeating: "", count: 12)

    private var currentWeekList: WeekList? {
        child.weekLists?.sorted(by: { $0.weekOf > $1.weekOf }).first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            ScrollView {
                wordGrid
            }
            footer
        }
        .padding(28)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { loadExistingWords() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("This week's spelling list")
                    .font(Theme.display(30))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(child.name) · week of \(Date().formatted(.dateTime.month(.wide).day()))")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            HStack(spacing: 12) {
                Text("How many words?")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
                Stepper(value: $wordCount, in: 5...30) {
                    Text("\(wordCount)").font(Theme.display(18)).frame(minWidth: 32)
                }
                .fixedSize()
                .onChange(of: wordCount) { _, newValue in resizeFields(to: newValue) }
            }
        }
    }

    private var wordGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(0..<wordFields.count, id: \.self) { index in
                HStack {
                    Text("\(index + 1)")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, alignment: .trailing)
                    TextField("", text: binding(for: index))
                        .font(Theme.body(18))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline, lineWidth: 1))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider().overlay(Theme.hairline)
            HStack {
                Text("Words are read aloud with the iPad voice. Tap a word to record your own voice.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Import a list") {
                    // TODO: hook up a document/CSV importer.
                }
                .font(Theme.body(15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))

                Button("Save list") { saveList() }
                    .font(Theme.body(15, weight: .medium))
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < wordFields.count ? wordFields[index] : "" },
            set: { if index < wordFields.count { wordFields[index] = $0 } }
        )
    }

    private func resizeFields(to count: Int) {
        if count > wordFields.count {
            wordFields.append(contentsOf: Array(repeating: "", count: count - wordFields.count))
        } else {
            wordFields = Array(wordFields.prefix(count))
        }
    }

    private func loadExistingWords() {
        guard let list = currentWeekList, let words = list.words, !words.isEmpty else { return }
        wordCount = list.targetWordCount
        var fields = Array(repeating: "", count: max(wordCount, words.count))
        for word in words.sorted(by: { $0.orderIndex < $1.orderIndex }) where word.orderIndex < fields.count {
            fields[word.orderIndex] = word.text
        }
        wordFields = fields
    }

    private func saveList() {
        let list = currentWeekList ?? {
            let newList = WeekList(weekOf: Date(), targetWordCount: wordCount)
            newList.child = child
            modelContext.insert(newList)
            return newList
        }()
        list.targetWordCount = wordCount

        // Capture the old words before touching anything, link the new
        // ones in (which appends them into list.words via the inverse
        // relationship -- no need to reassign the array), and only then
        // delete the old ones. Deleting first and reassigning list.words
        // in the same pass makes SwiftData diff the collection against
        // objects it just deleted, which crashes with "this model instance
        // was invalidated because its backing data could no longer be
        // found."
        let oldWords = list.words ?? []

        for (index, text) in wordFields.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let word = SpellingWord(text: trimmed, orderIndex: index)
            modelContext.insert(word)
            word.weekList = list
        }

        for word in oldWords {
            modelContext.delete(word)
        }
    }
}
