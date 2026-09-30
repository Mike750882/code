package com.spellwithspeagle.android.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.spellwithspeagle.android.data.model.SpellingWord
import kotlinx.coroutines.flow.Flow

@Dao
interface SpellingWordDao {
    @Query("SELECT * FROM spelling_words WHERE weekListId = :weekListId ORDER BY orderIndex ASC")
    fun observeForWeek(weekListId: String): Flow<List<SpellingWord>>

    @Query("SELECT * FROM spelling_words WHERE weekListId = :weekListId ORDER BY orderIndex ASC")
    suspend fun getForWeek(weekListId: String): List<SpellingWord>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(words: List<SpellingWord>)

    @Update
    suspend fun update(word: SpellingWord)

    @Delete
    suspend fun delete(word: SpellingWord)

    @Query("DELETE FROM spelling_words WHERE id IN (:ids)")
    suspend fun deleteByIds(ids: List<String>)
}
