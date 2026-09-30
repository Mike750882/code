package com.spellwithspeagle.android.domain

import java.util.Calendar

/** Week-boundary helpers, matching iOS's Monday-start `weekOf` convention. */
object WeekUtils {
    /** Local midnight of the Monday on/before [date] (defaults to now). */
    fun startOfWeek(date: Long = System.currentTimeMillis()): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = date
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        // Calendar.MONDAY=2 ... SUNDAY=1(7); roll back to this week's Monday.
        val weekday = cal.get(Calendar.DAY_OF_WEEK)
        val daysSinceMonday = (weekday - Calendar.MONDAY + 7) % 7
        cal.add(Calendar.DAY_OF_YEAR, -daysSinceMonday)
        return cal.timeInMillis
    }

    fun weekdayOf(date: Long): Int {
        val cal = Calendar.getInstance()
        cal.timeInMillis = date
        return cal.get(Calendar.DAY_OF_WEEK)
    }
}
