package com.spellwithspeagle.android.ui.settings

import android.content.Intent
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.WordInputMode
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.domain.WeekUtils
import com.spellwithspeagle.android.service.ActiveChildStore
import com.spellwithspeagle.android.service.AuthService
import com.spellwithspeagle.android.service.SpeechService
import com.spellwithspeagle.android.service.SyncService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

enum class SyncStatus { SIGNED_OUT, SYNCING, UP_TO_DATE, FAILED }

data class SettingsUiState(
    val isLoading: Boolean = true,
    val child: Child? = null,
    val voices: List<SpeechService.VoiceOption> = emptyList(),
    /** This week only, correct/total -- an activity count, not a graded score. The full history lives in the Progress Report screen. */
    val thisWeekCorrect: Int = 0,
    val thisWeekTotal: Int = 0,
    val signedInEmail: String? = null,
    val syncStatus: SyncStatus = SyncStatus.SIGNED_OUT
)

class SettingsViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore,
    private val speechService: SpeechService,
    private val authService: AuthService,
    private val syncService: SyncService
) : ViewModel() {
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val id = activeChildStore.activeChildId.first() ?: return@launch
            val child = repository.observeChild(id).first() ?: return@launch
            val voices = speechService.availableVoices()
            val weekList = repository.observeWeekList(id, WeekUtils.startOfWeek()).first()
            val attempts = if (weekList == null) {
                emptyList()
            } else {
                val words = repository.observeWords(weekList.id).first()
                repository.attemptsForWords(words.map { it.id })
            }
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                child = child,
                voices = voices,
                thisWeekCorrect = attempts.count { it.isCorrect },
                thisWeekTotal = attempts.size
            )
        }
        viewModelScope.launch {
            authService.authState.collect { user ->
                _uiState.value = _uiState.value.copy(
                    signedInEmail = user?.email,
                    syncStatus = when {
                        user == null -> SyncStatus.SIGNED_OUT
                        _uiState.value.syncStatus == SyncStatus.SIGNED_OUT -> SyncStatus.UP_TO_DATE
                        else -> _uiState.value.syncStatus
                    }
                )
            }
        }
    }

    fun signInIntent(): Intent = authService.signInIntent()

    /** Call with the result [Intent] from the sign-in [android.content.Intent] launcher's callback. */
    fun handleSignInResult(data: Intent?) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(syncStatus = SyncStatus.SYNCING)
            val result = authService.handleSignInResult(data)
            val user = result.getOrNull()
            if (user == null) {
                _uiState.value = _uiState.value.copy(syncStatus = SyncStatus.FAILED)
                return@launch
            }
            runCatching { syncService.onSignedIn(user.uid, repository) }
                .onSuccess { _uiState.value = _uiState.value.copy(syncStatus = SyncStatus.UP_TO_DATE) }
                .onFailure { _uiState.value = _uiState.value.copy(syncStatus = SyncStatus.FAILED) }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            syncService.onSignedOut()
            authService.signOut()
            _uiState.value = _uiState.value.copy(signedInEmail = null, syncStatus = SyncStatus.SIGNED_OUT)
        }
    }

    fun setVoice(name: String) = updateChild { it.copy(voiceIdentifier = name) }
    fun previewVoice(name: String) = speechService.speak("Spell With Speagle", name)
    fun setColorProfile(id: String) = updateChild { it.copy(colorProfile = id) }
    fun setInputMode(weekday: Int, mode: WordInputMode) = updateChild { WordInputMode.fieldFor(weekday, mode)(it) }
    fun setAllowHintsDuringTest(allow: Boolean) = updateChild { it.copy(allowHintsDuringTest = allow) }
    fun setFridayReminder(enabled: Boolean) = updateChild { it.copy(fridayNotificationEnabled = enabled) }
    fun setFridayReminderTime(hour: Int, minute: Int) = updateChild { it.copy(fridayNotificationHour = hour, fridayNotificationMinute = minute) }
    fun setAppearance(appearance: String) = updateChild { it.copy(appearance = appearance) }
    fun setTextScale(scale: Double) = updateChild { it.copy(textScale = scale) }

    private fun updateChild(transform: (Child) -> Child) {
        val current = _uiState.value.child ?: return
        val updated = transform(current)
        _uiState.value = _uiState.value.copy(child = updated)
        viewModelScope.launch { repository.updateChild(updated) }
    }
}
