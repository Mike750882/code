package com.spellwithspeagle.android.ui.practice

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.lifecycle.viewmodel.compose.viewModel
import com.spellwithspeagle.android.data.model.PracticeMode
import com.spellwithspeagle.android.data.model.WordInputMode
import com.spellwithspeagle.android.domain.Grading
import com.spellwithspeagle.android.ui.AppViewModelProvider
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme
import kotlin.math.roundToInt

@Composable
fun PracticeScreen(
    onGoHome: () -> Unit,
    viewModel: PracticeViewModel = viewModel(factory = AppViewModelProvider.Factory)
) {
    val state by viewModel.uiState.collectAsState()

    SpeagleBackground {
    Scaffold(containerColor = Color.Transparent) { padding ->
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
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .padding(24.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
            IconButton(onClick = onGoHome) {
                Icon(Icons.Default.ArrowBack, contentDescription = "Home", tint = SpellTheme.colors.textPrimary)
            }
            Text(state.progressLabel, style = SpellTheme.body(14.sp), color = SpellTheme.colors.textSecondary)
        }

        Spacer(Modifier.height(24.dp))

        Column(
            modifier = Modifier.fillMaxWidth(),
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

            if (state.inputMode == WordInputMode.TYPED) {
                OutlinedTextField(
                    value = state.typedAnswer,
                    onValueChange = viewModel::onAnswerChanged,
                    singleLine = true,
                    textStyle = SpellTheme.display(24.sp, FontWeight.Bold),
                    modifier = Modifier.fillMaxWidth()
                )
            } else {
                TileAnswerArea(state = state, viewModel = viewModel)
            }

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

        Spacer(Modifier.height(24.dp))

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
                enabled = !state.answerText.isNullOrBlank() && state.feedback == null,
                colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.action)
            ) {
                Text("Check my word", color = Color.White)
            }
        }
    }
}

/** Width/height/spacing/font a tile row renders at, shrunk just enough that every tile for the word fits on one line -- never wraps, however long the word is. */
private data class TileMetrics(val width: Dp, val height: Dp, val spacing: Dp, val fontSize: TextUnit)

private val IDEAL_TILE_WIDTH = 44.dp
private val IDEAL_TILE_HEIGHT = 52.dp
private val IDEAL_TILE_SPACING = 6.dp
private val IDEAL_TILE_FONT = 24.sp
private val MIN_TILE_WIDTH = 18.dp
private val MIN_TILE_SPACING = 2.dp

private fun tileMetrics(availableWidth: Dp, tileCount: Int): TileMetrics {
    if (tileCount <= 0 || availableWidth <= 0.dp) {
        return TileMetrics(IDEAL_TILE_WIDTH, IDEAL_TILE_HEIGHT, IDEAL_TILE_SPACING, IDEAL_TILE_FONT)
    }
    val count = tileCount.toFloat()
    val gaps = (count - 1).coerceAtLeast(0f)
    val idealTotal = IDEAL_TILE_WIDTH * count + IDEAL_TILE_SPACING * gaps
    if (idealTotal <= availableWidth) {
        return TileMetrics(IDEAL_TILE_WIDTH, IDEAL_TILE_HEIGHT, IDEAL_TILE_SPACING, IDEAL_TILE_FONT)
    }
    val spacing = maxOf(MIN_TILE_SPACING, IDEAL_TILE_SPACING * (availableWidth / idealTotal))
    val width = maxOf(MIN_TILE_WIDTH, (availableWidth - spacing * gaps) / count)
    val scale = width / IDEAL_TILE_WIDTH
    return TileMetrics(width, IDEAL_TILE_HEIGHT * scale, spacing, (IDEAL_TILE_FONT.value * scale).sp)
}

/**
 * Minimum finger movement before a touch on a bank tile counts as a drag
 * rather than a tap -- below this, [BankTile]'s gesture handler treats it
 * as a tap (fills the first empty blank), same as iOS's 8pt threshold.
 */
private val TAP_VS_DRAG_THRESHOLD = 8.dp

