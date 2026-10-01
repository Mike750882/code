package com.spellwithspeagle.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
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
 * "Default" is the only profile that follows [appearance] -- the other
 * three fix their own look regardless of it, same as iOS.
 *
 * [appearance] is [com.spellwithspeagle.android.data.model.Child.appearance]
 * verbatim ("system" | "light" | "dark"). [textScale] is
 * [com.spellwithspeagle.android.data.model.Child.textScale], applied as a
 * multiplier on top of the device's own font-scale setting via
 * [LocalDensity] so every `sp`-sized text in the app grows/shrinks
 * together, matching iOS's text-size slider.
 */
@Composable
fun SpellWithSpeagleTheme(
    colorProfile: ColorProfile = ColorProfile.Default,
    appearance: String = "system",
    textScale: Double = 1.0,
    content: @Composable () -> Unit
) {
    val systemDark = isSystemInDarkTheme()
    val darkTheme = when (appearance) {
        "light" -> false
        "dark" -> true
        else -> systemDark
    }
    val colors = colorProfile.resolve(darkTheme)
    val density = LocalDensity.current
    CompositionLocalProvider(
        LocalSpellColors provides colors,
        LocalColorProfileId provides colorProfile.id,
        LocalDensity provides Density(density.density, density.fontScale * textScale.toFloat())
    ) {
        MaterialTheme(
            typography = AppTypography,
            content = content
        )
    }
}
