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
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/**
 * Single entry point the UI layer talks to instead of individual DAOs --
 * bundles the multi-table reads/writes (e.g. "this week's list, creating it
 * if it doesn't exist yet") that a ViewModel would otherwise have to
 * orchestrate by hand.
 */
class SpellingRepository(
    private val childDao: ChildDao,
    private val weekListDao: WeekListDao,
    private val spellingWordDao: SpellingWordDao,
    private val practiceAttemptDao: PracticeAttemptDao,
    private val dailyRewardDao: DailyRewardDao,
    private val weeklyPrizeDao: WeeklyPrizeDao
) {
    fun observeChildren(): Flow<List<Child>> = childDao.observeAll()
    fun observeChild(id: String): Flow<Child?> = childDao.observe(id)
    suspend fun childCount(): Int = childDao.count()

    suspend fun addChild(name: String): Child {
        val child = Child(name = name)
        childDao.upsert(child)
        return child
    }

    suspend fun updateChild(child: Child) = childDao.update(child)
    suspend fun deleteChild(child: Child) = childDao.delete(child)

    fun observeWeekList(childId: String, weekOf: Long = WeekUtils.startOfWeek()): Flow<WeekList?> =
        weekListDao.observeForWeek(childId, weekOf)

    fun observeWeekLists(childId: String): Flow<List<WeekList>> = weekListDao.observeForChild(childId)

    fun observeWords(weekListId: String): Flow<List<SpellingWord>> = spellingWordDao.observeForWeek(weekListId)

    suspend fun getOrCreateCurrentWeekList(childId: String): WeekList {
        val weekOf = WeekUtils.startOfWeek()
        return weekListDao.findForWeek(childId, weekOf) ?: WeekList(childId = childId, weekOf = weekOf).also {
            weekListDao.upsert(it)
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
        if (toDelete.isNotEmpty()) spellingWordDao.deleteByIds(toDelete)

        val upserts = entries.mapIndexed { index, (text, hint) ->
            val current = existing.getOrNull(index)
            if (current != null) {
                current.copy(text = text, hint = hint)
            } else {
                SpellingWord(weekListId = weekListId, text = text, orderIndex = index, hint = hint)
            }
        }
        spellingWordDao.upsertAll(upserts)
    }

    fun observeAttemptsForWords(wordIds: List<String>): Flow<List<PracticeAttempt>> =
        practiceAttemptDao.observeForWords(wordIds)

    suspend fun recordAttempts(attempts: List<PracticeAttempt>) = practiceAttemptDao.insertAll(attempts)

    fun newSessionId(): String = UUID.randomUUID().toString()

    fun observeDailyRewards(childId: String, weekOf: Long = WeekUtils.startOfWeek()): Flow<List<DailyReward>> =
        dailyRewardDao.observeForWeek(childId, weekOf)

    suspend fun setDailyReward(reward: DailyReward) = dailyRewardDao.upsert(reward)

    fun observeWeeklyPrize(childId: String, weekOf: Long = WeekUtils.startOfWeek()): Flow<WeeklyPrize?> =
        weeklyPrizeDao.observeForWeek(childId, weekOf)

    suspend fun setWeeklyPrize(prize: WeeklyPrize) = weeklyPrizeDao.upsert(prize)

    suspend fun wordsForCurrentWeek(childId: String): List<SpellingWord> {
        val weekList = getOrCreateCurrentWeekList(childId)
        return spellingWordDao.getForWeek(weekList.id)
    }

    suspend fun attemptsForWords(wordIds: List<String>): List<PracticeAttempt> =
        practiceAttemptDao.getForWords(wordIds)
}
