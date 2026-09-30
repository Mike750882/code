package com.spellwithspeagle.android.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * A full color set a child can pick in Settings. Field names mirror the
 * role names in the app's theme token spec (background/surface/primary/
 * action/tile/reward/etc.) rather than ad-hoc names like "coral" or "blue"
 * -- a role keeps its meaning (e.g. [action] is always "the main
 * kid-facing action color") even though the actual color behind it changes
 * per theme. Ported 1:1 from iOS `ColorProfile` (`DesignSystem/Theme.swift`).
 *
 * [Default] is the one profile that adapts to light/dark system setting;
 * Space/Princess/Circus each fix their own look regardless of system
 * appearance, matching their source spec (every one of their tokens is a
 * single value).
 */
data class ColorProfile(
    val id: String,
    val displayName: String,
    val backgroundLight: Color,
    val backgroundDark: Color,
    val surfaceLight: Color,
    val surfaceDark: Color,
    /** The main Practice card only -- every other card/field uses [surfaceLight]/[surfaceDark]. */
    val surfaceRaisedLight: Color,
    val surfaceRaisedDark: Color,
    val hairlineLight: Color,
    val hairlineDark: Color,
    val hairlineOpacity: Float,
    val textPrimaryLight: Color,
    val textPrimaryDark: Color,
    val textSecondaryLight: Color,
    val textSecondaryDark: Color,
    /** Navigation, progress (outside reward contexts), Save/Done buttons, lock badges. */
    val primary: Color,
    /** The main kid-facing action: the Practice card, "Check my word." */
    val action: Color,
    /** Letter-tile border, reward sliders, decorative/Settings icons. */
    val tile: Color,
    /** Weekly-prize card border, weekly-prize progress fill. */
    val reward: Color,
    val rewardFillLight: Color,
    val rewardFillDark: Color,
    /** The prize star icon specifically. */
    val rewardIcon: Color,
    /** The "WEEKLY PRIZE" label text specifically. */
    val rewardText: Color,
    /** The picker circle in Settings. */
    val swatchColor: Color
) {
    companion object {
        val Default = ColorProfile(
            id = "default",
            displayName = "Default",
            backgroundLight = Color(0xFFF1EFEE), backgroundDark = Color(0xFF1C1B19),
            surfaceLight = Color(0xFFFDFDFC), surfaceDark = Color(0xFF2A2825),
            surfaceRaisedLight = Color(0xFFFDFDFC), surfaceRaisedDark = Color(0xFF2A2825),
            hairlineLight = Color(0xFFE2E0DB), hairlineDark = Color(0xFF3A3833),
            hairlineOpacity = 1.0f,
            textPrimaryLight = Color(0xFF2A2925), textPrimaryDark = Color(0xFFF1EFEA),
            textSecondaryLight = Color(0xFF6E6C66), textSecondaryDark = Color(0xFFA8A49C),
            primary = Color(0xFF3E7089),
            action = Color(0xFFE14C3E),
            tile = Color(0xFF8257B5),
            reward = Color(0xFFC9A227),
            rewardFillLight = Color(0xFFFBF6E3), rewardFillDark = Color(0xFF332B12),
            rewardIcon = Color(0xFFC9A227),
            rewardText = Color(0xFFC9A227),
            swatchColor = Color(0xFFE14C3E)
        )

        /** Dark, starry blues/purples. */
        val Space = ColorProfile(
            id = "space",
            displayName = "Space",
            backgroundLight = Color(0xFF141A33), backgroundDark = Color(0xFF141A33),
            surfaceLight = Color(0xFF1D2547), surfaceDark = Color(0xFF1D2547),
            surfaceRaisedLight = Color(0xFF222B52), surfaceRaisedDark = Color(0xFF222B52),
            hairlineLight = Color(0xFFEEF1FF), hairlineDark = Color(0xFFEEF1FF),
            hairlineOpacity = 0.28f,
            textPrimaryLight = Color(0xFFEEF1FF), textPrimaryDark = Color(0xFFEEF1FF),
            textSecondaryLight = Color(0xFFB3BBDF), textSecondaryDark = Color(0xFFB3BBDF),
            primary = Color(0xFF5EC8F2),
            action = Color(0xFFFF7A59),
            tile = Color(0xFFB18CFF),
            reward = Color(0xFFFFD166),
            rewardFillLight = Color(0xFF262A44), rewardFillDark = Color(0xFF262A44),
            rewardIcon = Color(0xFFFFD166),
            rewardText = Color(0xFFFFE39E),
            swatchColor = Color(0xFF141A33)
        )

        /** Soft pink and purple. */
        val Princess = ColorProfile(
            id = "princess",
            displayName = "Princess",
            backgroundLight = Color(0xFFFDF3F6), backgroundDark = Color(0xFFFDF3F6),
            surfaceLight = Color(0xFFFFFAFC), surfaceDark = Color(0xFFFFFAFC),
            surfaceRaisedLight = Color(0xFFFFFFFF), surfaceRaisedDark = Color(0xFFFFFFFF),
            hairlineLight = Color(0xFF3B1F3A), hairlineDark = Color(0xFF3B1F3A),
            hairlineOpacity = 0.28f,
            textPrimaryLight = Color(0xFF3B1F3A), textPrimaryDark = Color(0xFF3B1F3A),
            textSecondaryLight = Color(0xFF765671), textSecondaryDark = Color(0xFF765671),
            primary = Color(0xFFB8367F),
            action = Color(0xFF8F5BD6),
            tile = Color(0xFFD19A2E),
            reward = Color(0xFFE8B64C),
            rewardFillLight = Color(0xFFFFF9EC), rewardFillDark = Color(0xFFFFF9EC),
            rewardIcon = Color(0xFFA07516),
            rewardText = Color(0xFF7A5810),
            swatchColor = Color(0xFFFFB6C1)
        )

        /** Warm, bold, carnival-poster colors. */
        val Circus = ColorProfile(
            id = "circus",
            displayName = "Circus",
            backgroundLight = Color(0xFFFBF1E1), backgroundDark = Color(0xFFFBF1E1),
            surfaceLight = Color(0xFFFFF8EC), surfaceDark = Color(0xFFFFF8EC),
            surfaceRaisedLight = Color(0xFFFFFBF3), surfaceRaisedDark = Color(0xFFFFFBF3),
            hairlineLight = Color(0xFF2A1A14), hairlineDark = Color(0xFF2A1A14),
            hairlineOpacity = 0.28f,
            textPrimaryLight = Color(0xFF2A1A14), textPrimaryDark = Color(0xFF2A1A14),
            textSecondaryLight = Color(0xFF6B5446), textSecondaryDark = Color(0xFF6B5446),
            primary = Color(0xFF1F4E8C),
            action = Color(0xFFD62B2B),
            tile = Color(0xFF1F8A7A),
            reward = Color(0xFFF2B705),
            rewardFillLight = Color(0xFFFFF7E0), rewardFillDark = Color(0xFFFFF7E0),
            rewardIcon = Color(0xFF9A7300),
            rewardText = Color(0xFF6E5200),
            swatchColor = Color(0xFFD62B2B)
        )

        val all = listOf(Default, Space, Princess, Circus)

        fun byId(id: String?): ColorProfile = all.firstOrNull { it.id == id } ?: Default
    }
}
