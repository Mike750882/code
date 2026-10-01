package com.spellwithspeagle.android.ui.progress

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun ProgressReportScreen(
    onBack: () -> Unit,
    viewModel: ProgressReportViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()
    var expandedIds by remember { mutableStateOf(setOf<String>()) }

    SpeagleBackground {
    Scaffold(containerColor = Color.Transparent) { padding ->
        if (state.isLoading) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = SpellTheme.colors.primary)
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text("Progress report", style = SpellTheme.display(24.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
            }
            if (state.weeks.isEmpty()) {
                item {
                    Text("No weeks recorded yet.", color = SpellTheme.colors.textSecondary, style = SpellTheme.body(15.sp))
                }
            }
            items(state.weeks) { row ->
                val expanded = row.weekList.id in expandedIds
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SpellTheme.cardCornerRadius))
                        .background(SpellTheme.colors.surface)
                        .clickable {
                            expandedIds = if (expanded) expandedIds - row.weekList.id else expandedIds + row.weekList.id
                        }
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                        Column {
                            Text("Week of ${formatWeek(row.weekList.weekOf)}", style = SpellTheme.body(16.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                            Text("${row.correct} of ${row.total} correct", style = SpellTheme.body(13.sp), color = SpellTheme.colors.textSecondary)
                        }
                        Icon(
                            imageVector = if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                            contentDescription = if (expanded) "Collapse" else "Expand",
                            tint = SpellTheme.colors.textSecondary
                        )
                    }
                    if (expanded) {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            row.words.forEach { breakdown ->
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    when (breakdown.status) {
                                        WordStatus.CORRECT -> Icon(Icons.Default.Check, contentDescription = "Correct", tint = SpellTheme.colors.success)
                                        WordStatus.INCORRECT -> Icon(Icons.Default.Close, contentDescription = "Incorrect", tint = SpellTheme.colors.error)
                                        WordStatus.NEVER_ATTEMPTED -> Text("--", color = SpellTheme.colors.textSecondary)
                                    }
                                    Text(breakdown.word.text, color = SpellTheme.colors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
            item {
                Spacer(Modifier.height(4.dp))
                Button(
                    onClick = onBack,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
                ) {
                    Text("Back to Settings")
                }
            }
        }
    }
    }
}

private fun formatWeek(weekOf: Long): String =
    SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(weekOf))
