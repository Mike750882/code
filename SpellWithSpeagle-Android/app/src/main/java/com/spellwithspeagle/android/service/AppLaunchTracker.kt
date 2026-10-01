package com.spellwithspeagle.android.service

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore

private val Context.launchDataStore by preferencesDataStore(name = "launch_tracker")
private val LAUNCH_COUNT = intPreferencesKey("launch_count")
private val TOUR_DISMISSED = booleanPreferencesKey("tour_dismissed")

/**
 * Backs the dismissible "Take a Tour" banner on Home -- shown only for the
 * app's first two launches, or until dismissed early, matching iOS's
 * `AppLaunchTracker`. Backed by DataStore so it resets on reinstall.
 */
object AppLaunchTracker {
    // Computed once per process the first time it's asked -- revisiting
    // Home within the same session (e.g. after finishing Practice)
    // shouldn't increment the persisted launch count again.
    private var cachedShouldShowBanner: Boolean? = null

    suspend fun shouldShowTourBanner(context: Context): Boolean {
        cachedShouldShowBanner?.let { return it }
        var count = 0
        var dismissed = false
        context.launchDataStore.edit { prefs ->
            count = (prefs[LAUNCH_COUNT] ?: 0) + 1
            prefs[LAUNCH_COUNT] = count
            dismissed = prefs[TOUR_DISMISSED] ?: false
        }
        val result = count <= 2 && !dismissed
        cachedShouldShowBanner = result
        return result
    }

    suspend fun dismissTourBanner(context: Context) {
        context.launchDataStore.edit { it[TOUR_DISMISSED] = true }
        cachedShouldShowBanner = false
    }
}
