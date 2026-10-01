package com.spellwithspeagle.android.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.data.model.WordInputMode
import com.spellwithspeagle.android.service.SpeechService
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.theme.ColorProfile
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

private val SCHEDULE_DAYS = listOf(
    Calendar.MONDAY to "Monday",
    Calendar.TUESDAY to "Tuesday",
    Calendar.WEDNESDAY to "Wednesday",
    Calendar.THURSDAY to "Thursday"
)

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun SettingsScreen(
    onChangePin: () -> Unit,
    onBack: () -> Unit,
    viewModel: SettingsViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()
    val child = state.child

    SpeagleBackground {
    Scaffold(containerColor = Color.Transparent) { padding ->
        if (state.isLoading || child == null) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = SpellTheme.colors.primary)
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            item {
                Text("Settings", style = SpellTheme.display(24.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
            }

            item {
                SettingsSection(title = "Color theme") {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        ColorProfile.all.forEach { profile ->
                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(CircleShape)
                                    .background(profile.swatchColor)
                                    .border(
                                        width = if (child.colorProfile == profile.id) 3.dp else 0.dp,
                                        color = SpellTheme.colors.textPrimary,
                                        shape = CircleShape
                                    )
                                    .clickable { viewModel.setColorProfile(profile.id) }
                            )
                        }
                    }
                }
            }

            item {
                SettingsSection(title = "Voice") {
                    if (state.voices.isEmpty()) {
                        Text(
                            "No extra voices found on this device -- using the system default. " +
                                "More can be installed from Settings -> Languages & input -> Text-to-speech output.",
                            color = SpellTheme.colors.textSecondary,
                            style = SpellTheme.body(13.sp)
                        )
                    } else {
                        VoiceDropdown(
                            voices = state.voices,
                            selectedId = child.voiceIdentifier,
                            onSelect = viewModel::setVoice
                        )
                    }
                    Button(
                        onClick = { viewModel.previewVoice(child.voiceIdentifier) },
                        colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.tile)
                    ) {
                        Text("Preview", color = Color.White)
                    }
                }
            }

            item {
                SettingsSection(title = "Practice schedule") {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        SCHEDULE_DAYS.forEach { (weekday, label) ->
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(label, style = SpellTheme.body(14.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                                FlowRow(
                                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                                    verticalArrangement = Arrangement.spacedBy(6.dp),
                                    maxItemsInEachRow = 2
                                ) {
                                    WordInputMode.entries.forEach { mode ->
                                        val selected = WordInputMode.forWeekday(weekday, child) == mode
                                        FilterChip(
                                            selected = selected,
                                            onClick = { viewModel.setInputMode(weekday, mode) },
                                            label = { Text(mode.shortLabel) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            item {
                SettingsSection(title = "Test options") {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                        Text("Hints during Test", color = SpellTheme.colors.textPrimary)
                        Switch(checked = child.allowHintsDuringTest, onCheckedChange = { viewModel.setAllowHintsDuringTest(it) })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                        Text("Friday test reminder", color = SpellTheme.colors.textPrimary)
                        Switch(checked = child.fridayNotificationEnabled, onCheckedChange = { viewModel.setFridayReminder(it) })
                    }
                }
            }

            item {
                SettingsSection(title = "Progress") {
                    if (state.weeksSummary.isEmpty()) {
                        Text("No practice recorded yet.", color = SpellTheme.colors.textSecondary, style = SpellTheme.body(13.sp))
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            state.weeksSummary.forEach { week ->
                                val percent = if (week.total == 0) 0 else (week.correct * 100) / week.total
                                Text(
                                    "Week of ${formatWeek(week.weekOf)}: $percent% (${week.correct}/${week.total})",
                                    color = SpellTheme.colors.textSecondary,
                                    style = SpellTheme.body(13.sp)
                                )
                            }
                        }
                    }
                }
            }

            item {
                Button(
                    onClick = onChangePin,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
                ) {
                    Text("Change PIN")
                }
            }
            item {
                TextButton(onClick = onBack) {
                    Text("Back to Home", color = SpellTheme.colors.textSecondary)
                }
            }
        }
    }
    }
}

@Composable
private fun VoiceDropdown(
    voices: List<SpeechService.VoiceOption>,
    selectedId: String,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = voices.firstOrNull { it.id == selectedId }?.label ?: "Choose a voice"

    Box(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(SpellTheme.controlCornerRadius))
                .border(1.dp, SpellTheme.colors.hairline, RoundedCornerShape(SpellTheme.controlCornerRadius))
                .clickable { expanded = true }
                .padding(horizontal = 16.dp, vertical = 14.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(selectedLabel, color = SpellTheme.colors.textPrimary)
            Icon(Icons.Default.ArrowDropDown, contentDescription = "Choose a voice", tint = SpellTheme.colors.textSecondary)
        }
        // DropdownMenu scrolls internally on its own once its content is
        // taller than fits, so this stays compact however many voices are
        // offered instead of pushing the rest of Settings off-screen.
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            voices.forEach { voice ->
                DropdownMenuItem(
                    text = { Text(voice.label) },
                    onClick = {
                        onSelect(voice.id)
                        expanded = false
                    }
                )
            }
        }
    }
}

@Composable
private fun SettingsSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
            .background(SpellTheme.colors.surface)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text(title, style = SpellTheme.body(13.sp, FontWeight.Bold), color = SpellTheme.colors.textSecondary)
        content()
    }
}

private fun formatWeek(weekOf: Long): String =
    SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(weekOf))
