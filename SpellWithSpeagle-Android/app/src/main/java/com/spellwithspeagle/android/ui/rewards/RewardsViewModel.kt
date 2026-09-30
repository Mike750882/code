package com.spellwithspeagle.android.ui.rewards

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.spellwithspeagle.android.data.model.DailyReward
import com.spellwithspeagle.android.data.model.WeeklyPrize
import com.spellwithspeagle.android.data.repository.SpellingRepository
import com.spellwithspeagle.android.domain.WeekUtils
import com.spellwithspeagle.android.service.ActiveChildStore
import java.util.Calendar
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class DailyRewardRow(
    /** Null until this weekday has an existing row to reuse the id of -- keeps a save from inserting a duplicate. */
    val id: String?,
    val weekday: Int,
    val label: String,
    val text: String,
    val thresholdPercent: Int
)

data class RewardsUiState(
    val isLoading: Boolean = true,
    val days: List<DailyRewardRow> = emptyList(),
    val weeklyPrizeId: String? = null,
    val weeklyTitle: String = "",
    val weeklyThreshold: Int = 80
)

private val WEEKDAY_LABELS = listOf(
    Calendar.MONDAY to "Monday",
    Calendar.TUESDAY to "Tuesday",
    Calendar.WEDNESDAY to "Wednesday",
    Calendar.THURSDAY to "Thursday"
)

class RewardsViewModel(
    private val repository: SpellingRepository,
    private val activeChildStore: ActiveChildStore
) : ViewModel() {
    private val _uiState = MutableStateFlow(RewardsUiState())
    val uiState: StateFlow<RewardsUiState> = _uiState.asStateFlow()

    private var childId: String? = null
    private val weekOf = WeekUtils.startOfWeek()

    init {
        viewModelScope.launch {
            val id = activeChildStore.activeChildId.first() ?: return@launch
            childId = id
            val dailyRewards = repository.observeDailyRewards(id, weekOf).first()
            val weeklyPrize = repository.observeWeeklyPrize(id, weekOf).first()
            val days = WEEKDAY_LABELS.map { (weekday, label) ->
                val existing = dailyRewards.firstOrNull { it.weekday == weekday }
                DailyRewardRow(
                    id = existing?.id,
                    weekday = weekday,
                    label = label,
                    text = existing?.rewardText.orEmpty(),
                    thresholdPercent = existing?.thresholdPercent ?: 70
                )
            }
            _uiState.value = RewardsUiState(
                isLoading = false,
                days = days,
                weeklyPrizeId = weeklyPrize?.id,
                weeklyTitle = weeklyPrize?.title.orEmpty(),
                weeklyThreshold = weeklyPrize?.thresholdPercent ?: 80
            )
        }
    }

    fun updateDayText(weekday: Int, text: String) = updateDay(weekday) { it.copy(text = text) }
    fun updateDayThreshold(weekday: Int, threshold: Int) = updateDay(weekday) { it.copy(thresholdPercent = threshold) }

    private fun updateDay(weekday: Int, transform: (DailyRewardRow) -> DailyRewardRow) {
        _uiState.value = _uiState.value.copy(
            days = _uiState.value.days.map { if (it.weekday == weekday) transform(it) else it }
        )
    }

    fun updateWeeklyTitle(title: String) {
        _uiState.value = _uiState.value.copy(weeklyTitle = title)
    }

    fun updateWeeklyThreshold(threshold: Int) {
        _uiState.value = _uiState.value.copy(weeklyThreshold = threshold)
    }

    fun save(onDone: () -> Unit) {
        val id = childId ?: return
        val state = _uiState.value
        viewModelScope.launch {
            state.days.forEach { row ->
                repository.setDailyReward(
                    DailyReward(
                        id = row.id ?: UUID.randomUUID().toString(),
                        childId = id,
                        weekOf = weekOf,
                        weekday = row.weekday,
                        rewardText = row.text,
                        thresholdPercent = row.thresholdPercent
                    )
                )
            }
            repository.setWeeklyPrize(
                WeeklyPrize(
                    id = state.weeklyPrizeId ?: UUID.randomUUID().toString(),
                    childId = id,
                    weekOf = weekOf,
                    title = state.weeklyTitle,
                    thresholdPercent = state.weeklyThreshold
                )
            )
            onDone()
        }
    }
}
