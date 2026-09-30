package com.spellwithspeagle.android.service

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "app_prefs")
private val ACTIVE_CHILD_ID = stringPreferencesKey("active_child_id")

/**
 * Which profile is showing -- device-local, not synced, mirroring iOS's
 * `@AppStorage("activeChildID")`: a family with one device per kid can have
 * each default to a different student.
 */
class ActiveChildStore(private val context: Context) {
    val activeChildId: Flow<String?> = context.dataStore.data.map { it[ACTIVE_CHILD_ID] }

    suspend fun setActiveChild(id: String) {
        context.dataStore.edit { it[ACTIVE_CHILD_ID] = id }
    }
}
