package com.spellwithspeagle.android.data.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.spellwithspeagle.android.data.model.Child
import kotlinx.coroutines.flow.Flow

@Dao
interface ChildDao {
    @Query("SELECT * FROM children ORDER BY createdAt ASC")
    fun observeAll(): Flow<List<Child>>

    @Query("SELECT * FROM children WHERE id = :id")
    fun observe(id: String): Flow<Child?>

    @Query("SELECT * FROM children WHERE id = :id")
    suspend fun get(id: String): Child?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(child: Child)

    @Update
    suspend fun update(child: Child)

    @Delete
    suspend fun delete(child: Child)

    @Query("SELECT COUNT(*) FROM children")
    suspend fun count(): Int
}
