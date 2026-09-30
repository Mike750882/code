package com.spellwithspeagle.android.ui.practice

import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.SpellingWord

enum class CheckFeedback { CORRECT, INCORRECT }

data class WordResultUi(val word: SpellingWord, val isCorrect: Boolean, val typed: String)

data class PracticeUiState(
    val isLoading: Boolean = true,
    val mode: PracticeMode = PracticeMode.PRACTICE,
    val words: List<SpellingWord> = emptyList(),
    val currentIndex: Int = 0,
    val typedAnswer: String = "",
    val feedback: CheckFeedback? = null,
    val hintAvailable: Boolean = false,
    val isSessionComplete: Boolean = false,
    val results: List<WordResultUi> = emptyList()
) {
    val currentWord: SpellingWord? get() = words.getOrNull(currentIndex)
    val progressLabel: String get() = if (words.isEmpty()) "" else "${currentIndex + 1} / ${words.size}"
}
