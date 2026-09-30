package com.spellwithspeagle.android.ui

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.createSavedStateHandle
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.spellwithspeagle.android.SpellWithSpeagleApp
import com.spellwithspeagle.android.ui.home.HomeViewModel
import com.spellwithspeagle.android.ui.practice.PracticeViewModel
import com.spellwithspeagle.android.ui.profiles.AddChildViewModel

private fun CreationExtras.spellApp(): SpellWithSpeagleApp =
    this[ViewModelProvider.AndroidViewModelFactory.APPLICATION_KEY] as SpellWithSpeagleApp

/** Hand-rolled factory wiring -- avoids pulling in a DI framework for this scaffold's first slice. */
object AppViewModelProvider {
    val Factory = viewModelFactory {
        initializer {
            HomeViewModel(spellApp().repository, spellApp().activeChildStore)
        }
        initializer {
            PracticeViewModel(spellApp().repository, spellApp().speechService, spellApp().activeChildStore, createSavedStateHandle())
        }
        initializer {
            AddChildViewModel(spellApp().repository, spellApp().activeChildStore)
        }
    }
}
