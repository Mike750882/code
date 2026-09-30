package com.spellwithspeagle.android.domain

/** Shared percent-to-letter-grade scale, so a score never shows as two different grades in two places. */
object Grading {
    fun letter(percent: Int): String = when {
        percent >= 97 -> "A+"
        percent >= 93 -> "A"
        percent >= 90 -> "A-"
        percent >= 87 -> "B+"
        percent >= 83 -> "B"
        percent >= 80 -> "B-"
        percent >= 77 -> "C+"
        percent >= 73 -> "C"
        percent >= 70 -> "C-"
        percent >= 67 -> "D+"
        percent >= 63 -> "D"
        percent >= 60 -> "D-"
        else -> "F"
    }

    fun caption(percent: Int): String = when {
        percent >= 90 -> "Excellent!"
        percent >= 80 -> "Good Job!"
        percent >= 70 -> "Getting Better"
        else -> "Need More Practice!"
    }
}
