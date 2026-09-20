import SwiftUI

private struct SlotFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

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

/// Which challenge a word uses. Chosen per weekday in Settings
/// (`Child.inputMode(forWeekday:)`) so a parent can ease a child from
/// scaffolded tiles up to typing from memory across the week, independent
/// of the Practice/Test toggle -- both modes share whatever the day says.
enum WordInputMode: String, CaseIterable, Identifiable, Hashable {
    case tilesScaffolded
    case tilesFull
    case halfAndHalf
    case typed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tilesScaffolded: return "Tiles: some letters given"
        case .tilesFull: return "Tiles: fill in every letter"
        case .halfAndHalf: return "Half tiles, half typed"
        case .typed: return "Type from memory"
        }
    }

    /// A short line for Home's practice card, so a child knows what kind
    /// of challenge today's words use before they start.
    var homeCardSubtitle: String {
        switch self {
        case .tilesScaffolded: return "Listen, then fill in the missing letters, some are already there."
        case .tilesFull: return "Listen, then build each word from letter tiles."
        case .halfAndHalf: return "Listen, some words use letter tiles, others you'll type from memory."
        case .typed: return "Listen, then type each word from memory."
        }
    }

    /// `.halfAndHalf` isn't a real per-word mode -- it resolves to one of
    /// the other two, fresh per word, so which words land in each half
    /// changes on every attempt rather than always being the same ones.
    var resolvedForWord: WordInputMode {
        self == .halfAndHalf ? (Bool.random() ? .tilesFull : .typed) : self
    }
}

/// One answer blank's state. Separate from the letter bank's tiles because
/// a scaffolded word's given letters aren't drawn from the bank at all --
/// they're just shown, locked, from the start.
private enum SlotState: Equatable {
    case prefilled(Character)
    case empty
    case filled(bankIndex: Int)
}

