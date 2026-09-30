package com.spellwithspeagle.android.ui.speagle

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.spellwithspeagle.android.R
import com.spellwithspeagle.android.ui.theme.SpellTheme

/** The four illustrated poses of Speagle the eagle mascot. */
enum class SpeaglePose(val drawableRes: Int) {
    WAVE(R.drawable.speagle_wave),
    POINT(R.drawable.speagle_point),
    THINK(R.drawable.speagle_think),
    CHEER(R.drawable.speagle_cheer)
}

/** Renders one pose at the given size. Source art is 1200x1200px transparent PNG. */
@Composable
fun Speagle(pose: SpeaglePose, size: Dp, modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(pose.drawableRes),
        contentDescription = "Speagle the eagle",
        modifier = modifier.size(size)
    )
}

/** Pairs a pose with a short message bubble next to it -- the shape most screens use. */
@Composable
fun SpeagleTip(
    pose: SpeaglePose,
    message: String,
    modifier: Modifier = Modifier,
    avatarSize: Dp = 56.dp
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Speagle(pose = pose, size = avatarSize)
        Text(
            text = message,
            style = SpellTheme.body(15.sp),
            color = SpellTheme.colors.textPrimary,
            modifier = Modifier
                .clip(RoundedCornerShape(SpellTheme.controlCornerRadius))
                .background(SpellTheme.colors.surface)
                .padding(horizontal = 14.dp, vertical = 10.dp)
        )
    }
}
