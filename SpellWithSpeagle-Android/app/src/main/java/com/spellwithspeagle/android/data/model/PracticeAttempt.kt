package com.spellwithspeagle.android.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import java.util.UUID

enum class PracticeMode { PRACTICE, TEST }

/**
 * One checked word, in either Practice or Test mode. Only TEST attempts
 * count toward a day's grade -- Practice allows unlimited retries, so
 * counting it would make every day read as 100%.
 */
@Entity(
    tableName = "practice_attempts",
    foreignKeys = [
        ForeignKey(
            entity = SpellingWord::class,
            parentColumns = ["id"],
            childColumns = ["wordId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("wordId"), Index("sessionId")]
)
data class PracticeAttempt(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val wordId: String,
    val date: Long = System.currentTimeMillis(),
    val isCorrect: Boolean,
    val mode: PracticeMode,
    /**
     * Shared by every attempt recorded in one practice/test session. Lets a
     * day's grade use only the most recent session's attempts instead of
     * blending in an earlier, retaken attempt from the same day.
     */
    val sessionId: String
)
