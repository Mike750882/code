package com.spellwithspeagle.android.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.domain.Grading
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpellTheme

enum class PracticeOrTest { PRACTICE, TEST }

@Composable
fun HomeScreen(
    onStartSession: (mode: PracticeOrTest, restrictToWordIds: List<String>?) -> Unit,
    viewModel: HomeViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()
    var mode by remember { mutableStateOf(PracticeOrTest.PRACTICE) }
    var rewardDialog by remember { mutableStateOf<DayGradeUi?>(null) }

    Scaffold(containerColor = SpellTheme.colors.background) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Speagle(pose = SpeaglePose.WAVE, size = 56.dp)
                Column {
                    Text(
                        text = "Hi, ${state.child?.name?.ifBlank { "friend" } ?: "friend"}!",
                        style = SpellTheme.display(28.sp, FontWeight.Bold),
                        color = SpellTheme.colors.textPrimary
                    )
                    Text(
                        text = "Ready to spell today?",
                        style = SpellTheme.body(15.sp),
                        color = SpellTheme.colors.textSecondary
                    )
                }
            }

            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                SegmentedButton(
                    selected = mode == PracticeOrTest.PRACTICE,
                    onClick = { mode = PracticeOrTest.PRACTICE },
                    shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2)
                ) { Text("Practice") }
                SegmentedButton(
                    selected = mode == PracticeOrTest.TEST,
                    onClick = { mode = PracticeOrTest.TEST },
                    shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2)
                ) { Text("Test") }
            }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
                    .background(SpellTheme.colors.action)
                    .clickable { onStartSession(mode, null) }
                    .padding(28.dp)
            ) {
                Column {
                    Text(
                        text = if (mode == PracticeOrTest.PRACTICE) "Practice spelling list" else "Take spelling test",
                        style = SpellTheme.display(24.sp, FontWeight.Bold),
                        color = androidx.compose.ui.graphics.Color.White
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Tap to start",
                        style = SpellTheme.body(14.sp),
                        color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.85f)
                    )
                }
            }

            Text("This week", style = SpellTheme.display(18.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(vertical = 4.dp)) {
                items(state.dayGrades) { day ->
                    DayGradeCard(
                        day = day,
                        onClick = {
                            if (day.missedWordIds.isNotEmpty()) onStartSession(PracticeOrTest.PRACTICE, day.missedWordIds)
                        },
                        onBadgeClick = { rewardDialog = day }
                    )
                }
            }

            state.weeklyPrize?.let { prize ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
                        .background(SpellTheme.colors.rewardFill)
                        .padding(16.dp)
                ) {
                    Text("WEEKLY PRIZE", style = SpellTheme.body(12.sp, FontWeight.Bold), color = SpellTheme.colors.rewardText)
                    Text(prize.title, style = SpellTheme.display(18.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                    Spacer(Modifier.height(8.dp))
                    LinearProgressIndicator(
                        progress = { (state.weeklyPrizeProgress ?: 0) / 100f },
                        modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
                        color = SpellTheme.colors.reward
                    )
                }
            }
        }
    }

    rewardDialog?.let { day ->
        AlertDialog(
            onDismissRequest = { rewardDialog = null },
            confirmButton = {
                Button(onClick = { rewardDialog = null }, colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)) {
                    Text("Got it")
                }
            },
            title = { Text("Reward Earned!") },
            text = { Text(day.reward?.rewardText.orEmpty()) }
        )
    }
}

@Composable
private fun DayGradeCard(day: DayGradeUi, onClick: () -> Unit, onBadgeClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(110.dp)
            .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
            .background(SpellTheme.colors.surface)
            .clickable(enabled = day.missedWordIds.isNotEmpty()) { onClick() }
            .padding(12.dp)
    ) {
        Column(verticalArrangement = Arrangement.Center, modifier = Modifier.fillMaxSize()) {
            Text(day.label, style = SpellTheme.body(13.sp, FontWeight.Bold), color = SpellTheme.colors.textSecondary)
            Spacer(Modifier.height(4.dp))
            if (day.percent != null) {
                Text(Grading.letter(day.percent), style = SpellTheme.display(22.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                Text("${day.percent}%", style = SpellTheme.body(12.sp), color = SpellTheme.colors.textSecondary)
            } else {
                Text("No test yet", style = SpellTheme.body(12.sp), color = SpellTheme.colors.textSecondary)
            }
            if (day.missedWordIds.isNotEmpty()) {
                Text("Retake ${day.missedWordIds.size} missed", style = SpellTheme.body(11.sp), color = SpellTheme.colors.action)
            }
        }
        if (day.rewardEarned) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .clip(RoundedCornerShape(50))
                    .background(SpellTheme.colors.reward)
                    .clickable { onBadgeClick() }
                    .padding(horizontal = 6.dp, vertical = 3.dp)
            ) {
                Text("★", color = androidx.compose.ui.graphics.Color.Black, style = SpellTheme.body(10.sp))
            }
        }
    }
}
