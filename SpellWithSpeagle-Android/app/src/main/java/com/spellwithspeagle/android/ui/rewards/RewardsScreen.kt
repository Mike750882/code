package com.spellwithspeagle.android.ui.rewards

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.theme.SpellTheme

@Composable
fun RewardsScreen(
    onDone: () -> Unit,
    viewModel: RewardsViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(containerColor = SpellTheme.colors.background) { padding ->
        if (state.isLoading) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = SpellTheme.colors.primary)
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                Text("Rewards", style = SpellTheme.display(24.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
            }
            items(state.days) { day ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
                        .background(SpellTheme.colors.surface)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(day.label, style = SpellTheme.body(16.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                    OutlinedTextField(
                        value = day.text,
                        onValueChange = { viewModel.updateDayText(day.weekday, it) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        placeholder = { Text("Reward, e.g. 30 extra minutes of screen time") }
                    )
                    Text("Needs ${day.thresholdPercent}% correct", style = SpellTheme.body(13.sp), color = SpellTheme.colors.textSecondary)
                    Slider(
                        value = day.thresholdPercent.toFloat(),
                        onValueChange = { viewModel.updateDayThreshold(day.weekday, it.toInt()) },
                        valueRange = 0f..100f,
                        steps = 9,
                        colors = SliderDefaults.colors(thumbColor = SpellTheme.colors.tile, activeTrackColor = SpellTheme.colors.tile)
                    )
                }
            }
            item {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
                        .background(SpellTheme.colors.rewardFill)
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("WEEKLY PRIZE", style = SpellTheme.body(12.sp, FontWeight.Bold), color = SpellTheme.colors.rewardText)
                    OutlinedTextField(
                        value = state.weeklyTitle,
                        onValueChange = { viewModel.updateWeeklyTitle(it) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        placeholder = { Text("Prize title") }
                    )
                    Text("Needs ${state.weeklyThreshold}% correct for the week", style = SpellTheme.body(13.sp), color = SpellTheme.colors.textSecondary)
                    Slider(
                        value = state.weeklyThreshold.toFloat(),
                        onValueChange = { viewModel.updateWeeklyThreshold(it.toInt()) },
                        valueRange = 0f..100f,
                        steps = 9,
                        colors = SliderDefaults.colors(thumbColor = SpellTheme.colors.reward, activeTrackColor = SpellTheme.colors.reward)
                    )
                }
            }
            item {
                Spacer(Modifier.height(4.dp))
                Button(
                    onClick = { viewModel.save(onDone) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
                ) {
                    Text("Save rewards")
                }
            }
        }
    }
}
