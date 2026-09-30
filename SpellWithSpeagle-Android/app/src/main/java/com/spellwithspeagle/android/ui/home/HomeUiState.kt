package com.spellwithspeagle.android.ui.home

import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.data.model.DailyReward
import com.spellwithspeagle.android.data.model.WeeklyPrize

data class DayGradeUi(
    val weekday: Int,
    val label: String,
    /** null = "No test yet." */
    val percent: Int?,
    val reward: DailyReward?,
    val rewardEarned: Boolean,
    val missedWordIds: List<String>
)

data class HomeUiState(
    val isLoading: Boolean = true,
    val child: Child? = null,
    val weekListId: String? = null,
    val dayGrades: List<DayGradeUi> = emptyList(),
    val weeklyPrize: WeeklyPrize? = null,
    val weeklyPrizeProgress: Int? = null
)
