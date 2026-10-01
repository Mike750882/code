package com.spellwithspeagle.android.ui.profiles

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
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
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme

@Composable
fun ProfilesScreen(
    onAddStudent: () -> Unit,
    onProfileSwitched: () -> Unit,
    onBack: () -> Unit,
    viewModel: ProfilesViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()
    var pendingDelete by remember { mutableStateOf<Child?>(null) }

    SpeagleBackground {
    Scaffold(containerColor = Color.Transparent) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Text("Student profiles", style = SpellTheme.display(24.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
            }
            items(state.children) { child ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(SpellTheme.controlCornerRadius))
                        .background(SpellTheme.colors.surface)
                        .clickable {
                            viewModel.switchTo(child.id)
                            onProfileSwitched()
                        }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (child.id == state.activeChildId) {
                            Icon(Icons.Default.CheckCircle, contentDescription = "Active", tint = SpellTheme.colors.primary)
                        }
                        Text(child.name, color = SpellTheme.colors.textPrimary, style = SpellTheme.body(16.sp, FontWeight.Bold))
                    }
                    if (state.children.size > 1) {
                        IconButton(onClick = { pendingDelete = child }) {
                            Icon(Icons.Default.Delete, contentDescription = "Remove ${child.name}", tint = SpellTheme.colors.textSecondary)
                        }
                    }
                }
            }
            item {
                Button(
                    onClick = onAddStudent,
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
                ) {
                    Text("Add a student")
                }
            }
            item {
                TextButton(onClick = onBack) {
                    Text("Back to Settings", color = SpellTheme.colors.textSecondary)
                }
            }
        }
    }
    }

    pendingDelete?.let { child ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Remove ${child.name}?") },
            text = { Text("This permanently deletes ${child.name}'s word lists, rewards, and progress. This can't be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.delete(child)
                    pendingDelete = null
                }) {
                    Text("Remove", color = SpellTheme.colors.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("Cancel") }
            }
        )
    }
}
