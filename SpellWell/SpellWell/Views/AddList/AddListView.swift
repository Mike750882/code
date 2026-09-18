import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let child: Child

    @State private var wordCount: Int = 12
    @State private var wordFields: [String] = Array(repeating: "", count: 12)

    @State private var showImportSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    private var currentWeekList: WeekList? {
        child.weekLists?.sorted(by: { $0.weekOf > $1.weekOf }).first
    }

    var body: some View {
        // One shared ScrollView for header, word grid, and footer --
        // previously only the grid scrolled while the header and footer
        // (Save/Import buttons) sat outside it in a fixed layout, so
        // nothing could scroll a field out from under the keyboard,
        // especially in landscape.
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                wordGrid
                footer
            }
            .padding(28)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onAppear { loadExistingWords() }
        .overlay {
            if isImporting {
                ProgressView("Reading photo…")
                    .padding(24)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
            }
        }
        .confirmationDialog("Import from a photo", isPresented: $showImportSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Take or choose a photo of a printed or handwritten word list.")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture(
                onCapture: { image in
                    showCamera = false
                    Task { await importWords(from: image) }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await importWords(from: image)
                } else {
                    importErrorMessage = "Couldn't open that photo. Try a different one."
                    showImportError = true
                }
                photoPickerItem = nil
            }
        }
        .alert("Couldn't read that photo", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
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
                    showImportSourceDialog = true
                }
                .font(Theme.body(15))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))

                Button("Save list") {
                    saveList()
                    dismiss()
                }
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

    private func importWords(from image: UIImage) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let words = try await TextRecognitionService.recognizeWords(in: image)
            applyImportedWords(words)
        } catch {
            importErrorMessage = "We couldn't find any words in that photo. Try a clearer, well-lit picture with one word per line."
            showImportError = true
        }
    }

    /// Replaces the current draft with the words read from a photo. Caps at
    /// 30 (the stepper's max) and raises the word count to fit them, same
    /// as typing a longer list in by hand would.
    private func applyImportedWords(_ words: [String]) {
        let trimmed = Array(words.prefix(30))
        guard !trimmed.isEmpty else { return }
        wordCount = min(max(trimmed.count, 5), 30)
        wordFields = Array(repeating: "", count: wordCount)
        for (index, word) in trimmed.enumerated() where index < wordFields.count {
            wordFields[index] = word
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

        // Save explicitly rather than relying on autosave timing. Besides
        // durability, this also matters for anything that captures this
        // list's identity right after saving (e.g. tapping Practice on
        // Home) -- a freshly inserted object only gets a permanent,
        // resolvable identifier once its context has actually been saved.
        try? modelContext.save()
    }
}
