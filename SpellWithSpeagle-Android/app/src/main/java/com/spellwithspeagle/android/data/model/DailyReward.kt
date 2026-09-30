package com.spellwithspeagle.android.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

/** A parent-configured reward for one weekday (Monday=2 .. Thursday=5, matching Calendar.DAY_OF_WEEK). */
@Entity(
    tableName = "daily_rewards",
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
data class DailyReward(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val childId: String,
    val weekOf: Long,
    /** java.util.Calendar.DAY_OF_WEEK: 2 = Monday ... 5 = Thursday. */
    val weekday: Int,
    val rewardText: String = "",
    val thresholdPercent: Int = 70
)
