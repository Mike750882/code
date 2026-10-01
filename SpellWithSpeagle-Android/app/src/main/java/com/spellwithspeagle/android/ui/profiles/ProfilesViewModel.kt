package com.spellwithspeagle.android.ui.profiles

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class ProfilesUiState(
    val children: List<Child> = emptyList(),
    val activeChildId: String? = null
)

class ProfilesViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
) : ViewModel() {
    val uiState: StateFlow<ProfilesUiState> = combine(
        repository.observeChildren(),
        activeChildStore.activeChildId
    ) { children, activeId ->
        ProfilesUiState(children = children, activeChildId = activeId)
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProfilesUiState())

    fun switchTo(childId: String) {
        viewModelScope.launch { activeChildStore.setActiveChild(childId) }
    }

    /** Never deletes the last remaining profile -- there must always be at least one. */
    fun delete(child: Child) {
        val state = uiState.value
        if (state.children.size <= 1) return
        viewModelScope.launch {
            repository.deleteChild(child)
            if (state.activeChildId == child.id) {
                val next = state.children.firstOrNull { it.id != child.id }
                if (next != null) activeChildStore.setActiveChild(next.id)
            }
        }
    }
}
