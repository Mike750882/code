package com.spellwithspeagle.android.ui.progress

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.model.WeekList
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

enum class WordStatus { CORRECT, INCORRECT, NEVER_ATTEMPTED }

data class WordBreakdown(val word: SpellingWord, val status: WordStatus)

data class WeekReportRow(val weekList: WeekList, val correct: Int, val total: Int, val words: List<WordBreakdown>)

data class ProgressReportUiState(
    val isLoading: Boolean = true,
    val weeks: List<WeekReportRow> = emptyList()
)

/** Covers every week the child has had, not just the current one -- an activity view, not a graded score. */
class ProgressReportViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
) : ViewModel() {
    private val _uiState = MutableStateFlow(ProgressReportUiState())
    val uiState: StateFlow<ProgressReportUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val childId = activeChildStore.activeChildId.first() ?: return@launch
            val weekLists = repository.observeWeekLists(childId).first()
            val rows = weekLists.map { weekList ->
                val words = repository.observeWords(weekList.id).first()
                val attempts = repository.attemptsForWords(words.map { it.id })
                val breakdown = words.map { word -> WordBreakdown(word, statusFor(word.id, attempts)) }
                WeekReportRow(
                    weekList = weekList,
                    correct = breakdown.count { it.status == WordStatus.CORRECT },
                    total = breakdown.size,
                    words = breakdown
                )
            }.sortedByDescending { it.weekList.weekOf }
            _uiState.value = ProgressReportUiState(isLoading = false, weeks = rows)
        }
    }

    /** Each word's *most recent* attempt -- a word retried until right shows as correct, not every retry. */
    private fun statusFor(wordId: String, attempts: List<com.spellwithspeagle.android.data.model.PracticeAttempt>): WordStatus {
        val latest = attempts.filter { it.wordId == wordId }.maxByOrNull { it.date } ?: return WordStatus.NEVER_ATTEMPTED
        return if (latest.isCorrect) WordStatus.CORRECT else WordStatus.INCORRECT
    }
}
