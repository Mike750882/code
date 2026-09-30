package com.spellwithspeagle.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Resolved role-based colors for the currently active [ColorProfile] +
 * light/dark setting. Mirrors iOS `Theme`'s computed static properties, but
 * as a plain value read via [LocalSpellColors] so Compose recomposes
 * automatically when the profile or system appearance changes (iOS instead
 * forces a full tree rebuild with `.id(profileID)`).
 */
@Immutable
data class SpellColors(
    val background: Color,
    val surface: Color,
    val surfaceRaised: Color,
    val hairline: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val primary: Color,
    val action: Color,
    val tile: Color,
    val reward: Color,
    val rewardFill: Color,
    val rewardIcon: Color,
    val rewardText: Color,
    /** Fixed across every theme -- "right"/"wrong" must always read the same way. */
    val success: Color,
    val error: Color
)

private val SuccessColor = Color(0xFF3F8B5D)
private val ErrorColor = Color(0xFFE14C3E)

private fun ColorProfile.resolve(darkTheme: Boolean): SpellColors = SpellColors(
    background = if (darkTheme) backgroundDark else backgroundLight,
    surface = if (darkTheme) surfaceDark else surfaceLight,
    surfaceRaised = if (darkTheme) surfaceRaisedDark else surfaceRaisedLight,
    hairline = (if (darkTheme) hairlineDark else hairlineLight).copy(alpha = hairlineOpacity),
    textPrimary = if (darkTheme) textPrimaryDark else textPrimaryLight,
    textSecondary = if (darkTheme) textSecondaryDark else textSecondaryLight,
    primary = primary,
    action = action,
    tile = tile,
    reward = reward,
    rewardFill = if (darkTheme) rewardFillDark else rewardFillLight,
    rewardIcon = rewardIcon,
    rewardText = rewardText,
    success = SuccessColor,
    error = ErrorColor
)

val LocalSpellColors = staticCompositionLocalOf { ColorProfile.Default.resolve(darkTheme = false) }

/** The active [ColorProfile.id] -- lets a screen ask "am I on Default?" (e.g. [SpeagleBackground]) without threading the profile through every call site. */
val LocalColorProfileId = staticCompositionLocalOf { ColorProfile.Default.id }

/**
 * App-wide design constants, mirroring iOS `Theme`'s static helpers
 * (`Theme.display(_:weight:)`, `Theme.cardCornerRadius`, etc.) so call
 * sites read the same way: `SpellTheme.colors.action`, `SpellTheme.display(28.sp)`.
 */
object SpellTheme {
    val colors: SpellColors
        @Composable get() = LocalSpellColors.current

    val cardCornerRadius = 16.dp
    val controlCornerRadius = 10.dp

    fun display(size: TextUnit, weight: FontWeight = FontWeight.Normal): TextStyle =
        TextStyle(fontFamily = FontFamily.Serif, fontSize = size, fontWeight = weight)

    fun body(size: TextUnit = 17.sp, weight: FontWeight = FontWeight.Normal): TextStyle =
        TextStyle(fontFamily = FontFamily.Default, fontSize = size, fontWeight = weight)
}

private val AppTypography = Typography()

/**
 * [colorProfile] should come from the active [com.spellwithspeagle.android.data.model.Child];
 * "Default" is the only profile that follows [darkTheme] -- the other three
 * fix their own look, same as iOS.
 */
@Composable
fun SpellWithSpeagleTheme(
    colorProfile: ColorProfile = ColorProfile.Default,
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = colorProfile.resolve(darkTheme)
    CompositionLocalProvider(LocalSpellColors provides colors, LocalColorProfileId provides colorProfile.id) {
        MaterialTheme(
            typography = AppTypography,
            content = content
        )
    }
}