/// The letter-tile word builder: hear the word, tap or drag scrambled
/// letters into the blanks in any order, undo with "Take one back," then
/// check. On a day set to "Type from memory," there's no tile UI at all --
/// just a text field.
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
    /// Per answer-slot state, indexed by slot position, not fill order, so
    /// a letter can be dragged into any blank rather than only the next
    /// empty one in line. Empty for the current word when its day's mode
    /// is `.typed` -- there's nothing to render here then.
    @State private var slotContents: [SlotState] = []
    /// Slot indices in the order they were filled (by tap or drag), so
    /// "Take one back" can undo the most recent placement regardless of
    /// which slot it landed in.
    @State private var fillOrder: [Int] = []
    /// Only the letters still needed for this word's empty slots -- on a
    /// scaffolded word, the already-given letters never enter the bank.
    @State private var bankOrder: [Character] = []
    /// Which slot a dragged letter is currently hovering over, for a
    /// highlight while dropping -- nil when nothing is being dragged onto
    /// a slot.
    @State private var dragTargetSlot: Int?
    /// Which bank tile is actively being dragged, and by how much, so it
    /// can be drawn following the finger. A plain DragGesture (rather than
    /// the system .draggable/.dropDestination pair) starts moving the tile
    /// the instant a finger slides, with no "hold to lift" delay first --
    /// a tap is just a drag that ends with almost no movement.
    @State private var draggingBankIndex: Int?
    @State private var dragTranslation: CGSize = .zero
    /// Each answer slot's frame in the shared "practiceArea" coordinate
    /// space, so a drag's release point can be tested against them.
    @State private var slotFrames: [Int: CGRect] = [:]
    /// This word's challenge type, resolved fresh each time a new word is
    /// set up -- on a `.halfAndHalf` day this is where that resolves to
    /// either tiles or typed for this particular word.
    @State private var currentWordMode: WordInputMode = .tilesFull
    /// Practice allows retrying a word after a miss (see `checkWord`), so
    /// this tracks whether the *first* attempt at the current word has
    /// already gone into `results` -- retries after that update `feedback`
    /// and can still advance on a correct answer, but don't add duplicate
    /// entries to the end-of-session results screen.
    @State private var recordedFirstAttempt = false
    @State private var typedAnswer: String = ""
    @FocusState private var isTypedFieldFocused: Bool
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

    private var usedBankIndices: Set<Int> {
        Set(slotContents.compactMap { slot in
            if case .filled(let index) = slot { return index }
            return nil
        })
    }

    private var currentAttemptString: String {
        if currentWordMode == .typed {
            return typedAnswer
        }
        return slotContents.map { slot -> String in
            switch slot {
            case .prefilled(let character): return String(character)
            case .filled(let index): return index < bankOrder.count ? String(bankOrder[index]) : ""
            case .empty: return ""
            }
        }.joined()
    }

    var body: some View {
        VStack(spacing: 0) {
            if currentWord != nil {
                topBar
            }
            Spacer()
            if let word = currentWord {
                hearWordSection(word: word)
                if currentWordMode == .typed {
                    typedAnswerField
                } else {
                    answerSlots(wordLength: word.text.count)
                    letterBank
                }
                actionButtons
            } else {
                PracticeResultsView(results: results) { dismiss() }
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .coordinateSpace(name: "practiceArea")
        .onPreferenceChange(SlotFramesKey.self) { slotFrames = $0 }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isTypedFieldFocused = false }
            }
        }
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
                let slot: SlotState = slotIndex < slotContents.count ? slotContents[slotIndex] : .empty
                let isTargeted = dragTargetSlot == slotIndex

                switch slot {
                case .prefilled(let character):
                    Text(String(character).uppercased())
                        .font(Theme.display(28))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 56, height: 64)
                        .background(Theme.hairline.opacity(0.3))
                        .overlay(Rectangle().stroke(Theme.hairline, lineWidth: 1))
                default:
                    let letter: String = {
                        if case .filled(let index) = slot, index < bankOrder.count { return String(bankOrder[index]) }
                        return ""
                    }()
                    Text(letter.uppercased())
                        .font(Theme.display(28))
                        .frame(width: 56, height: 64)
                        .background(isTargeted ? Theme.purple.opacity(0.15) : Theme.surface)
                        .overlay(
                            Rectangle().stroke(isTargeted ? Theme.purple : borderColor, lineWidth: isTargeted ? 2 : (feedback == nil ? 1 : 2))
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: SlotFramesKey.self,
                                    value: [slotIndex: geo.frame(in: .named("practiceArea"))]
                                )
                            }
                        )
                        .onTapGesture { clearSlot(slotIndex) }
                }
            }
        }
        .padding(.bottom, 20)
    }

    private var typedAnswerField: some View {
        TextField("Type the word", text: $typedAnswer)
            .font(Theme.display(28))
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isTypedFieldFocused)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: 360)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlCornerRadius)
                    .stroke(feedback == .incorrect ? Theme.coral : Theme.hairline, lineWidth: feedback == nil ? 1 : 2)
            )
            .onSubmit { checkWord() }
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

    /// A letter tile slides with the finger the instant it moves -- no
    /// hold-to-lift delay like the system drag-and-drop APIs require -- and
    /// drops into whichever empty slot it's released over. A tap (a "drag"
    /// that ends with barely any movement) still fills the first empty
    /// slot. Only attached to unused tiles, so an already-placed one can't
    /// be picked up again from the bank.
    private func bankTile(index: Int, letter: Character) -> some View {
        let used = usedBankIndices.contains(index)
        let isDragging = draggingBankIndex == index
        let tile = Text(String(letter).uppercased())
            .font(Theme.display(24))
            .frame(width: 56, height: 64)
            .background(Theme.surface)
            .overlay(
                Rectangle().stroke(used ? Theme.purple.opacity(0.25) : Theme.purple, lineWidth: used ? 1 : 2)
            )
            .opacity(used ? 0.4 : 1)
            .scaleEffect(isDragging ? 1.08 : 1)
            .shadow(color: isDragging ? Color.black.opacity(0.2) : .clear, radius: isDragging ? 6 : 0, y: isDragging ? 3 : 0)
            .offset(isDragging ? dragTranslation : .zero)
            .zIndex(isDragging ? 1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)

        return Group {
            if used {
                tile
            } else {
                tile.gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("practiceArea"))
                        .onChanged { value in
                            draggingBankIndex = index
                            dragTranslation = value.translation
                            dragTargetSlot = emptySlot(at: value.location)
                        }
                        .onEnded { value in
                            let distance = hypot(value.translation.width, value.translation.height)
                            if distance < 8 {
                                placeInFirstEmptySlot(bankIndex: index)
                            } else if let target = emptySlot(at: value.location) {
                                place(bankIndex: index, inSlot: target)
                            }
                            draggingBankIndex = nil
                            dragTranslation = .zero
                            dragTargetSlot = nil
                        }
                )
            }
        }
    }

    private func emptySlot(at location: CGPoint) -> Int? {
        slotFrames.first { slotIndex, frame in
            frame.contains(location) && slotIndex < slotContents.count && slotContents[slotIndex] == .empty
        }?.key
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            if currentWordMode != .typed {
                Button("Take one back") { takeOneBack() }
                    .font(Theme.body(16))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }

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

    private func setUpWord() {
        feedback = nil
        typedAnswer = ""
        recordedFirstAttempt = false
        guard let word = currentWord else {
            slotContents = []
            fillOrder = []
            bankOrder = []
            return
        }

        let dayMode = weekList.child?.inputMode(forWeekday: Calendar.current.component(.weekday, from: Date())) ?? .tilesFull
        currentWordMode = dayMode.resolvedForWord
        let letters = Array(word.text.lowercased())

        switch currentWordMode {
        case .typed:
            bankOrder = []
            slotContents = []

        case .tilesScaffolded:
            let prefilledCount = letters.count / 2
            let prefilledPositions = Set(letters.indices.shuffled().prefix(prefilledCount))
            var remainingLetters: [Character] = []
            var slots: [SlotState] = []
            for (position, character) in letters.enumerated() {
                if prefilledPositions.contains(position) {
                    slots.append(.prefilled(character))
                } else {
                    slots.append(.empty)
                    remainingLetters.append(character)
                }
            }
            bankOrder = remainingLetters.shuffled()
            slotContents = slots

        case .tilesFull, .halfAndHalf:
            // .halfAndHalf never actually reaches here -- currentWordMode
            // was already resolved above -- but the switch has to be
            // exhaustive, and this is the right fallback behavior anyway.
            bankOrder = letters.shuffled()
            slotContents = Array(repeating: .empty, count: letters.count)
        }

        fillOrder = []
    }

    private func place(bankIndex: Int, inSlot slotIndex: Int) {
        guard !isAdvancing,
              slotIndex < slotContents.count,
              slotContents[slotIndex] == .empty,
              !usedBankIndices.contains(bankIndex)
        else { return }
        slotContents[slotIndex] = .filled(bankIndex: bankIndex)
        fillOrder.append(slotIndex)
        feedback = nil
    }

    private func placeInFirstEmptySlot(bankIndex: Int) {
        guard !isAdvancing, let firstEmpty = slotContents.firstIndex(where: { $0 == .empty }) else { return }
        place(bankIndex: bankIndex, inSlot: firstEmpty)
    }

    private func clearSlot(_ slotIndex: Int) {
        guard !isAdvancing, slotIndex < slotContents.count, case .filled = slotContents[slotIndex] else { return }
        slotContents[slotIndex] = .empty
        fillOrder.removeAll { $0 == slotIndex }
        feedback = nil
    }

    private func takeOneBack() {
        guard !isAdvancing, let lastSlot = fillOrder.popLast() else { return }
        slotContents[lastSlot] = .empty
        feedback = nil
    }

    private func checkWord() {
        guard !isAdvancing, let word = currentWord else { return }
        let attempt = currentAttemptString
        let isCorrect = attempt.lowercased() == word.text.lowercased()
        feedback = isCorrect ? .correct : .incorrect

        switch mode {
        case .test:
            // Every check is a fresh word (no retries), recorded both into
            // this session's results and permanently as a PracticeAttempt
            // -- Test is what daily grades and the Progress Report are
            // built from.
            let record = PracticeAttempt(isCorrect: isCorrect, mode: mode.rawValue.lowercased())
            record.sessionID = sessionID
            record.word = word
            modelContext.insert(record)
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
            // so they can keep retrying the same word until they get it.
            // Only the first attempt goes into this session's end-of-
            // practice results, and nothing here is ever persisted as a
            // PracticeAttempt -- practice is just for rehearsing, and
            // shouldn't show up later in the Progress Report or count
            // toward any grade.
            if !recordedFirstAttempt {
                results.append(WordResult(word: word.text, attempt: attempt, isCorrect: isCorrect))
                recordedFirstAttempt = true
            }
            if isCorrect {
                currentIndex += 1
            }
        }
    }
}
