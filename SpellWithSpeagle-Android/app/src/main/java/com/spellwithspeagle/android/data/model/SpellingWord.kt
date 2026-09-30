package com.spellwithspeagle.android.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/** One word in a [WeekList], with an optional parent-written hint. */
@Entity(
    tableName = "spelling_words",
    foreignKeys = [
        ForeignKey(
            entity = WeekList::class,
            parentColumns = ["id"],
            childColumns = ["weekListId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("weekListId")]
)
data class SpellingWord(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val weekListId: String,
    val text: String,
    val orderIndex: Int,
    /**
     * Optional parent-written clue Speagle speaks aloud on request. Always
     * exactly what the parent typed, never generated or looked up -- this
     * app makes no network calls.
     */
    val hint: String = "",
    /** Path to a parent-recorded pronunciation clip, or null for none. */
    val customAudioPath: String? = null
)
