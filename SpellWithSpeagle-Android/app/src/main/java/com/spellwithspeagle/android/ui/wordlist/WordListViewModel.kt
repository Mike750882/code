package com.spellwithspeagle.android.ui.wordlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class WordListUiState(
    val isLoading: Boolean = true,
    val words: List<SpellingWord> = emptyList()
)

/** Ungated "study aid" preview of this week's words -- no correct/incorrect info, just the list. */
class WordListViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
) : ViewModel() {
    private val _uiState = MutableStateFlow(WordListUiState())
    val uiState: StateFlow<WordListUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val childId = activeChildStore.activeChildId.first() ?: return@launch
            val words = repository.wordsForCurrentWeek(childId)
            _uiState.value = WordListUiState(isLoading = false, words = words)
        }
    }
}
