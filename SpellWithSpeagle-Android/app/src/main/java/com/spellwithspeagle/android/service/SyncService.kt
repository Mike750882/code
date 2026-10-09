package com.spellwithspeagle.android.service

import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.DailyReward
import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.SpellingWord
import com.spellwithspeagle.android.data.model.WeekList
import com.spellwithspeagle.android.data.model.WeeklyPrize
import com.spellwithspeagle.android.data.repository.SpellingRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

private const val CHILDREN = "children"
private const val WEEK_LISTS = "weekLists"
private const val SPELLING_WORDS = "spellingWords"
private const val PRACTICE_ATTEMPTS = "practiceAttempts"
private const val DAILY_REWARDS = "dailyRewards"
private const val WEEKLY_PRIZES = "weeklyPrizes"

/**
 * Mirrors the six Room tables [SpellingRepository] owns into Firestore,
 * scoped under `users/{uid}/...` for whichever Google account is signed
 * in -- the Android equivalent of iOS's automatic CloudKit sync, except
 * explicit (there's no "already signed into iCloud" on Android) and with
 * simple last-write-wins conflict handling, the same default behavior
 * CloudKit itself falls back to since nothing here does field-level merge.
 *
 * Every push*/delete* method below is safe to call even while signed out
 * -- it just no-ops -- so [SpellingRepository] can call them after every
 * local write unconditionally, without checking sign-in state itself.
 */
class SyncService {
    private val db = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var uid: String? = null
    private var listeners: List<ListenerRegistration> = emptyList()

    private fun base() = uid?.let { db.collection("users").document(it) }
    private fun collection(name: String) = base()?.collection(name)

    // --- Lifecycle ---

    /**
     * Call once right after sign-in. If Firestore already has data for
     * this account (a second device joining an existing sync group), that
     * remote copy wins and overwrites local Room -- otherwise (first
     * device for this account) the local copy becomes the new cloud
     * baseline. Either way, starts the live listeners that keep every
     * signed-in device in sync from here on.
     */
    suspend fun onSignedIn(uid: String, repository: SpellingRepository) {
        this.uid = uid
        val remoteChildren = db.collection("users").document(uid).collection(CHILDREN).get().await()
        if (remoteChildren.isEmpty) {
            pushAll(repository)
        } else {
            pullAll(repository)
        }
        startListening(repository)
    }

    fun onSignedOut() {
        listeners.forEach { it.remove() }
        listeners = emptyList()
        uid = null
    }

    // --- Push (local write -> Firestore) ---

    fun pushChild(child: Child) {
        collection(CHILDREN)?.document(child.id)?.set(child.toMap())
    }

    fun pushWeekList(weekList: WeekList) {
        collection(WEEK_LISTS)?.document(weekList.id)?.set(weekList.toMap())
    }

    fun pushWord(word: SpellingWord) {
        collection(SPELLING_WORDS)?.document(word.id)?.set(word.toMap())
    }

    fun pushAttempts(attempts: List<PracticeAttempt>) {
        val target = collection(PRACTICE_ATTEMPTS) ?: return
        attempts.forEach { target.document(it.id).set(it.toMap()) }
    }

    fun pushDailyReward(reward: DailyReward) {
        collection(DAILY_REWARDS)?.document(reward.id)?.set(reward.toMap())
    }

    fun pushWeeklyPrize(prize: WeeklyPrize) {
        collection(WEEKLY_PRIZES)?.document(prize.id)?.set(prize.toMap())
    }

    fun pushDeleteWords(ids: List<String>) {
        val target = collection(SPELLING_WORDS) ?: return
        ids.forEach { target.document(it).delete() }
    }

    /**
     * Firestore has no cascade delete, so removing a child also has to
     * find and remove every week list/word/attempt/reward/prize that
     * pointed at it, mirroring Room's `ForeignKey.CASCADE`.
     */
    fun pushDeleteChild(childId: String) {
        val uid = this.uid ?: return
        collection(CHILDREN)?.document(childId)?.delete()
        scope.launch {
            runCatching {
                val base = db.collection("users").document(uid)
                base.collection(WEEK_LISTS).whereEqualTo("childId", childId).get().await()
                    .documents.forEach { cascadeDeleteWeekList(base, it.id) }
                base.collection(DAILY_REWARDS).whereEqualTo("childId", childId).get().await()
                    .documents.forEach { it.reference.delete() }
                base.collection(WEEKLY_PRIZES).whereEqualTo("childId", childId).get().await()
                    .documents.forEach { it.reference.delete() }
            }
        }
    }

    private suspend fun cascadeDeleteWeekList(base: com.google.firebase.firestore.DocumentReference, weekListId: String) {
        base.collection(WEEK_LISTS).document(weekListId).delete().await()
        base.collection(SPELLING_WORDS).whereEqualTo("weekListId", weekListId).get().await().documents.forEach { wordDoc ->
            wordDoc.reference.delete()
            base.collection(PRACTICE_ATTEMPTS).whereEqualTo("wordId", wordDoc.id).get().await()
                .documents.forEach { it.reference.delete() }
        }
    }

