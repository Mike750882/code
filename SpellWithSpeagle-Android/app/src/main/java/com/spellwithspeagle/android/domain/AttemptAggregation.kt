package com.spellwithspeagle.android.domain

import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.PracticeMode

/**
 * Collapses a set of attempts to just each weekday's most recent Test-mode
 * session -- a retaken day's earlier, superseded attempts are dropped
 * instead of being averaged in alongside the retake that replaced them.
 * Mirrors iOS `Array<PracticeAttempt>.latestSessionPerWeekday`.
 */
fun List<PracticeAttempt>.latestSessionPerWeekday(): List<PracticeAttempt> {
    val testAttempts = filter { it.mode == PracticeMode.TEST }
    val byWeekday = testAttempts.groupBy { WeekUtils.weekdayOf(it.date) }
    return byWeekday.values.flatMap { dayAttempts ->
        val latestSessionId = dayAttempts.maxByOrNull { it.date }?.sessionId ?: return@flatMap emptyList()
        dayAttempts.filter { it.sessionId == latestSessionId }
    }
}

/** Percent correct (0-100), or null if [this] is empty. */
fun List<PracticeAttempt>.percentCorrect(): Int? {
    if (isEmpty()) return null
    val correct = count { it.isCorrect }
    return (correct * 100) / size
}
