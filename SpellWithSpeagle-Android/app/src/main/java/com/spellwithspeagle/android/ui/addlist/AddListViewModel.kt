package com.spellwithspeagle.android.ui.addlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import com.spellwithspeagle.android.service.SpellCheckService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class WordEntry(val text: String = "", val hint: String = "", val isMisspelled: Boolean = false)

data class AddListUiState(
    val isLoading: Boolean = true,
    val entries: List<WordEntry> = emptyList()
)

private const val DEFAULT_WORD_COUNT = 10

class AddListViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore,
    private val spellCheckService: SpellCheckService
) : ViewModel() {
    private val _uiState = MutableStateFlow(AddListUiState())
    val uiState: StateFlow<AddListUiState> = _uiState.asStateFlow()

    private var childId: String? = null

    init {
        viewModelScope.launch {
            val id = activeChildStore.activeChildId.first() ?: return@launch
            childId = id
            val words = repository.wordsForCurrentWeek(id)
            val entries = if (words.isEmpty()) {
                List(DEFAULT_WORD_COUNT) { WordEntry() }
            } else {
                words.map { WordEntry(text = it.text, hint = it.hint) }
            }
            _uiState.value = AddListUiState(isLoading = false, entries = entries)
        }
    }

    fun updateWord(index: Int, text: String) {
        updateEntry(index) { it.copy(text = text, isMisspelled = false) }
        viewModelScope.launch {
            val misspelled = spellCheckService.isMisspelled(text.trim())
            // The field may have changed again (or been removed) while the
            // check was in flight -- only apply the result if it's still
            // checking the same text.
            val current = _uiState.value.entries.getOrNull(index) ?: return@launch
            if (current.text == text) updateEntry(index) { it.copy(isMisspelled = misspelled) }
        }
    }

    fun updateHint(index: Int, hint: String) = updateEntry(index) { it.copy(hint = hint) }

    fun hasMisspellings(): Boolean = _uiState.value.entries.any { it.isMisspelled }

    /** Recognized words replace the current draft, matching iOS's photo-import behavior. */
    fun importWords(words: List<String>) {
        if (words.isEmpty()) return
        _uiState.value = _uiState.value.copy(entries = words.map { WordEntry(text = it) })
        words.indices.forEach { index -> updateWord(index, words[index]) }
    }

    private fun updateEntry(index: Int, transform: (WordEntry) -> WordEntry) {
        val entries = _uiState.value.entries.toMutableList()
        if (index !in entries.indices) return
        entries[index] = transform(entries[index])
        _uiState.value = _uiState.value.copy(entries = entries)
    }

    fun addWordSlot() {
        _uiState.value = _uiState.value.copy(entries = _uiState.value.entries + WordEntry())
    }

    fun removeWordSlot(index: Int) {
        val entries = _uiState.value.entries.toMutableList()
        if (index !in entries.indices) return
        entries.removeAt(index)
        _uiState.value = _uiState.value.copy(entries = entries)
    }

    fun save(onDone: () -> Unit) {
        val id = childId ?: return
        viewModelScope.launch {
            val weekList = repository.getOrCreateCurrentWeekList(id)
            val nonBlank = _uiState.value.entries.filter { it.text.isNotBlank() }
            repository.saveWords(weekList.id, nonBlank.map { it.text.trim() to it.hint.trim() })
            onDone()
        }
    }
}
