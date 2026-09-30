package com.spellwithspeagle.android.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.spellwithspeagle.android.data.model.PracticeAttempt
import kotlinx.coroutines.flow.Flow

/**
 * Attempts are joined back to their [com.spellwithspeagle.android.data.model.SpellingWord]
 * via [wordId]; callers that need a week's worth of attempts filter by the
 * week's word ids (see PracticeRepository).
 */
@Dao
interface PracticeAttemptDao {
    @Insert
    suspend fun insertAll(attempts: List<PracticeAttempt>)

    @Insert
    suspend fun insert(attempt: PracticeAttempt)

    @Query("SELECT * FROM practice_attempts WHERE wordId IN (:wordIds)")
    fun observeForWords(wordIds: List<String>): Flow<List<PracticeAttempt>>

    @Query("SELECT * FROM practice_attempts WHERE wordId IN (:wordIds)")
    suspend fun getForWords(wordIds: List<String>): List<PracticeAttempt>

    @Query("SELECT * FROM practice_attempts WHERE wordId = :wordId ORDER BY date DESC")
    fun observeForWord(wordId: String): Flow<List<PracticeAttempt>>
}
