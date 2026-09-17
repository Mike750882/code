import SwiftUI

/// The letter-tile word builder: hear the word, tap scrambled letters into
/// the blanks in any order, undo with "Take one back", then check.
///
/// Checking a word -- right or wrong -- advances to the next one after a
/// brief flash of feedback; there's no retrying a word once it's been
/// checked. That's what makes a real right/wrong tally and grade at the end
/// meaningful, the same way an actual spelling test works.
struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var speech = SpeechService()

    let weekList: WeekList

    @State private var currentIndex = 0
    @State private var placedLetters: [Character] = []
    @State private var placedBankIndices: [Int] = []
    @State private var bankOrder: [Character] = []
    @State private var feedback: Feedback?
    @State private var results: [WordResult] = []

    enum Feedback { case correct, incorrect }

    private var words: [SpellingWord] {
        (weekList.words ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
    }

    private var currentWord: SpellingWord? {
        currentIndex < words.count ? words[currentIndex] : nil
    }

    private var usedBankIndices: Set<Int> { Set(placedBankIndices) }

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
            } else {
                PracticeResultsView(results: results) { dismiss() }
            }
            Spacer()
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
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
                speech.speak(word.text, customAudioData: word.customAudioData)
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
            ForEach(0..<wordLength, id: \.self) { index in
                let letter = index < placedLetters.count ? String(placedLetters[index]) : ""
                Text(letter.uppercased())
                    .font(Theme.display(28))
                    .frame(width: 56, height: 64)
                    .background(Theme.surface)
                    .overlay(Rectangle().stroke(borderColor, lineWidth: feedback == nil ? 1 : 2))
            }
        }
        .padding(.bottom, 20)
    }

    private var letterBank: some View {
        HStack(spacing: 10) {
            ForEach(Array(bankOrder.enumerated()), id: \.offset) { index, letter in
                let used = usedBankIndices.contains(index)
                Button {
                    placeLetter(letter, bankIndex: index)
                } label: {
                    Text(String(letter).uppercased())
                        .font(Theme.display(24))
                        .frame(width: 56, height: 64)
                        .background(Theme.surface)
                        .overlay(
                            Rectangle().stroke(used ? Theme.purple.opacity(0.25) : Theme.purple, lineWidth: used ? 1 : 2)
                        )
                        .opacity(used ? 0.4 : 1)
                }
                .disabled(used)
            }
        }
        .padding(.bottom, 32)
        .allowsHitTesting(feedback == nil)
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
        .disabled(feedback != nil)
        .opacity(feedback == nil ? 1 : 0.4)
    }

    private func setUpWord() {
        placedLetters = []
        placedBankIndices = []
        feedback = nil
        guard let word = currentWord else { return }
        bankOrder = Array(word.text.lowercased()).shuffled()
    }

    private func placeLetter(_ letter: Character, bankIndex: Int) {
        guard feedback == nil, let word = currentWord, placedLetters.count < word.text.count else { return }
        placedLetters.append(letter)
        placedBankIndices.append(bankIndex)
    }

    private func takeOneBack() {
        guard !placedLetters.isEmpty else { return }
        placedLetters.removeLast()
        placedBankIndices.removeLast()
    }

    private func checkWord() {
        guard feedback == nil, let word = currentWord else { return }
        let attempt = String(placedLetters)
        let isCorrect = attempt.lowercased() == word.text.lowercased()

        let record = PracticeAttempt(isCorrect: isCorrect)
        record.word = word
        modelContext.insert(record)
        results.append(WordResult(word: word.text, isCorrect: isCorrect))

        feedback = isCorrect ? .correct : .incorrect
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            currentIndex += 1
        }
    }
}
