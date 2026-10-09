package com.spellwithspeagle.android.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.spellwithspeagle.android.data.model.WeekList
import kotlinx.coroutines.flow.Flow

@Dao
interface WeekListDao {
    @Query("SELECT * FROM week_lists WHERE childId = :childId ORDER BY weekOf DESC")
    fun observeForChild(childId: String): Flow<List<WeekList>>

    @Query("SELECT * FROM week_lists WHERE childId = :childId AND weekOf = :weekOf LIMIT 1")
    suspend fun findForWeek(childId: String, weekOf: Long): WeekList?

    @Query("SELECT * FROM week_lists WHERE childId = :childId AND weekOf = :weekOf LIMIT 1")
    fun observeForWeek(childId: String, weekOf: Long): Flow<WeekList?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(weekList: WeekList)

    @Update
    suspend fun update(weekList: WeekList)

    @Delete
    suspend fun delete(weekList: WeekList)

    @Query("DELETE FROM week_lists WHERE id = :id")
    suspend fun deleteById(id: String)
}
