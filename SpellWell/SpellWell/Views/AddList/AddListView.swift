import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct AddListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let child: Child

    private var isCompact: Bool { horizontalSizeClass == .compact }

    @State private var wordCount: Int = 12
    @State private var wordFields: [String] = Array(repeating: "", count: 12)
    /// An optional clue per word, parallel to `wordFields` by index --
    /// Speagle offers it on request during Practice (see PracticeView).
    @State private var hintFields: [String] = Array(repeating: "", count: 12)
    private enum FocusField: Hashable {
        case word(Int)
        case hint(Int)
    }
    @FocusState private var focusedField: FocusField?

    @State private var showImportSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showSpellCheckConfirmation = false

    /// How many currently-typed words don't match a standard dictionary
    /// spelling (see `SpellCheckService`) -- recomputed on every keystroke
    /// since `wordFields` is what drives it, no separate tracking needed.
    private var flaggedWordCount: Int {
        wordFields.filter(SpellCheckService.isPossiblyMisspelled).count
    }

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
                SpeagleTip(message: "I'll help you get this week's list ready! Type each word below exactly how it should be spelled, capital letters count. Add a hint too, and I'll offer it if they get stuck during practice.", pose: .point, avatarSize: 96)
                header
                wordGrid
                footer
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .speagleBackground()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
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
        .alert("Double check these words", isPresented: $showSpellCheckConfirmation) {
            Button("Review words", role: .cancel) {}
            Button("Save anyway") { finishSaving() }
        } message: {
            Text(flaggedWordCount == 1
                ? "1 word doesn't match a standard dictionary spelling. Make sure it's spelled the way you want before saving."
                : "\(flaggedWordCount) words don't match a standard dictionary spelling. Make sure they're spelled the way you want before saving.")
        }
    }

    private var header: some View {
        let title = VStack(alignment: .leading, spacing: 4) {
            Text("This week's spelling list")
                .font(Theme.display(30))
                .foregroundStyle(Theme.textPrimary)
            Text("\(child.name) · week of \(Date().formatted(.dateTime.month(.wide).day()))")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
        }

        let stepper = HStack(spacing: 12) {
            Text("How many words?")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
            Stepper(value: $wordCount, in: 5...30) {
                Text("\(wordCount)").font(Theme.display(18)).frame(minWidth: 32)
            }
            .fixedSize()
            .onChange(of: wordCount) { _, newValue in resizeFields(to: newValue) }
        }

        return Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    title
                    stepper
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer()
                    stepper
                }
            }
        }
    }

    private var wordGrid: some View {
        // .adaptive rather than a fixed 3 columns -- narrower on an
        // iPhone, where 3 columns of number + text field would otherwise
        // be squeezed uncomfortably tight. Widened from before now that
        // each cell holds a second, hint row underneath the word.
        let columns = [GridItem(.adaptive(minimum: isCompact ? 180 : 260), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<wordFields.count, id: \.self) { index in
                let flagged = SpellCheckService.isPossiblyMisspelled(wordFields[index])
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(index + 1)")
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 20, alignment: .trailing)
                        TextField("", text: binding(for: index))
                            .font(Theme.body(18))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(flagged ? Theme.error.opacity(0.7) : Theme.hairline, lineWidth: flagged ? 1.5 : 1)
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .word(index))
                        // Not in the system dictionary -- a nudge to double
                        // check, not a hard error. A name or uncommon word will
                        // trip this too, so it's never blocking on its own.
                        if flagged {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.error.opacity(0.7))
                        }
                    }
                    // Optional -- Speagle only offers this on request
                    // during Practice (never Test, to keep it a fair
                    // one-try assessment), and only for a word that
                    // actually has one.
                    TextField("Hint Speagle can give (optional)", text: hintBinding(for: index))
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.surface.opacity(0.6))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline.opacity(0.6), lineWidth: 1))
                        .focused($focusedField, equals: .hint(index))
                        .padding(.leading, 28)
                        .grammarAssisted()
                }
            }
        }
    }

    private var footer: some View {
        let caption = Text("Words are read aloud with the iPad voice. Tap a word to record your own voice. A flagged word doesn't match a standard dictionary spelling, double check it before saving.")
            .font(Theme.body(13))
            .foregroundStyle(Theme.textSecondary)

        let buttons = HStack {
            Button("Import a list") {
                showImportSourceDialog = true
            }
            .font(Theme.body(15))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))

            Button("Save list") {
                if flaggedWordCount > 0 {
                    showSpellCheckConfirmation = true
                } else {
                    finishSaving()
                }
            }
            .font(Theme.body(15, weight: .medium))
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.primary, lineWidth: 1.5))
        }

        return VStack(alignment: .leading, spacing: 16) {
            Divider().overlay(Theme.hairline)
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    caption
                    buttons
                }
            } else {
                HStack {
                    caption
                    Spacer()
                    buttons
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < wordFields.count ? wordFields[index] : "" },
            set: { if index < wordFields.count { wordFields[index] = $0 } }
        )
    }

    private func hintBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < hintFields.count ? hintFields[index] : "" },
            set: { if index < hintFields.count { hintFields[index] = $0 } }
        )
    }

    private func resizeFields(to count: Int) {
        if count > wordFields.count {
            wordFields.append(contentsOf: Array(repeating: "", count: count - wordFields.count))
        } else {
            wordFields = Array(wordFields.prefix(count))
        }
        if count > hintFields.count {
            hintFields.append(contentsOf: Array(repeating: "", count: count - hintFields.count))
        } else {
            hintFields = Array(hintFields.prefix(count))
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
        // A photo import has no way to supply hints -- reset rather than
        // leaving stale ones from whatever was typed before misaligned
        // against the newly imported words.
        hintFields = Array(repeating: "", count: wordCount)
        for (index, word) in trimmed.enumerated() where index < wordFields.count {
            wordFields[index] = word
        }
    }

    private func loadExistingWords() {
        guard let list = currentWeekList, let words = list.words, !words.isEmpty else { return }
        wordCount = list.targetWordCount
        var fields = Array(repeating: "", count: max(wordCount, words.count))
        var hints = Array(repeating: "", count: max(wordCount, words.count))
        for word in words.sorted(by: { $0.orderIndex < $1.orderIndex }) where word.orderIndex < fields.count {
            fields[word.orderIndex] = word.text
            hints[word.orderIndex] = word.hint
        }
        wordFields = fields
        hintFields = hints
    }

    private func finishSaving() {
        saveList()
        dismiss()
    }

    private func saveList() {
        let list = currentWeekList ?? {
            let newList = WeekList(weekOf: Date(), targetWordCount: wordCount)
            newList.child = child
            modelContext.insert(newList)
            return newList
        }()
        list.targetWordCount = wordCount

        // Matched to the draft by orderIndex rather than deleted and
        // recreated wholesale -- a SpellingWord's PracticeAttempt history
        // cascades away when it's deleted (see the model's delete rule),
        // so blowing away and rebuilding every word on every save --
        // even ones whose text never changed -- erased a whole week's
        // test scores just for adding or editing one word partway
        // through it. Only a word whose slot is now blank, or whose slot
        // no longer exists (the word count went down), is actually
        // deleted; an edited word keeps its identity (and attempts) with
        // its text simply updated in place.
        var existingByIndex: [Int: SpellingWord] = [:]
        for word in list.words ?? [] {
            existingByIndex[word.orderIndex] = word
        }

        // All inserts/edits happen first, deletes only in one final pass
        // at the end -- same ordering the original all-delete-then-insert
        // code relied on to avoid SwiftData diffing list.words against an
        // object it had already deleted mid-pass (see the note that used
        // to be here).
        var wordsToDelete: [SpellingWord] = []

        for (index, text) in wordFields.enumerated() {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHint = (index < hintFields.count ? hintFields[index] : "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing = existingByIndex.removeValue(forKey: index) {
                if trimmed.isEmpty {
                    wordsToDelete.append(existing)
                } else {
                    if existing.text != trimmed {
                        existing.text = trimmed
                    }
                    if existing.hint != trimmedHint {
                        existing.hint = trimmedHint
                    }
                }
            } else if !trimmed.isEmpty {
                let word = SpellingWord(text: trimmed, orderIndex: index)
                word.hint = trimmedHint
                modelContext.insert(word)
                word.weekList = list
            }
        }

        // Anything left here had no matching field at all this save.
        wordsToDelete.append(contentsOf: existingByIndex.values)

        for word in wordsToDelete {
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

private extension View {
    /// Turns on Apple's Writing Tools (proofread/rewrite, including
    /// grammar correction, not just spelling) for the hint field -- the
    /// most that's realistically available without adding a network
    /// dependency this app deliberately avoids everywhere else. Only
    /// does anything on Apple Intelligence-capable hardware running iOS
    /// 18.1+; older devices/OSes just get the field as it already
    /// behaved (plain system autocorrect, no grammar help), no error.
    @ViewBuilder
    func grammarAssisted() -> some View {
        if #available(iOS 18.0, *) {
            writingToolsBehavior(.complete)
        } else {
            self
        }
    }
}
