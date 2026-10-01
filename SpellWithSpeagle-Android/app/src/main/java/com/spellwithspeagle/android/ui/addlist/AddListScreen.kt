package com.spellwithspeagle.android.ui.addlist

import android.Manifest
import android.content.Context
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.service.TextRecognitionService
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme
import kotlinx.coroutines.launch

@Composable
fun AddListScreen(
    onDone: () -> Unit,
    viewModel: AddListViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()
    var showSpellCheckDialog by remember { mutableStateOf(false) }
    var isImporting by remember { mutableStateOf(false) }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val textRecognitionService = remember { TextRecognitionService() }

    fun handleBitmap(bitmap: Bitmap?) {
        if (bitmap == null) return
        isImporting = true
        scope.launch {
            val words = textRecognitionService.recognizeWords(bitmap)
            viewModel.importWords(words)
            isImporting = false
        }
    }

    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        handleBitmap(bitmap)
    }
    val cameraPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) cameraLauncher.launch(null)
    }
    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) handleBitmap(loadBitmap(context, uri))
    }

    SpeagleBackground {
    Scaffold(containerColor = androidx.compose.ui.graphics.Color.Transparent) { padding ->
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
            item {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    Button(
                        onClick = { cameraPermissionLauncher.launch(Manifest.permission.CAMERA) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.tile)
                    ) {
                        Text("Take Photo")
                    }
                    Button(
                        onClick = { galleryLauncher.launch("image/*") },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.tile)
                    ) {
                        Text("Choose from Library")
                    }
                }
                if (isImporting) {
                    Text("Reading the photo...", style = SpellTheme.body(13.sp), color = SpellTheme.colors.textSecondary)
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
                            isError = entry.isMisspelled,
                            placeholder = { Text("Word") }
                        )
                        if (entry.isMisspelled) {
                            Icon(Icons.Default.Warning, contentDescription = "Not in dictionary -- double check this word", tint = SpellTheme.colors.error)
                        }
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
                    onClick = {
                        if (viewModel.hasMisspellings()) showSpellCheckDialog = true else viewModel.save(onDone)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
                ) {
                    Text("Save list")
                }
            }
        }
    }
    }

    if (showSpellCheckDialog) {
        AlertDialog(
            onDismissRequest = { showSpellCheckDialog = false },
            title = { Text("Double check these words") },
            text = {
                Text("Some words aren't in the dictionary. That's often fine -- names and uncommon words always get flagged -- just make sure they're spelled the way you want.")
            },
            confirmButton = {
                TextButton(onClick = {
                    showSpellCheckDialog = false
                    viewModel.save(onDone)
                }) {
                    Text("Save anyway")
                }
            },
            dismissButton = {
                TextButton(onClick = { showSpellCheckDialog = false }) { Text("Review words") }
            }
        )
    }
}

private fun loadBitmap(context: Context, uri: Uri): Bitmap? = runCatching {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri))
    } else {
        @Suppress("DEPRECATION")
        MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
    }
}.getOrNull()
