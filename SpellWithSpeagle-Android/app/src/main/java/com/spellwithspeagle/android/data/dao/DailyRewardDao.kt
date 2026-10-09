package com.spellwithspeagle.android.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.spellwithspeagle.android.data.model.DailyReward
import kotlinx.coroutines.flow.Flow

@Dao
interface DailyRewardDao {
    @Query("SELECT * FROM daily_rewards WHERE childId = :childId AND weekOf = :weekOf ORDER BY weekday ASC")
    fun observeForWeek(childId: String, weekOf: Long): Flow<List<DailyReward>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(reward: DailyReward)

    @Update
    suspend fun update(reward: DailyReward)

    @Query("DELETE FROM daily_rewards WHERE id = :id")
    suspend fun deleteById(id: String)
}
