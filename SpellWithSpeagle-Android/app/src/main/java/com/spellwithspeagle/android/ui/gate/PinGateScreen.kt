package com.spellwithspeagle.android.ui.gate

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.font.FontWeight
import com.spellwithspeagle.android.SpellWithSpeagleApp
import com.spellwithspeagle.android.ui.components.PinDots
import com.spellwithspeagle.android.ui.components.PinPad
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme

/** Where a successful PIN check should go. CHANGE_PIN always forces the create/confirm flow, even if a PIN already exists. */
enum class GateDestination { ADD_LIST, REWARDS, SETTINGS, CHANGE_PIN }

private enum class Mode { VERIFY, CREATE }
private enum class Stage { ENTER, CONFIRM }

/**
 * Every gated screen is checked fresh on every visit -- unlocking one never
 * carries over to another or to a later visit, matching iOS's
 * `ParentGate.verify` called fresh each time. The very first visit (no PIN
 * set yet) goes straight into the create flow instead of failing a check
 * against nothing -- there's nothing to protect yet.
 */
@Composable
fun PinGateScreen(
    destination: GateDestination,
    onSuccess: (GateDestination) -> Unit,
    onCancel: () -> Unit
) {
    val context = LocalContext.current
    val pinService = remember { (context.applicationContext as SpellWithSpeagleApp).pinService }

    var mode by remember { mutableStateOf(if (destination == GateDestination.CHANGE_PIN || !pinService.hasPin()) Mode.CREATE else Mode.VERIFY) }
    var stage by remember { mutableStateOf(Stage.ENTER) }
    var firstPin by remember { mutableStateOf("") }
    var digits by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    fun onDigit(digit: Char) {
        if (digits.length >= 4) return
        digits += digit
        if (digits.length < 4) return

        when (mode) {
            Mode.VERIFY -> {
                if (pinService.verify(digits)) {
                    onSuccess(destination)
                } else {
                    error = "Wrong PIN, try again"
                    digits = ""
                }
            }
            Mode.CREATE -> when (stage) {
                Stage.ENTER -> {
                    firstPin = digits
                    digits = ""
                    error = null
                    stage = Stage.CONFIRM
                }
                Stage.CONFIRM -> {
                    if (digits == firstPin) {
                        pinService.setPin(digits)
                        onSuccess(destination)
                    } else {
                        error = "PINs didn't match -- try again"
                        digits = ""
                        firstPin = ""
                        stage = Stage.ENTER
                    }
                }
            }
        }
    }

    val title = when {
        mode == Mode.CREATE && destination == GateDestination.CHANGE_PIN && stage == Stage.ENTER -> "Set a new PIN"
        mode == Mode.CREATE && destination == GateDestination.CHANGE_PIN && stage == Stage.CONFIRM -> "Confirm your new PIN"
        mode == Mode.CREATE && stage == Stage.ENTER -> "Grown-ups: set a PIN"
        mode == Mode.CREATE && stage == Stage.CONFIRM -> "Confirm your PIN"
        else -> "Enter parent PIN"
    }

    SpeagleBackground {
    Scaffold(containerColor = androidx.compose.ui.graphics.Color.Transparent) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(32.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Speagle(pose = SpeaglePose.POINT, size = 90.dp)
            Text(title, style = SpellTheme.display(22.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
            PinDots(length = 4, filled = digits.length)
            error?.let { message -> Text(message, color = SpellTheme.colors.error, style = SpellTheme.body(14.sp)) }
            PinPad(onDigit = ::onDigit, onDelete = { if (digits.isNotEmpty()) digits = digits.dropLast(1) })
            TextButton(onClick = onCancel) {
                Text("Cancel", color = SpellTheme.colors.textSecondary)
            }
        }
    }
    }
}
