package com.spellwithspeagle.android.ui.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.domain.Grading
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpellTheme

@Composable
fun PracticeScreen(
    onGoHome: () -> Unit,
    viewModel: PracticeViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()

    Scaffold(containerColor = SpellTheme.colors.background) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = SpellTheme.colors.primary)
                state.words.isEmpty() -> EmptyWordsMessage(onGoHome)
                state.isSessionComplete -> PracticeResults(state = state, onGoHome = onGoHome)
                else -> PracticeBody(state = state, viewModel = viewModel, onGoHome = onGoHome)
            }
        }
    }
}

@Composable
private fun EmptyWordsMessage(onGoHome: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Speagle(pose = SpeaglePose.THINK, size = 120.dp)
        Text("No words yet!", style = SpellTheme.display(22.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
        Text("Ask a grown-up to add this week's spelling list.", style = SpellTheme.body(15.sp), color = SpellTheme.colors.textSecondary)
        Button(onClick = onGoHome, colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)) {
            Text("Back to Home")
        }
    }
}

@Composable
private fun PracticeBody(state: PracticeUiState, viewModel: PracticeViewModel, onGoHome: () -> Unit) {
    val word = state.currentWord ?: return
    Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            IconButton(onClick = onGoHome) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Home", tint = SpellTheme.colors.textPrimary)
            }
            Text(state.progressLabel, style = SpellTheme.body(14.sp), color = SpellTheme.colors.textSecondary)
        }

        Spacer(Modifier.height(24.dp))

        Column(
            modifier = Modifier.fillMaxWidth().weight(1f),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Speagle(pose = SpeaglePose.THINK, size = 100.dp)
            Spacer(Modifier.height(16.dp))

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { viewModel.speakCurrentWord() },
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.tile)
                ) {
                    Icon(Icons.Default.VolumeUp, contentDescription = null, tint = Color.White)
                    Spacer(Modifier.width(8.dp))
                    Text("Tap to hear the word", color = Color.White)
                }
            }

            if (state.hintAvailable) {
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = { viewModel.speakHint() },
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.reward)
                ) {
                    Icon(Icons.Default.Lightbulb, contentDescription = null, tint = Color.Black)
                    Spacer(Modifier.width(8.dp))
                    Text("Hear a hint", color = Color.Black)
                }
            }

            Spacer(Modifier.height(28.dp))

            OutlinedTextField(
                value = state.typedAnswer,
                onValueChange = viewModel::onAnswerChanged,
                singleLine = true,
                textStyle = SpellTheme.display(24.sp, FontWeight.Bold),
                modifier = Modifier.fillMaxWidth()
            )

            state.feedback?.let { feedback ->
                Spacer(Modifier.height(12.dp))
                val (icon, color, label) = when (feedback) {
                    CheckFeedback.CORRECT -> Triple(Icons.Default.Check, SpellTheme.colors.success, "Correct!")
                    CheckFeedback.INCORRECT -> Triple(Icons.Default.Close, SpellTheme.colors.error, "Try again")
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(icon, contentDescription = null, tint = color)
                    Text(label, color = color, style = SpellTheme.body(16.sp, FontWeight.Bold))
                }
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
            if (state.mode == PracticeMode.PRACTICE) {
                Button(
                    onClick = { viewModel.skipWord() },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.surface)
                ) {
                    Text("Skip word", color = SpellTheme.colors.textSecondary)
                }
            }
            Button(
                onClick = { viewModel.checkAnswer() },
                modifier = Modifier.weight(1f),
                enabled = state.typedAnswer.isNotBlank() && state.feedback == null,
                colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.action)
            ) {
                Text("Check my word", color = Color.White)
            }
        }
    }
}

@Composable
private fun PracticeResults(state: PracticeUiState, onGoHome: () -> Unit) {
    val total = state.results.size
    val correct = state.results.count { it.isCorrect }
    val percent = if (total == 0) 0 else (correct * 100) / total

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Speagle(pose = if (percent >= 90) SpeaglePose.CHEER else SpeaglePose.THINK, size = 120.dp)
                Text(Grading.letter(percent), style = SpellTheme.display(48.sp, FontWeight.Bold), color = SpellTheme.colors.primary)
                Text("$percent% -- $correct of $total correct", style = SpellTheme.body(16.sp), color = SpellTheme.colors.textSecondary)
            }
            Spacer(Modifier.height(12.dp))
        }
        items(state.results) { result ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(SpellTheme.controlCornerRadius))
                    .background(SpellTheme.colors.surface)
                    .padding(14.dp),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(result.word.text, style = SpellTheme.body(16.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                    if (!result.isCorrect) {
                        Text("You wrote: ${result.typed}", style = SpellTheme.body(13.sp), color = SpellTheme.colors.textSecondary)
                    }
                }
                Icon(
                    imageVector = if (result.isCorrect) Icons.Default.Check else Icons.Default.Close,
                    contentDescription = null,
                    tint = if (result.isCorrect) SpellTheme.colors.success else SpellTheme.colors.error
                )
            }
        }
        item {
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = onGoHome,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
            ) {
                Text("Back to Home")
            }
        }
    }
}
