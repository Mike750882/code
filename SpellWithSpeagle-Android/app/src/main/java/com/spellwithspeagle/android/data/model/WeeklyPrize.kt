package com.spellwithspeagle.android.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/** A parent-configured whole-week prize, on top of the four daily rewards. */
@Entity(
    tableName = "weekly_prizes",
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
data class WeeklyPrize(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val childId: String,
    val weekOf: Long,
    val title: String = "",
    val thresholdPercent: Int = 80
)
