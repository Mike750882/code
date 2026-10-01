package com.spellwithspeagle.android.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.WordInputMode
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import com.spellwithspeagle.android.service.SpeechService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class WeekSummary(val weekOf: Long, val correct: Int, val total: Int)

data class SettingsUiState(
    val isLoading: Boolean = true,
    val child: Child? = null,
    val voices: List<SpeechService.VoiceOption> = emptyList(),
    val weeksSummary: List<WeekSummary> = emptyList()
)

class SettingsViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore,
    private val speechService: SpeechService
) : ViewModel() {
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val id = activeChildStore.activeChildId.first() ?: return@launch
            val child = repository.observeChild(id).first() ?: return@launch
            val voices = speechService.availableVoices()
            val weekLists = repository.observeWeekLists(id).first()
            val summaries = weekLists.map { weekList ->
                val words = repository.observeWords(weekList.id).first()
                val attempts = repository.attemptsForWords(words.map { it.id })
                WeekSummary(weekList.weekOf, attempts.count { it.isCorrect }, attempts.size)
            }.sortedByDescending { it.weekOf }
            _uiState.value = SettingsUiState(isLoading = false, child = child, voices = voices, weeksSummary = summaries)
        }
    }

    fun setVoice(name: String) = updateChild { it.copy(voiceIdentifier = name) }
    fun previewVoice(name: String) = speechService.speak("Spell With Speagle", name)
    fun setColorProfile(id: String) = updateChild { it.copy(colorProfile = id) }
    fun setInputMode(weekday: Int, mode: WordInputMode) = updateChild { WordInputMode.fieldFor(weekday, mode)(it) }
    fun setAllowHintsDuringTest(allow: Boolean) = updateChild { it.copy(allowHintsDuringTest = allow) }
    fun setFridayReminder(enabled: Boolean) = updateChild { it.copy(fridayNotificationEnabled = enabled) }
    fun setAppearance(appearance: String) = updateChild { it.copy(appearance = appearance) }
    fun setTextScale(scale: Double) = updateChild { it.copy(textScale = scale) }

    private fun updateChild(transform: (Child) -> Child) {
        val current = _uiState.value.child ?: return
        val updated = transform(current)
        _uiState.value = _uiState.value.copy(child = updated)
        viewModelScope.launch { repository.updateChild(updated) }
    }
}
