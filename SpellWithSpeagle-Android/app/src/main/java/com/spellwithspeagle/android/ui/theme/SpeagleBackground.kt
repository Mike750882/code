package com.spellwithspeagle.android.ui.theme

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.spellwithspeagle.android.R

/**
 * A warm sky/clouds/grass scene pinned to the bottom edge, fading into
 * [SpellTheme.colors]' background toward the top so cards and text stay
 * legible over it -- the Android equivalent of iOS's `.speagleBackground()`
 * modifier. Only shown for the Default color theme; Space/Princess/Circus
 * each commit to their own distinct palette instead (a sunny daytime sky
 * would clash outright with Space's dark starfield in particular), so
 * those three keep a plain background fill.
 *
 * Drop-in replacement for a bare `Scaffold(containerColor = ...)`: wrap the
 * screen's `Scaffold` call in this, and set that Scaffold's own
 * `containerColor` to [androidx.compose.ui.graphics.Color.Transparent] so
 * it doesn't paint over this background.
 */
@Composable
fun SpeagleBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier = modifier.fillMaxSize().background(SpellTheme.colors.background)) {
        if (LocalColorProfileId.current == ColorProfile.Default.id) {
            // Crop (not FillWidth) so the scene covers the full screen height
            // on a tall phone, not just a short band matching the image's
            // own wide-landscape aspect ratio -- BottomCenter keeps the
            // grass line pinned to the bottom edge while the extra height
            // crops in from the sides instead of leaving blank space above.
            Image(
                painter = painterResource(R.drawable.app_background),
                contentDescription = null,
                contentScale = ContentScale.Crop,
                alignment = Alignment.BottomCenter,
                modifier = Modifier.fillMaxSize()
            )
            // Fades the top half of the image into the flat background color
            // so cards/text placed near the top of a screen stay legible.
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.5f)
                    .align(Alignment.TopStart)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(SpellTheme.colors.background, SpellTheme.colors.background.copy(alpha = 0f))
                        )
                    )
            )
        }
        content()
    }
}
