package com.spellwithspeagle.android.data.repository

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
import com.spellwithspeagle.android.domain.WeekUtils
import com.spellwithspeagle.android.service.SyncService
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/**
 * Single entry point the UI layer talks to instead of individual DAOs --
 * bundles the multi-table reads/writes (e.g. "this week's list, creating it
 * if it doesn't exist yet") that a ViewModel would otherwise have to
 * orchestrate by hand. Every write also pushes to [syncService], which is a
 * no-op while signed out -- so this repository never needs to check
 * sign-in state itself.
 */
class SpellingRepository(
    private val childDao: ChildDao,
    private val weekListDao: WeekListDao,
    private val spellingWordDao: SpellingWordDao,
    private val practiceAttemptDao: PracticeAttemptDao,
    private val dailyRewardDao: DailyRewardDao,
    private val weeklyPrizeDao: WeeklyPrizeDao,
    private val syncService: SyncService
) {
    fun observeChildren(): Flow<List<Child>> = childDao.observeAll()
    fun observeChild(id: String): Flow<Child?> = childDao.observe(id)
    suspend fun childCount(): Int = childDao.count()

    suspend fun addChild(name: String): Child {
        val child = Child(name = name)
        childDao.upsert(child)
        syncService.pushChild(child)
        return child
    }

    suspend fun updateChild(child: Child) {
        childDao.update(child)
        syncService.pushChild(child)
    }

    suspend fun deleteChild(child: Child) {
        childDao.delete(child)
        syncService.pushDeleteChild(child.id)
    }

    fun observeWeekList(childId: String, weekOf: Long = WeekUtils.startOfWeek()): Flow<WeekList?> =
        weekListDao.observeForWeek(childId, weekOf)

    fun observeWeekLists(childId: String): Flow<List<WeekList>> = weekListDao.observeForChild(childId)

    fun observeWords(weekListId: String): Flow<List<SpellingWord>> = spellingWordDao.observeForWeek(weekListId)

    suspend fun getOrCreateCurrentWeekList(childId: String): WeekList {
        val weekOf = WeekUtils.startOfWeek()
        return weekListDao.findForWeek(childId, weekOf) ?: WeekList(childId = childId, weekOf = weekOf).also {
            weekListDao.upsert(it)
            syncService.pushWeekList(it)
        }
    }

    /**
     * Matches word slots by order index rather than replacing every word,
     * so an untouched word keeps its identity (and test history) -- see
     * iOS's `saveList()` fix for why this matters mid-week.
     */
    suspend fun saveWords(weekListId: String, entries: List<Pair<String, String>>) {
        val existing = spellingWordDao.getForWeek(weekListId)
        val toDelete = existing.drop(entries.size).map { it.id }
        if (toDelete.isNotEmpty()) {
            spellingWordDao.deleteByIds(toDelete)
            syncService.pushDeleteWords(toDelete)
        }

        val upserts = entries.mapIndexed { index, (text, hint) ->
            val current = existing.getOrNull(index)
            if (current != null) {
                current.copy(text = text, hint = hint)
            } else {
                SpellingWord(weekListId = weekListId, text = text, orderIndex = index, hint = hint)
            }
        }
        spellingWordDao.upsertAll(upserts)
        upserts.forEach { syncService.pushWord(it) }
    }

    fun observeAttemptsForWords(wordIds: List<String>): Flow<List<PracticeAttempt>> =
        practiceAttemptDao.observeForWords(wordIds)

    suspend fun recordAttempts(attempts: List<PracticeAttempt>) {
        practiceAttemptDao.insertAll(attempts)
        syncService.pushAttempts(attempts)
    }

    fun newSessionId(): String = UUID.randomUUID().toString()

    fun observeDailyRewards(childId: String, weekOf: Long = WeekUtils.startOfWeek()): Flow<List<DailyReward>> =
        dailyRewardDao.observeForWeek(childId, weekOf)

    suspend fun setDailyReward(reward: DailyReward) {
        dailyRewardDao.upsert(reward)
        syncService.pushDailyReward(reward)
    }

    fun observeWeeklyPrize(childId: String, weekOf: Long = WeekUtils.startOfWeek()): Flow<WeeklyPrize?> =
        weeklyPrizeDao.observeForWeek(childId, weekOf)

    suspend fun setWeeklyPrize(prize: WeeklyPrize) {
        weeklyPrizeDao.upsert(prize)
        syncService.pushWeeklyPrize(prize)
    }

    suspend fun wordsForCurrentWeek(childId: String): List<SpellingWord> {
        val weekList = getOrCreateCurrentWeekList(childId)
        return spellingWordDao.getForWeek(weekList.id)
    }

    suspend fun attemptsForWords(wordIds: List<String>): List<PracticeAttempt> =
        practiceAttemptDao.getForWords(wordIds)

    // --- Cross-device sync support ---
    // Raw upserts/deletes with none of the above methods' extra business
    // logic (order-index matching, auto-creating a week list, etc.) --
    // [com.spellwithspeagle.android.service.SyncService] uses these to
    // mirror a remote Firestore change into Room exactly as given, the
    // same way Room's own REPLACE conflict strategy makes a local write
    // idempotent no matter how many times it's applied.
    suspend fun upsertChildFromSync(child: Child) = childDao.upsert(child)
    suspend fun deleteChildFromSync(id: String) = childDao.deleteById(id)
    suspend fun upsertWeekListFromSync(weekList: WeekList) = weekListDao.upsert(weekList)
    suspend fun deleteWeekListFromSync(id: String) = weekListDao.deleteById(id)
    suspend fun upsertWordFromSync(word: SpellingWord) = spellingWordDao.upsertAll(listOf(word))
    suspend fun deleteWordFromSync(id: String) = spellingWordDao.deleteByIds(listOf(id))
    suspend fun upsertAttemptFromSync(attempt: PracticeAttempt) = practiceAttemptDao.upsert(attempt)
    suspend fun upsertDailyRewardFromSync(reward: DailyReward) = dailyRewardDao.upsert(reward)
    suspend fun deleteDailyRewardFromSync(id: String) = dailyRewardDao.deleteById(id)
    suspend fun upsertWeeklyPrizeFromSync(prize: WeeklyPrize) = weeklyPrizeDao.upsert(prize)
    suspend fun deleteWeeklyPrizeFromSync(id: String) = weeklyPrizeDao.deleteById(id)
}
