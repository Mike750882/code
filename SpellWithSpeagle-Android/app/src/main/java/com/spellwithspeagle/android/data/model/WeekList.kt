package com.spellwithspeagle.android.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/** One week's spelling list, owned by a [Child]. */
@Entity(
    tableName = "week_lists",
    foreignKeys = [
        ForeignKey(
            entity = Child::class,
            parentColumns = ["id"],
            childColumns = ["childId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("childId")]
)
data class WeekList(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val childId: String,
    /** Start-of-week epoch millis (local midnight Monday). */
    val weekOf: Long,
    val targetWordCount: Int = 12
)