@Composable
private fun TileAnswerArea(state: PracticeUiState, viewModel: PracticeViewModel) {
    val tapThresholdPx = with(LocalDensity.current) { TAP_VS_DRAG_THRESHOLD.toPx() }

    // Which bank tile (if any) is mid-drag, how far it's moved from its
    // start position, and which empty slot it's currently hovering over
    // (for a highlight) -- all reset once the drag ends or is cancelled.
    var draggingBankIndex by remember { mutableStateOf<Int?>(null) }
    var dragOffset by remember { mutableStateOf(Offset.Zero) }
    var dragTargetSlot by remember { mutableStateOf<Int?>(null) }

    // Each tile's on-screen bounds, captured as they're laid out, so a
    // drag's current position (start bounds + accumulated offset) can be
    // tested against every slot to find which one it's over.
    val slotBounds = remember { mutableMapOf<Int, Rect>() }
    val bankTileBounds = remember { mutableMapOf<Int, Rect>() }

    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val metrics = tileMetrics(maxWidth, state.slots.size)
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(metrics.spacing)) {
                state.slots.forEachIndexed { index, slot ->
                    SlotTile(
                        slot = slot,
                        bankLetters = state.bankLetters,
                        metrics = metrics,
                        isTargeted = dragTargetSlot == index,
                        onPositioned = { slotBounds[index] = it },
                        onClick = { viewModel.tapSlot(index) }
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(metrics.spacing)) {
                state.bankLetters.forEachIndexed { index, letter ->
                    if (index < state.bankUsed.size && !state.bankUsed[index]) {
                        BankTile(
                            letter = letter,
                            metrics = metrics,
                            dragOffset = if (draggingBankIndex == index) dragOffset else Offset.Zero,
                            isDragging = draggingBankIndex == index,
                            onPositioned = { bankTileBounds[index] = it },
                            onDragStart = {
                                draggingBankIndex = index
                                dragOffset = Offset.Zero
                            },
                            onDrag = { amount ->
                                dragOffset += amount
                                val start = bankTileBounds[index]
                                dragTargetSlot = if (start != null) {
                                    val currentCenter = start.center + dragOffset
                                    slotBounds.entries.firstOrNull { (slotIndex, bounds) ->
                                        bounds.contains(currentCenter) && state.slots.getOrNull(slotIndex) is SlotState.Empty
                                    }?.key
                                } else {
                                    null
                                }
                            },
                            onDragEnd = {
                                if (dragOffset.getDistance() < tapThresholdPx) {
                                    viewModel.tapBankTile(index)
                                } else {
                                    dragTargetSlot?.let { target -> viewModel.placeInSlot(index, target) }
                                }
                                draggingBankIndex = null
                                dragOffset = Offset.Zero
                                dragTargetSlot = null
                            },
                            onDragCancel = {
                                draggingBankIndex = null
                                dragOffset = Offset.Zero
                                dragTargetSlot = null
                            }
                        )
                    }
                }
            }
            if (state.fillOrder.isNotEmpty()) {
                TextButton(onClick = { viewModel.takeOneBack() }) {
                    Text("Take one back", color = SpellTheme.colors.primary)
                }
            }
        }
    }
}

@Composable
private fun SlotTile(
    slot: SlotState,
    bankLetters: List<Char>,
    metrics: TileMetrics,
    isTargeted: Boolean,
    onPositioned: (Rect) -> Unit,
    onClick: () -> Unit
) {
    val text = when (slot) {
        is SlotState.Prefilled -> slot.char.toString()
        is SlotState.Filled -> bankLetters.getOrNull(slot.bankIndex)?.toString().orEmpty()
        SlotState.Empty -> ""
    }
    val background = when {
        slot is SlotState.Prefilled -> SpellTheme.colors.surfaceRaised
        isTargeted -> SpellTheme.colors.tile.copy(alpha = 0.15f)
        else -> SpellTheme.colors.surface
    }
    var modifier = Modifier
        .size(width = metrics.width, height = metrics.height)
        .onGloballyPositioned { onPositioned(it.boundsInWindow()) }
        .clip(RoundedCornerShape(8.dp))
        .background(background)
        .border(if (isTargeted) 3.dp else 2.dp, SpellTheme.colors.tile, RoundedCornerShape(8.dp))
    if (slot is SlotState.Filled) modifier = modifier.clickable(onClick = onClick)

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        Text(text, style = SpellTheme.display(metrics.fontSize, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
    }
}

/**
 * Tappable (fills the first empty blank) and draggable (slides with the
 * finger and drops into whichever empty blank it's released over) --
 * [onDragStart]/[onDrag]/[onDragEnd]/[onDragCancel] all come from a single
 * [detectDragGestures], the same way iOS treats a tap as just a drag that
 * ends with barely any movement, rather than two separate gesture
 * recognizers that could conflict.
 */
@Composable
private fun BankTile(
    letter: Char,
    metrics: TileMetrics,
    dragOffset: Offset,
    isDragging: Boolean,
    onPositioned: (Rect) -> Unit,
    onDragStart: () -> Unit,
    onDrag: (Offset) -> Unit,
    onDragEnd: () -> Unit,
    onDragCancel: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(width = metrics.width, height = metrics.height)
            .onGloballyPositioned { onPositioned(it.boundsInWindow()) }
            .offset { IntOffset(dragOffset.x.roundToInt(), dragOffset.y.roundToInt()) }
            .zIndex(if (isDragging) 1f else 0f)
            .clip(RoundedCornerShape(8.dp))
            .background(SpellTheme.colors.tile.copy(alpha = 0.15f))
            .border(2.dp, SpellTheme.colors.tile, RoundedCornerShape(8.dp))
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { onDragStart() },
                    onDrag = { change, amount ->
                        change.consume()
                        onDrag(amount)
                    },
                    onDragEnd = { onDragEnd() },
                    onDragCancel = { onDragCancel() }
                )
            },
        contentAlignment = Alignment.Center
    ) {
        Text(letter.toString(), style = SpellTheme.display(metrics.fontSize, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
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
