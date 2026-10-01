package com.spellwithspeagle.android.ui.practice

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.model.WordInputMode
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.domain.WeekUtils
import com.spellwithspeagle.android.service.ActiveChildStore
import com.spellwithspeagle.android.service.SpeechService
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/** Feedback flashes for this long before Practice re-enables editing / Test advances. */
private const val FEEDBACK_DELAY_MS = 900L

class PracticeViewModel(
    private val repository: SpellingRepository,
    private val speechService: SpeechService,
    private val activeChildStore: ActiveChildStore,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val requestedMode =
        if (savedStateHandle.get<String>("mode") == "TEST") PracticeMode.TEST else PracticeMode.PRACTICE
    private val restrictToWordIds: List<String>? = savedStateHandle.get<String>("restrictTo")
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.takeIf { it.isNotEmpty() }

    private val _uiState = MutableStateFlow(PracticeUiState(mode = requestedMode))
    val uiState: StateFlow<PracticeUiState> = _uiState.asStateFlow()

    private var child: Child? = null
    private val sessionId = repository.newSessionId()
    private val sessionAttempts = mutableListOf<PracticeAttempt>()

    init {
        viewModelScope.launch {
            val activeChildId = activeChildStore.activeChildId.first() ?: return@launch
            val activeChild = repository.observeChild(activeChildId).first() ?: return@launch
            child = activeChild
            val allWords = repository.wordsForCurrentWeek(activeChild.id)
            val words = if (restrictToWordIds != null) {
                allWords.filter { it.id in restrictToWordIds }
            } else {
                allWords
            }
            val todaysMode = WordInputMode.forWeekday(WeekUtils.weekdayOf(System.currentTimeMillis()), activeChild)
            val firstWordSetup = words.firstOrNull()?.let { setupWordInput(it, todaysMode) } ?: WordSetup()
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                words = words,
                inputMode = todaysMode,
                hintAvailable = hintAvailableFor(words.firstOrNull(), activeChild),
                slots = firstWordSetup.slots,
                bankLetters = firstWordSetup.bankLetters,
                bankUsed = firstWordSetup.bankUsed
            )
            speakCurrentWord()
        }
    }

    private fun hintAvailableFor(word: SpellingWord?, child: Child?): Boolean {
        if (word == null || word.hint.isBlank()) return false
        return requestedMode == PracticeMode.PRACTICE || (child?.allowHintsDuringTest == true)
    }

    private data class WordSetup(
        val slots: List<SlotState> = emptyList(),
        val bankLetters: List<Char> = emptyList(),
        val bankUsed: List<Boolean> = emptyList()
    )

    /**
     * Builds this word's blanks + letter bank for a tile mode. HALF_AND_HALF
     * resolves fresh to one of the other two treatments every time a word
     * comes up, matching iOS -- not always the same words in each half.
     */
    private fun setupWordInput(word: SpellingWord, mode: WordInputMode): WordSetup {
        if (mode == WordInputMode.TYPED) return WordSetup()

        val resolvedMode = if (mode == WordInputMode.HALF_AND_HALF) {
            if (kotlin.random.Random.nextBoolean()) WordInputMode.TILES_SCAFFOLDED else WordInputMode.TILES_FULL
        } else {
            mode
        }

        val letters = word.text.toList()
        val prefilledIndices = if (resolvedMode == WordInputMode.TILES_SCAFFOLDED) {
            letters.indices.shuffled().take(letters.size / 2).toSet()
        } else {
            emptySet()
        }

        val slots = letters.mapIndexed { index, char ->
            if (index in prefilledIndices) SlotState.Prefilled(char) else SlotState.Empty
        }
        val bankLetters = letters.filterIndexed { index, _ -> index !in prefilledIndices }.shuffled()
        val bankUsed = List(bankLetters.size) { false }

        return WordSetup(slots = slots, bankLetters = bankLetters, bankUsed = bankUsed)
    }

    fun onAnswerChanged(text: String) {
        _uiState.value = _uiState.value.copy(typedAnswer = text)
    }

    /** Tapping an unused bank tile fills the first empty blank. */
    fun tapBankTile(bankIndex: Int) {
        val state = _uiState.value
        if (bankIndex !in state.bankUsed.indices || state.bankUsed[bankIndex]) return
        val firstEmpty = state.slots.indexOfFirst { it is SlotState.Empty }
        if (firstEmpty == -1) return

        val slots = state.slots.toMutableList().apply { this[firstEmpty] = SlotState.Filled(bankIndex) }
        val bankUsed = state.bankUsed.toMutableList().apply { this[bankIndex] = true }
        _uiState.value = state.copy(slots = slots, bankUsed = bankUsed, fillOrder = state.fillOrder + firstEmpty)
    }

    /** Tapping a filled slot clears just that letter back to the bank. */
    fun tapSlot(slotIndex: Int) {
        val state = _uiState.value
        val slot = state.slots.getOrNull(slotIndex) as? SlotState.Filled ?: return
        val slots = state.slots.toMutableList().apply { this[slotIndex] = SlotState.Empty }
        val bankUsed = state.bankUsed.toMutableList().apply { this[slot.bankIndex] = false }
        _uiState.value = state.copy(slots = slots, bankUsed = bankUsed, fillOrder = state.fillOrder - slotIndex)
    }

    /** Undoes whichever slot was filled most recently, regardless of which one it was. */
    fun takeOneBack() {
        val state = _uiState.value
        val lastIndex = state.fillOrder.lastOrNull() ?: return
        tapSlot(lastIndex)
    }

    fun speakCurrentWord() {
        val word = _uiState.value.currentWord ?: return
        speechService.speak(word.text, child?.voiceIdentifier)
    }

    fun speakHint() {
        val word = _uiState.value.currentWord ?: return
        if (word.hint.isNotBlank()) speechService.speak(word.hint, child?.voiceIdentifier)
    }

    fun checkAnswer() {
        val state = _uiState.value
        val word = state.currentWord ?: return
        val typed = state.answerText ?: return
        val isCorrect = typed.trim() == word.text

        val updatedResults = state.results.toMutableList()
        val existingIndex = updatedResults.indexOfFirst { it.word.id == word.id }
        val result = WordResultUi(word, isCorrect, typed)
        if (existingIndex >= 0) updatedResults[existingIndex] = result else updatedResults.add(result)

        if (state.mode == PracticeMode.TEST) {
            sessionAttempts.add(PracticeAttempt(wordId = word.id, isCorrect = isCorrect, mode = PracticeMode.TEST, sessionId = sessionId))
        }

        _uiState.value = state.copy(
            feedback = if (isCorrect) CheckFeedback.CORRECT else CheckFeedback.INCORRECT,
            results = updatedResults
        )

        viewModelScope.launch {
            delay(FEEDBACK_DELAY_MS)
            if (state.mode == PracticeMode.TEST || isCorrect) {
                advance()
            } else {
                // Practice + wrong: clear feedback, let the child retry the same word.
                _uiState.value = _uiState.value.copy(feedback = null)
            }
        }
    }

    /** Practice-only: move on without requiring a correct answer. */
    fun skipWord() {
        val state = _uiState.value
        val word = state.currentWord ?: return
        if (state.results.none { it.word.id == word.id }) {
            val typed = partialAnswerText(state)
            val isCorrect = typed.trim() == word.text
            _uiState.value = state.copy(results = state.results + WordResultUi(word, isCorrect, typed))
        }
        advance()
    }

    /** Whatever's arranged/typed so far, even if incomplete -- used when skipping a word never checked. */
    private fun partialAnswerText(state: PracticeUiState): String {
        if (state.inputMode == WordInputMode.TYPED) return state.typedAnswer
        return buildString {
            state.slots.forEach { slot ->
                when (slot) {
                    is SlotState.Prefilled -> append(slot.char)
                    is SlotState.Filled -> append(state.bankLetters[slot.bankIndex])
                    SlotState.Empty -> Unit
                }
            }
        }
    }

    private fun advance() {
        val state = _uiState.value
        val nextIndex = state.currentIndex + 1
        if (nextIndex >= state.words.size) {
            _uiState.value = state.copy(isSessionComplete = true, feedback = null)
            if (state.mode == PracticeMode.TEST && sessionAttempts.isNotEmpty()) {
                viewModelScope.launch { repository.recordAttempts(sessionAttempts) }
            }
        } else {
            val nextWord = state.words[nextIndex]
            val setup = setupWordInput(nextWord, state.inputMode)
            _uiState.value = state.copy(
                currentIndex = nextIndex,
                typedAnswer = "",
                feedback = null,
                hintAvailable = hintAvailableFor(nextWord, child),
                slots = setup.slots,
                bankLetters = setup.bankLetters,
                bankUsed = setup.bankUsed,
                fillOrder = emptyList()
            )
            speakCurrentWord()
        }
    }
}
