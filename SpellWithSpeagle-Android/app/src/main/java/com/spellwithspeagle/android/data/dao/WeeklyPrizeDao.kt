package com.spellwithspeagle.android.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.spellwithspeagle.android.data.model.WeeklyPrize
import kotlinx.coroutines.flow.Flow

@Dao
interface WeeklyPrizeDao {
    @Query("SELECT * FROM weekly_prizes WHERE childId = :childId AND weekOf = :weekOf LIMIT 1")
    fun observeForWeek(childId: String, weekOf: Long): Flow<WeeklyPrize?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(prize: WeeklyPrize)

    @Update
    suspend fun update(prize: WeeklyPrize)

    @Query("DELETE FROM weekly_prizes WHERE id = :id")
    suspend fun deleteById(id: String)
}