    // --- First sync for this account: push everything local up as the baseline ---

    private suspend fun pushAll(repository: SpellingRepository) {
        val children = repository.observeChildren().first()
        children.forEach { child ->
            pushChild(child)
            val weekLists = repository.observeWeekLists(child.id).first()
            weekLists.forEach { weekList ->
                pushWeekList(weekList)
                val words = repository.observeWords(weekList.id).first()
                words.forEach { word ->
                    pushWord(word)
                    pushAttempts(repository.attemptsForWords(listOf(word.id)))
                }
                repository.observeDailyRewards(child.id, weekList.weekOf).first().forEach { pushDailyReward(it) }
                repository.observeWeeklyPrize(child.id, weekList.weekOf).first()?.let { pushWeeklyPrize(it) }
            }
        }
    }

    // --- Joining an existing sync group: pull everything remote down into Room ---

    private suspend fun pullAll(repository: SpellingRepository) {
        val base = base() ?: return
        base.collection(CHILDREN).get().await().documents.forEach { repository.upsertChildFromSync(it.toChild()) }
        base.collection(WEEK_LISTS).get().await().documents.forEach { repository.upsertWeekListFromSync(it.toWeekList()) }
        base.collection(SPELLING_WORDS).get().await().documents.forEach { repository.upsertWordFromSync(it.toSpellingWord()) }
        base.collection(PRACTICE_ATTEMPTS).get().await().documents.forEach { repository.upsertAttemptFromSync(it.toPracticeAttempt()) }
        base.collection(DAILY_REWARDS).get().await().documents.forEach { repository.upsertDailyRewardFromSync(it.toDailyReward()) }
        base.collection(WEEKLY_PRIZES).get().await().documents.forEach { repository.upsertWeeklyPrizeFromSync(it.toWeeklyPrize()) }
    }

    // --- Live listeners: every remote change from here on, from any signed-in device ---

    private fun startListening(repository: SpellingRepository) {
        val base = base() ?: return
        listeners = listOf(
            base.collection(CHILDREN).addSnapshotListener { snapshot, _ ->
                snapshot?.documentChanges?.forEach { change ->
                    scope.launch {
                        if (change.type == DocumentChange.Type.REMOVED) {
                            repository.deleteChildFromSync(change.document.id)
                        } else {
                            repository.upsertChildFromSync(change.document.toChild())
                        }
                    }
                }
            },
            base.collection(WEEK_LISTS).addSnapshotListener { snapshot, _ ->
                snapshot?.documentChanges?.forEach { change ->
                    scope.launch {
                        if (change.type == DocumentChange.Type.REMOVED) {
                            repository.deleteWeekListFromSync(change.document.id)
                        } else {
                            repository.upsertWeekListFromSync(change.document.toWeekList())
                        }
                    }
                }
            },
            base.collection(SPELLING_WORDS).addSnapshotListener { snapshot, _ ->
                snapshot?.documentChanges?.forEach { change ->
                    scope.launch {
                        if (change.type == DocumentChange.Type.REMOVED) {
                            repository.deleteWordFromSync(change.document.id)
                        } else {
                            repository.upsertWordFromSync(change.document.toSpellingWord())
                        }
                    }
                }
            },
            base.collection(PRACTICE_ATTEMPTS).addSnapshotListener { snapshot, _ ->
                snapshot?.documentChanges?.forEach { change ->
                    if (change.type != DocumentChange.Type.REMOVED) {
                        scope.launch { repository.upsertAttemptFromSync(change.document.toPracticeAttempt()) }
                    }
                }
            },
            base.collection(DAILY_REWARDS).addSnapshotListener { snapshot, _ ->
                snapshot?.documentChanges?.forEach { change ->
                    scope.launch {
                        if (change.type == DocumentChange.Type.REMOVED) {
                            repository.deleteDailyRewardFromSync(change.document.id)
                        } else {
                            repository.upsertDailyRewardFromSync(change.document.toDailyReward())
                        }
                    }
                }
            },
            base.collection(WEEKLY_PRIZES).addSnapshotListener { snapshot, _ ->
                snapshot?.documentChanges?.forEach { change ->
                    scope.launch {
                        if (change.type == DocumentChange.Type.REMOVED) {
                            repository.deleteWeeklyPrizeFromSync(change.document.id)
                        } else {
                            repository.upsertWeeklyPrizeFromSync(change.document.toWeeklyPrize())
                        }
                    }
                }
            }
        )
    }
}

// --- Firestore <-> Room field mapping ---
// Manual, deliberately -- Firestore's reflection-based POJO mapping needs
// a visible no-arg constructor, which these Kotlin data classes (every
// param defaulted, but not @JvmOverloads) don't reliably expose.

