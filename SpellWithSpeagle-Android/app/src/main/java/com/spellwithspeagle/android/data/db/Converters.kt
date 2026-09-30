package com.spellwithspeagle.android.data.db

import androidx.room.TypeConverter
import com.spellwithspeagle.android.data.model.PracticeMode

class Converters {
    @TypeConverter
    fun fromPracticeMode(mode: PracticeMode): String = mode.name

    @TypeConverter
    fun toPracticeMode(value: String): PracticeMode = PracticeMode.valueOf(value)
}
