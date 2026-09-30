package com.spellwithspeagle.android.ui.practice

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.repository.SpellingRepository
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
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                words = words,
                hintAvailable = hintAvailableFor(words.firstOrNull(), activeChild)
            )
            speakCurrentWord()
        }
    }

    private fun hintAvailableFor(word: SpellingWord?, child: Child?): Boolean {
        if (word == null || word.hint.isBlank()) return false
        return requestedMode == PracticeMode.PRACTICE || (child?.allowHintsDuringTest == true)
    }

    fun onAnswerChanged(text: String) {
        _uiState.value = _uiState.value.copy(typedAnswer = text)
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
        val typed = state.typedAnswer
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
            val isCorrect = state.typedAnswer.trim() == word.text
            _uiState.value = state.copy(results = state.results + WordResultUi(word, isCorrect, state.typedAnswer))
        }
        advance()
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
            _uiState.value = state.copy(
                currentIndex = nextIndex,
                typedAnswer = "",
                feedback = null,
                hintAvailable = hintAvailableFor(state.words[nextIndex], child)
            )
            speakCurrentWord()
        }
    }
}
