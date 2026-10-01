package com.spellwithspeagle.android.ui.practice

import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.model.WordInputMode

enum class CheckFeedback { CORRECT, INCORRECT }

data class WordResultUi(val word: SpellingWord, val isCorrect: Boolean, val typed: String)

/** One blank in the tile row. */
sealed interface SlotState {
    data object Empty : SlotState
    /** Holds a tile from [PracticeUiState.bankLetters] at [bankIndex]. */
    data class Filled(val bankIndex: Int) : SlotState
    /** A letter given for free (TILES_SCAFFOLDED), locked -- never tappable. */
    data class Prefilled(val char: Char) : SlotState
}

data class PracticeUiState(
    val isLoading: Boolean = true,
    val mode: PracticeMode = PracticeMode.PRACTICE,
    val words: List<SpellingWord> = emptyList(),
    val currentIndex: Int = 0,
    val feedback: CheckFeedback? = null,
    val hintAvailable: Boolean = false,
    val isSessionComplete: Boolean = false,
    val results: List<WordResultUi> = emptyList(),

    /** Today's configured mode for the current word -- same for every word in the session. */
    val inputMode: WordInputMode = WordInputMode.TYPED,

    // WordInputMode.TYPED:
    val typedAnswer: String = "",

    // Every other mode (tile-based):
    val slots: List<SlotState> = emptyList(),
    /** Only the letters still needed to fill non-prefilled slots, pre-shuffled. */
    val bankLetters: List<Char> = emptyList(),
    val bankUsed: List<Boolean> = emptyList(),
    /** Stack of slot indices filled, most recent last -- powers "Take one back" regardless of which slot it was. */
    val fillOrder: List<Int> = emptyList()
) {
    val currentWord: SpellingWord? get() = words.getOrNull(currentIndex)
    val progressLabel: String get() = if (words.isEmpty()) "" else "${currentIndex + 1} / ${words.size}"

    /** The word as currently spelled out, or null while any tile mode slot is still empty. Always non-null (possibly blank) for TYPED. */
    val answerText: String?
        get() = if (inputMode == WordInputMode.TYPED) {
            typedAnswer
        } else {
            if (slots.any { it is SlotState.Empty }) return null
            buildString {
                slots.forEach { slot ->
                    when (slot) {
                        is SlotState.Prefilled -> append(slot.char)
                        is SlotState.Filled -> append(bankLetters[slot.bankIndex])
                        SlotState.Empty -> Unit
                    }
                }
            }
        }
}
