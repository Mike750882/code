package com.spellwithspeagle.android.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import com.spellwithspeagle.android.data.dao.ChildDao
import com.spellwithspeagle.android.data.dao.DailyRewardDao
import com.spellwithspeagle.android.data.dao.PracticeAttemptDao
import com.spellwithspeagle.android.data.dao.SpellingWordDao
import com.spellwithspeagle.android.data.dao.WeekListDao
import com.spellwithspeagle.android.data.dao.WeeklyPrizeDao
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.DailyReward
import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.model.WeekList
import com.spellwithspeagle.android.data.model.WeeklyPrize

@Database(
    entities = [
        Child::class,
        WeekList::class,
        SpellingWord::class,
        PracticeAttempt::class,
        DailyReward::class,
        WeeklyPrize::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun childDao(): ChildDao
    abstract fun weekListDao(): WeekListDao
    abstract fun spellingWordDao(): SpellingWordDao
    abstract fun practiceAttemptDao(): PracticeAttemptDao
    abstract fun dailyRewardDao(): DailyRewardDao
    abstract fun weeklyPrizeDao(): WeeklyPrizeDao

    companion object {
        @Volatile private var instance: AppDatabase? = null

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "spell_with_speagle.db"
                ).build().also { instance = it }
            }
    }
}
