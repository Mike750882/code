package com.spellwithspeagle.android.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.DailyReward
import com.spellwithspeagle.android.data.model.PracticeAttempt
import com.spellwithspeagle.android.data.model.WeeklyPrize
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.domain.WeekUtils
import com.spellwithspeagle.android.domain.latestSessionPerWeekday
import com.spellwithspeagle.android.domain.percentCorrect
import com.spellwithspeagle.android.service.ActiveChildStore
import java.util.Calendar
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn

private val WEEKDAY_LABELS = mapOf(
    Calendar.MONDAY to "Mon",
    Calendar.TUESDAY to "Tue",
    Calendar.WEDNESDAY to "Wed",
    Calendar.THURSDAY to "Thu",
    Calendar.FRIDAY to "Fri"
)

class HomeViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
) : ViewModel() {

    val uiState: StateFlow<HomeUiState> = activeChildStore.activeChildId
        .flatMapLatest { childId ->
            if (childId == null) flowOf(HomeUiState(isLoading = false)) else observeForChild(childId)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeUiState())

    private fun observeForChild(childId: String) =
        repository.observeChild(childId).flatMapLatest { child ->
            if (child == null) return@flatMapLatest flowOf(HomeUiState(isLoading = false))
            val weekOf = WeekUtils.startOfWeek()
            combine(
                repository.observeWeekList(childId, weekOf),
                repository.observeDailyRewards(childId, weekOf),
                repository.observeWeeklyPrize(childId, weekOf)
            ) { weekList, dailyRewards, weeklyPrize -> Triple(weekList, dailyRewards, weeklyPrize) }
                .flatMapLatest { (weekList, dailyRewards, weeklyPrize) ->
                    if (weekList == null) {
                        flowOf(buildState(child.id, null, emptyList(), dailyRewards, weeklyPrize))
                    } else {
                        repository.observeWords(weekList.id).flatMapLatest { words ->
                            val wordIds = words.map { it.id }
                            val attempts = if (wordIds.isEmpty()) flowOf(emptyList()) else repository.observeAttemptsForWords(wordIds)
                            attempts.map { buildState(child.id, weekList.id, it, dailyRewards, weeklyPrize) }
                        }
                    }
                }.map { it.copy(child = child) }
        }

    private fun buildState(
        childId: String,
        weekListId: String?,
        attempts: List<PracticeAttempt>,
        dailyRewards: List<DailyReward>,
        weeklyPrize: WeeklyPrize?
    ): HomeUiState {
        val collapsed = attempts.latestSessionPerWeekday()
        val dayGrades = WEEKDAY_LABELS.map { (weekday, label) ->
            val dayAttempts = collapsed.filter { WeekUtils.weekdayOf(it.date) == weekday }
            val percent = dayAttempts.percentCorrect()
            val reward = dailyRewards.firstOrNull { it.weekday == weekday }
            DayGradeUi(
                weekday = weekday,
                label = label,
                percent = percent,
                reward = reward,
                rewardEarned = reward != null && percent != null && percent >= reward.thresholdPercent,
                missedWordIds = dayAttempts.filter { !it.isCorrect }.map { it.wordId }
            )
        }
        val weeklyPercent = collapsed.percentCorrect()
        return HomeUiState(
            isLoading = false,
            weekListId = weekListId,
            dayGrades = dayGrades,
            weeklyPrize = weeklyPrize,
            weeklyPrizeProgress = weeklyPercent
        )
    }
}
