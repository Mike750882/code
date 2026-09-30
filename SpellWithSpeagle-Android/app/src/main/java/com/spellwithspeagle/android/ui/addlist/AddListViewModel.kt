package com.spellwithspeagle.android.ui.addlist

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class WordEntry(val text: String = "", val hint: String = "")

data class AddListUiState(
    val isLoading: Boolean = true,
    val entries: List<WordEntry> = emptyList()
)

private const val DEFAULT_WORD_COUNT = 10

class AddListViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
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

    fun updateWord(index: Int, text: String) = updateEntry(index) { it.copy(text = text) }
    fun updateHint(index: Int, hint: String) = updateEntry(index) { it.copy(hint = hint) }

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
