package com.spellwithspeagle.android.ui.addlist

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpellTheme

@Composable
fun AddListScreen(
    onDone: () -> Unit,
    viewModel: AddListViewModel = viewModel(factory = AppViewModelProvider.Factory)
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
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Speagle(pose = SpeaglePose.POINT, size = 56.dp)
                    Text("This week's spelling list", style = SpellTheme.display(22.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                }
            }
            itemsIndexed(state.entries) { index, entry ->
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SpellTheme.controlCornerRadius))
                        .background(SpellTheme.colors.surface)
                        .padding(12.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("${index + 1}", style = SpellTheme.body(14.sp, FontWeight.Bold), color = SpellTheme.colors.textSecondary)
                        OutlinedTextField(
                            value = entry.text,
                            onValueChange = { viewModel.updateWord(index, it) },
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                            placeholder = { Text("Word") }
                        )
                        IconButton(onClick = { viewModel.removeWordSlot(index) }) {
                            Icon(Icons.Default.Delete, contentDescription = "Remove word", tint = SpellTheme.colors.textSecondary)
                        }
                    }
                    OutlinedTextField(
                        value = entry.hint,
                        onValueChange = { viewModel.updateHint(index, it) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true,
                        placeholder = { Text("Hint Speagle can give (optional)") }
                    )
                }
            }
            item {
                TextButton(onClick = { viewModel.addWordSlot() }) {
                    Text("+ Add another word", color = SpellTheme.colors.primary)
                }
            }
            item {
                Button(
                    onClick = { viewModel.save(onDone) },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
                ) {
                    Text("Save list")
                }
            }
        }
    }
}
