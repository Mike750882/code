package com.spellwithspeagle.android.ui.tour

import androidx.compose.foundation.ExperimentalFoundationApi
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.spellwithspeagle.android.ui.speagle.Speagle
import com.spellwithspeagle.android.ui.speagle.SpeaglePose
import com.spellwithspeagle.android.ui.theme.SpeagleBackground
import com.spellwithspeagle.android.ui.theme.SpellTheme
import kotlinx.coroutines.launch

private data class TourPage(val pose: SpeaglePose, val title: String, val body: String)

private val TOUR_PAGES = listOf(
    TourPage(SpeaglePose.WAVE, "Hi, I'm Speagle!", "I'm here to help you learn to spell. Let's take a quick look around."),
    TourPage(SpeaglePose.POINT, "Setting your PIN", "The first time you open a grown-up screen, you'll set a 4-digit PIN. Only grown-ups who know it can get back in."),
    TourPage(SpeaglePose.POINT, "The Settings screen", "Change your PIN, pick a voice, choose a color theme, and see a full progress report -- all from Settings."),
    TourPage(SpeaglePose.POINT, "More than one student", "Settings -> Student profiles lets you add a sibling or switch who's practicing, any time."),
    TourPage(SpeaglePose.THINK, "This week's words", "Tap \"This week's words\" on Home any time to see the full list -- no PIN needed, it's just a study aid."),
    TourPage(SpeaglePose.THINK, "Practice vs. Test", "Practice lets you try a word as many times as you like. Test checks once per word and counts toward the day's grade -- retaking it the same day replaces the earlier grade."),
    TourPage(SpeaglePose.THINK, "Hear it, spell it", "Tap the word to hear it read aloud. Some days you'll type it, other days you'll arrange letter tiles -- tap a tile to place it, tap it again to take it back."),
    TourPage(SpeaglePose.THINK, "Grades and progress", "Home shows a grade for each day's test. A grade only counts for the day it's taken -- there's no backfilling a missed day."),
    TourPage(SpeaglePose.POINT, "Grown-ups only", "Add List, Rewards, and Settings all ask for the PIN every time, to keep them just for grown-ups."),
    TourPage(SpeaglePose.CHEER, "Rewards", "Set a reward and a goal percentage for each day, plus one big weekly prize. Hit the goal and a gold badge shows up on that day's grade card!")
)

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TourScreen(onDone: () -> Unit) {
    val pagerState = rememberPagerState(pageCount = { TOUR_PAGES.size })
    val scope = rememberCoroutineScope()

    SpeagleBackground {
    Scaffold(containerColor = Color.Transparent) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(24.dp)) {
            Row(horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = onDone) {
                    Text("Skip", color = SpellTheme.colors.textSecondary)
                }
            }

            HorizontalPager(state = pagerState, modifier = Modifier.weight(1f)) { page ->
                val tourPage = TOUR_PAGES[page]
                Column(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Speagle(pose = tourPage.pose, size = 140.dp)
                    Text(tourPage.title, style = SpellTheme.display(24.sp, FontWeight.Bold), color = SpellTheme.colors.textPrimary)
                    Text(tourPage.body, style = SpellTheme.body(16.sp), color = SpellTheme.colors.textSecondary)
                }
            }

            Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                TOUR_PAGES.indices.forEach { index ->
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (index == pagerState.currentPage) SpellTheme.colors.primary else SpellTheme.colors.hairline)
                    )
                    if (index != TOUR_PAGES.lastIndex) Spacer(Modifier.width(6.dp))
                }
            }

            val isLastPage = pagerState.currentPage == TOUR_PAGES.lastIndex
            Button(
                onClick = {
                    if (isLastPage) {
                        onDone()
                    } else {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = SpellTheme.colors.primary)
            ) {
                Text(if (isLastPage) "Done" else "Next")
            }
        }
    }
    }
}
