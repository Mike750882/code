package com.spellwithspeagle.android.ui.profiles

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import kotlinx.coroutines.launch

class AddChildViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
) : ViewModel() {
    fun addChild(name: String, onDone: () -> Unit) {
        viewModelScope.launch {
            val child = repository.addChild(name)
            activeChildStore.setActiveChild(child.id)
            onDone()
        }
    }
}
