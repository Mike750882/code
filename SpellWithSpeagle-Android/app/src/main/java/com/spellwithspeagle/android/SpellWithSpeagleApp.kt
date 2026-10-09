package com.spellwithspeagle.android

import android.app.Application
import com.spellwithspeagle.android.data.db.AppDatabase
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.service.ActiveChildStore
import com.spellwithspeagle.android.service.AuthService
import com.spellwithspeagle.android.service.FridayReminderScheduler
import com.spellwithspeagle.android.service.PinService
import com.spellwithspeagle.android.service.SpeechService
import com.spellwithspeagle.android.service.SpellCheckService
import com.spellwithspeagle.android.service.SyncService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class SpellWithSpeagleApp : Application() {
    lateinit var repository: SpellingRepository
        private set
    lateinit var speechService: SpeechService
        private set
    lateinit var pinService: PinService
        private set
    lateinit var activeChildStore: ActiveChildStore
        private set
    lateinit var spellCheckService: SpellCheckService
        private set
    lateinit var authService: AuthService
        private set
    lateinit var syncService: SyncService
        private set

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        val db = AppDatabase.get(this)
        syncService = SyncService()
        repository = SpellingRepository(
            childDao = db.childDao(),
            weekListDao = db.weekListDao(),
            spellingWordDao = db.spellingWordDao(),
            practiceAttemptDao = db.practiceAttemptDao(),
            dailyRewardDao = db.dailyRewardDao(),
            weeklyPrizeDao = db.weeklyPrizeDao(),
            syncService = syncService
        )
        speechService = SpeechService(this)
        pinService = PinService(this)
        activeChildStore = ActiveChildStore(this)
        spellCheckService = SpellCheckService(this)
        authService = AuthService(this)
        FridayReminderScheduler.ensureChannel(this)

        // Resume cross-device sync on launch if a previous session is still
        // signed in -- Firebase Auth persists sign-in across app restarts,
        // but the live Firestore listeners themselves don't, so they need
        // restarting here. An interactive sign-in (Settings' "Sign in with
        // Google") starts them itself; this only covers the already-signed-in
        // case, which never reaches that code path.
        authService.currentUser?.let { user ->
            applicationScope.launch { syncService.onSignedIn(user.uid, repository) }
        }
    }

    override fun onTerminate() {
        speechService.shutdown()
        super.onTerminate()
    }
}
