package com.spellwithspeagle.android.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

/**
 * A student profile. Mirrors the iOS `Child` SwiftData model. The parent PIN
 * itself is NOT stored here -- it lives in EncryptedSharedPreferences, shared
 * across every profile on the device, same as the iOS Keychain entry.
 */
@Entity(tableName = "children")
data class Child(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val textScale: Double = 1.0,
    /** "system" | "light" | "dark" */
    val appearance: String = "system",
    /** Matches a [com.spellwithspeagle.android.ui.theme.ColorProfile.id]. */
    val colorProfile: String = "default",
    /** A TextToSpeech voice name, or "" to use the device default. */
    val voiceIdentifier: String = "",
    val createdAt: Long = System.currentTimeMillis(),

    // Per-weekday WordInputMode.name for Monday-Thursday; Friday is always
    // "TYPED" and isn't user-configurable (see WordInputMode.forWeekday).
    val mondayInputMode: String = "TILES_SCAFFOLDED",
    val tuesdayInputMode: String = "TILES_FULL",
    val wednesdayInputMode: String = "HALF_AND_HALF",
    val thursdayInputMode: String = "TYPED",

    val fridayNotificationEnabled: Boolean = false,
    val fridayNotificationHour: Int = 7,
    val fridayNotificationMinute: Int = 0,

    val allowHintsDuringTest: Boolean = false
)
