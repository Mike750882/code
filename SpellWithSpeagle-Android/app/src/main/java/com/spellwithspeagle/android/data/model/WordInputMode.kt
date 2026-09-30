package com.spellwithspeagle.android.data.model

import java.util.Calendar

/**
 * A per-weekday difficulty progression applied to both Practice and Test.
 * Mirrors iOS `WordInputMode`.
 */
enum class WordInputMode {
    /** About half of each word's letters are pre-filled and locked. */
    TILES_SCAFFOLDED,
    /** Every blank starts empty; the full word's letters are in the bank. */
    TILES_FULL,
    /** Each word is independently, randomly resolved to one of the other two tile treatments. */
    HALF_AND_HALF,
    /** No letter tiles -- a plain text field. */
    TYPED;

    val homeCardSubtitle: String
        get() = when (this) {
            TILES_SCAFFOLDED -> "Some letters given"
            TILES_FULL -> "Unscramble the letters"
            HALF_AND_HALF -> "A mix of tiles and typing"
            TYPED -> "Type it from memory"
        }

    companion object {
        /**
         * Friday (day 6) is always [TYPED] -- the real weekly test, not one
         * of the four adjustable practice days -- unconditionally, ahead of
         * the Monday-Thursday lookup.
         */
        fun forWeekday(weekday: Int, child: Child): WordInputMode {
            if (weekday == Calendar.FRIDAY) return TYPED
            val raw = when (weekday) {
                Calendar.MONDAY -> child.mondayInputMode
                Calendar.TUESDAY -> child.tuesdayInputMode
                Calendar.WEDNESDAY -> child.wednesdayInputMode
                Calendar.THURSDAY -> child.thursdayInputMode
                else -> TILES_FULL.name
            }
            return runCatching { valueOf(raw) }.getOrDefault(TILES_FULL)
        }

        fun fieldFor(weekday: Int, mode: WordInputMode): (Child) -> Child = { child ->
            when (weekday) {
                Calendar.MONDAY -> child.copy(mondayInputMode = mode.name)
                Calendar.TUESDAY -> child.copy(tuesdayInputMode = mode.name)
                Calendar.WEDNESDAY -> child.copy(wednesdayInputMode = mode.name)
                Calendar.THURSDAY -> child.copy(thursdayInputMode = mode.name)
                else -> child
            }
        }
    }
}
