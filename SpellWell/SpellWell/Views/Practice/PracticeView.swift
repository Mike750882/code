import SwiftUI

enum PracticeMode: String, CaseIterable, Identifiable, Hashable {
    case practice = "Practice"
    case test = "Test"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .practice: return "Try each word as many times as you like."
        case .test: return "One try per word, then see your grade."
        }
    }
}

/// The letter-tile word builder: hear the word, tap scrambled letters into
/// the blanks in any order, undo with "Take one back", then check.
///
/// Behavior branches on `mode`: in Test mode, checking a word -- right or
/// wrong -- flashes feedback and advances to the next one, with no retries,
/// so a right/wrong tally and grade at the end mean something. In Practice
/// mode, a wrong answer just flashes red and lets the child keep trying the
/// same word; there's no grading at the end.
struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechService()

    let weekList: WeekList
    let mode: PracticeMode

    @State private var currentIndex = 0
    /// Per answer-slot: which letter-bank index is placed there, or nil if
    /// empty. Indexed by slot position, not fill order, so a letter can be
    /// dragged into any blank rather than only the next empty one in line.
    @State private var slotContents: [Int?] = []
    /// Slot indices in the order they were filled (by tap or drag), so
    /// "Take one back" can undo the most recent placement regardless of
    /// which slot it landed in.
    @State private var fillOrder: [Int] = []
    @State private var bankOrder: [Character] = []
    /// Which slot a dragged letter is currently hovering over, for a
    /// highlight while dropping -- nil when nothing is being dragged onto
    /// a slot.
    @State private var dragTargetSlot: Int?
    @State private var feedback: Feedback?
    @State private var isAdvancing = false
    @State private var results: [WordResult] = []
    /// One ID for this whole session, stamped onto every PracticeAttempt
    /// recorded here -- lets Home's daily grade use only the most recent
    /// session's result for a day when a test is retaken.
    @State private var sessionID = UUID()

    enum Feedback { case correct, incorrect }

    private var words: [SpellingWord] {
        (weekList.words ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var currentWord: SpellingWord? {
        currentIndex < words.count ? words[currentIndex] : nil
    }

    private var usedBankIndices: Set<Int> { Set(slotContents.compactMap { $0 }) }

    private var currentAttemptString: String {
        slotContents.compactMap { $0.map { String(bankOrder[$0]) } }.joined()
    }

    var body: some View {
        VStack(spacing: 0) {
            if currentWord != nil {
                topBar
            }
            Spacer()
            if let word = currentWord {
                hearWordSection(word: word)
                answerSlots(wordLength: word.text.count)
                letterBank
                actionButtons
            } else if mode == .test {
                PracticeResultsView(results: results) { dismiss() }
            } else {
                completionView
            }
            Spacer()
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear { setUpWord() }
        .onChange(of: currentIndex) { _, _ in setUpWord() }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Label("Home", systemImage: "chevron.left")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.textPrimary)
            }
            ProgressView(value: Double(currentIndex), total: Double(max(words.count, 1)))
                .tint(Theme.blue)
                .padding(.horizontal, 16)
            Text("Word \(min(currentIndex + 1, words.count)) of \(words.count)")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func hearWordSection(word: SpellingWord) -> some View {
        HStack(spacing: 16) {
            Button {
                speech.speak(word.text, customAudioData: word.customAudioData, voiceIdentifier: weekList.child?.voiceIdentifier)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.blue)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Theme.blue, lineWidth: 1.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Tap to hear the word")
                    .font(Theme.display(24))
                    .foregroundStyle(Theme.textPrimary)
                Text("Say it slowly · Use it in a sentence")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.bottom, 40)
    }

    private func answerSlots(wordLength: Int) -> some View {
        let borderColor: Color = {
            switch feedback {
            case .correct: return Theme.green
            case .incorrect: return Theme.coral
            case nil: return Theme.hairline
            }
        }()
        return HStack(spacing: 10) {
            ForEach(0..<wordLength, id: \.self) { slotIndex in
                let bankIndex = slotIndex < slotContents.count ? slotContents[slotIndex] : nil
                let letter = bankIndex.map { String(bankOrder[$0]) } ?? ""
                let isTargeted = dragTargetSlot == slotIndex
                Text(letter.uppercased())
                    .font(Theme.display(28))
                    .frame(width: 56, height: 64)
                    .background(isTargeted ? Theme.purple.opacity(0.15) : Theme.surface)
                    .overlay(
                        Rectangle().stroke(isTargeted ? Theme.purple : borderColor, lineWidth: isTargeted ? 2 : (feedback == nil ? 1 : 2))
                    )
                    .onTapGesture { clearSlot(slotIndex) }
                    .dropDestination(for: String.self) { items, _ in
                        guard let raw = items.first,
                              raw.hasPrefix("bank:"),
                              let draggedIndex = Int(raw.dropFirst(5))
                        else { return false }
                        place(bankIndex: draggedIndex, inSlot: slotIndex)
                        return true
                    } isTargeted: { targeted in
                        dragTargetSlot = targeted ? slotIndex : nil
                    }
            }
        }
        .padding(.bottom, 20)
    }

    private var letterBank: some View {
        HStack(spacing: 10) {
            ForEach(Array(bankOrder.enumerated()), id: \.offset) { index, letter in
                bankTile(index: index, letter: letter)
            }
        }
        .padding(.bottom, 32)
        .allowsHitTesting(!isAdvancing)
    }

    /// A letter tile can be tapped (fills the first empty slot) or dragged
    /// (drops into whichever slot the child chooses) -- drag is only
    /// attached to unused tiles, so an already-placed one can't be dragged
    /// again from the bank.
    private func bankTile(index: Int, letter: Character) -> some View {
        let used = usedBankIndices.contains(index)
        let tile = Text(String(letter).uppercased())
            .font(Theme.display(24))
            .frame(width: 56, height: 64)
            .background(Theme.surface)
            .overlay(
                Rectangle().stroke(used ? Theme.purple.opacity(0.25) : Theme.purple, lineWidth: used ? 1 : 2)
            )
            .opacity(used ? 0.4 : 1)
            .onTapGesture {
                guard !used else { return }
                placeInFirstEmptySlot(bankIndex: index)
            }

        return Group {
            if used {
                tile
            } else {
                tile.draggable("bank:\(index)")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Take one back") { takeOneBack() }
                .font(Theme.body(16))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))

            Button("Check my word") { checkWord() }
                .font(Theme.body(16, weight: .medium))
                .foregroundStyle(Theme.coral)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.coral, lineWidth: 1.5))
        }
        .disabled(isAdvancing)
        .opacity(isAdvancing ? 0.4 : 1)
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.coral)
            Text("All done for today!")
                .font(Theme.display(28))
                .foregroundStyle(Theme.textPrimary)
            Button("Back to Home") { dismiss() }
                .font(Theme.body(16, weight: .medium))
                .foregroundStyle(Theme.blue)
        }
    }

    private func setUpWord() {
        feedback = nil
        guard let word = currentWord else {
            slotContents = []
            fillOrder = []
            return
        }
        bankOrder = Array(word.text.lowercased()).shuffled()
        slotContents = Array(repeating: nil, count: word.text.count)
        fillOrder = []
    }

    private func place(bankIndex: Int, inSlot slotIndex: Int) {
        guard !isAdvancing,
              slotIndex < slotContents.count,
              slotContents[slotIndex] == nil,
              !usedBankIndices.contains(bankIndex)
        else { return }
        slotContents[slotIndex] = bankIndex
        fillOrder.append(slotIndex)
        feedback = nil
    }

    private func placeInFirstEmptySlot(bankIndex: Int) {
        guard !isAdvancing, let firstEmpty = slotContents.firstIndex(where: { $0 == nil }) else { return }
        place(bankIndex: bankIndex, inSlot: firstEmpty)
    }

    private func clearSlot(_ slotIndex: Int) {
        guard !isAdvancing, slotIndex < slotContents.count, slotContents[slotIndex] != nil else { return }
        slotContents[slotIndex] = nil
        fillOrder.removeAll { $0 == slotIndex }
        feedback = nil
    }

    private func takeOneBack() {
        guard !isAdvancing, let lastSlot = fillOrder.popLast() else { return }
        slotContents[lastSlot] = nil
        feedback = nil
    }

    private func checkWord() {
        guard !isAdvancing, let word = currentWord else { return }
        let attempt = currentAttemptString
        let isCorrect = attempt.lowercased() == word.text.lowercased()

        let record = PracticeAttempt(isCorrect: isCorrect, mode: mode.rawValue.lowercased())
        record.sessionID = sessionID
        record.word = word
        modelContext.insert(record)
        feedback = isCorrect ? .correct : .incorrect

        switch mode {
        case .test:
            results.append(WordResult(word: word.text, attempt: attempt, isCorrect: isCorrect))
            isAdvancing = true
            Task {
                try? await Task.sleep(nanoseconds: 700_000_000)
                isAdvancing = false
                currentIndex += 1
            }
        case .practice:
            // Wrong answers just leave the red flash showing -- placing or
            // clearing a letter clears it as soon as the child edits again,
            // so they can keep retrying the same word.
            if isCorrect {
                currentIndex += 1
            }
        }
    }
}
