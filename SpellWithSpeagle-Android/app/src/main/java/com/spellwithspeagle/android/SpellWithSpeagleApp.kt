package com.spellwithspeagle.android

import android.app.Application
import com.spellwithspeagle.android.data.db.AppDatabase
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import com.spellwithspeagle.android.service.FridayReminderScheduler
import com.spellwithspeagle.android.service.PinService
import com.spellwithspeagle.android.service.SpeechService

class SpellWithSpeagleApp : Application() {
    lateinit var repository: SpellingRepository
        private set
    lateinit var speechService: SpeechService
        private set
    lateinit var pinService: PinService
        private set
    lateinit var activeChildStore: ActiveChildStore
        private set

    override fun onCreate() {
        super.onCreate()
        val db = AppDatabase.get(this)
        repository = SpellingRepository(
            childDao = db.childDao(),
            weekListDao = db.weekListDao(),
            spellingWordDao = db.spellingWordDao(),
            practiceAttemptDao = db.practiceAttemptDao(),
            dailyRewardDao = db.dailyRewardDao(),
            weeklyPrizeDao = db.weeklyPrizeDao()
        )
        speechService = SpeechService(this)
        pinService = PinService(this)
        activeChildStore = ActiveChildStore(this)
        FridayReminderScheduler.ensureChannel(this)
    }

    override fun onTerminate() {
        speechService.shutdown()
        super.onTerminate()
    }
}
