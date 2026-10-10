package com.spellwithspeagle.android.ui.profiles

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme

/** First-ever launch (zero children): no PIN gate, nothing to protect yet. */
@Composable
fun AddChildScreen(
    onChildAdded: () -> Unit,
    viewModel: AddChildViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    var name by remember { mutableStateOf("") }

    SpeagleBackground {
    Scaffold(containerColor = androidx.compose.ui.graphics.Color.Transparent) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .imePadding()
                .padding(32.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Speagle(pose = SpeaglePose.WAVE, size = 140.dp)
            Text(
                text = "Hi friends, I'm Speagle the eagle. I'm here to help you learn.",
                style = SpellTheme.display(20.sp, FontWeight.Bold),
                color = SpellTheme.colors.textPrimary
            )
            Text("What's your name?", style = SpellTheme.body(16.sp), color = SpellTheme.colors.textSecondary)
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true
            )
            Button(
                onClick = { if (name.isNotBlank()) viewModel.addChild(name.trim(), onChildAdded) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary),
                enabled = name.isNotBlank()
            ) {
                Text("Let's go!")
            }
        }
    }
    }
}