private fun Child.toMap(): Map<String, Any?> = mapOf(
    "name" to name,
    "textScale" to textScale,
    "appearance" to appearance,
    "colorProfile" to colorProfile,
    "voiceIdentifier" to voiceIdentifier,
    "createdAt" to createdAt,
    "mondayInputMode" to mondayInputMode,
    "tuesdayInputMode" to tuesdayInputMode,
    "wednesdayInputMode" to wednesdayInputMode,
    "thursdayInputMode" to thursdayInputMode,
    "fridayNotificationEnabled" to fridayNotificationEnabled,
    "fridayNotificationHour" to fridayNotificationHour,
    "fridayNotificationMinute" to fridayNotificationMinute,
    "allowHintsDuringTest" to allowHintsDuringTest
)

private fun DocumentSnapshot.toChild(): Child = Child(
    id = id,
    name = getString("name").orEmpty(),
    textScale = getDouble("textScale") ?: 1.0,
    appearance = getString("appearance") ?: "system",
    colorProfile = getString("colorProfile") ?: "default",
    voiceIdentifier = getString("voiceIdentifier").orEmpty(),
    createdAt = getLong("createdAt") ?: System.currentTimeMillis(),
    mondayInputMode = getString("mondayInputMode") ?: "TILES_SCAFFOLDED",
    tuesdayInputMode = getString("tuesdayInputMode") ?: "TILES_FULL",
    wednesdayInputMode = getString("wednesdayInputMode") ?: "HALF_AND_HALF",
    thursdayInputMode = getString("thursdayInputMode") ?: "TYPED",
    fridayNotificationEnabled = getBoolean("fridayNotificationEnabled") ?: false,
    fridayNotificationHour = (getLong("fridayNotificationHour") ?: 7L).toInt(),
    fridayNotificationMinute = (getLong("fridayNotificationMinute") ?: 0L).toInt(),
    allowHintsDuringTest = getBoolean("allowHintsDuringTest") ?: false
)

private fun WeekList.toMap(): Map<String, Any?> = mapOf(
    "childId" to childId,
    "weekOf" to weekOf,
    "targetWordCount" to targetWordCount
)

private fun DocumentSnapshot.toWeekList(): WeekList = WeekList(
    id = id,
    childId = getString("childId").orEmpty(),
    weekOf = getLong("weekOf") ?: 0L,
    targetWordCount = (getLong("targetWordCount") ?: 12L).toInt()
)

private fun SpellingWord.toMap(): Map<String, Any?> = mapOf(
    "weekListId" to weekListId,
    "text" to text,
    "orderIndex" to orderIndex,
    "hint" to hint,
    "customAudioPath" to customAudioPath
)

private fun DocumentSnapshot.toSpellingWord(): SpellingWord = SpellingWord(
    id = id,
    weekListId = getString("weekListId").orEmpty(),
    text = getString("text").orEmpty(),
    orderIndex = (getLong("orderIndex") ?: 0L).toInt(),
    hint = getString("hint").orEmpty(),
    customAudioPath = getString("customAudioPath")
)

private fun PracticeAttempt.toMap(): Map<String, Any?> = mapOf(
    "wordId" to wordId,
    "date" to date,
    "isCorrect" to isCorrect,
    "mode" to mode.name,
    "sessionId" to sessionId
)

private fun DocumentSnapshot.toPracticeAttempt(): PracticeAttempt = PracticeAttempt(
    id = id,
    wordId = getString("wordId").orEmpty(),
    date = getLong("date") ?: System.currentTimeMillis(),
    isCorrect = getBoolean("isCorrect") ?: false,
    mode = runCatching { PracticeMode.valueOf(getString("mode") ?: "PRACTICE") }.getOrDefault(PracticeMode.PRACTICE),
    sessionId = getString("sessionId").orEmpty()
)

private fun DailyReward.toMap(): Map<String, Any?> = mapOf(
    "childId" to childId,
    "weekOf" to weekOf,
    "weekday" to weekday,
    "rewardText" to rewardText,
    "thresholdPercent" to thresholdPercent
)

private fun DocumentSnapshot.toDailyReward(): DailyReward = DailyReward(
    id = id,
    childId = getString("childId").orEmpty(),
    weekOf = getLong("weekOf") ?: 0L,
    weekday = (getLong("weekday") ?: 2L).toInt(),
    rewardText = getString("rewardText").orEmpty(),
    thresholdPercent = (getLong("thresholdPercent") ?: 70L).toInt()
)

private fun WeeklyPrize.toMap(): Map<String, Any?> = mapOf(
    "childId" to childId,
    "weekOf" to weekOf,
    "title" to title,
    "thresholdPercent" to thresholdPercent
)

private fun DocumentSnapshot.toWeeklyPrize(): WeeklyPrize = WeeklyPrize(
    id = id,
    childId = getString("childId").orEmpty(),
    weekOf = getLong("weekOf") ?: 0L,
    title = getString("title").orEmpty(),
    thresholdPercent = (getLong("thresholdPercent") ?: 80L).toInt()
)
