import SwiftUI
import UIKit

/// A full color set a child can pick in Settings. Field names mirror the
/// role names in the app's theme token spec (background/surface/primary/
/// action/tile/reward/etc.) rather than old ad-hoc names like "coral" or
/// "blue" -- a role keeps its meaning (e.g. `action` is always "the main
/// kid-facing action color") even though the actual color behind it
/// changes per theme.
///
/// `Default` is the one profile that adapts to the system's light/dark
/// setting (its neutrals carry separate light/dark hex values, same as
/// before this token system existed). `Space`, `Princess`, and `Circus`
/// each fix their own look regardless of system appearance -- per their
/// source spec every one of their tokens is a single value, so their
/// light/dark struct fields are just set to the same hex twice.
struct ColorProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let backgroundLight: UInt32
    let backgroundDark: UInt32
    let surfaceLight: UInt32
    let surfaceDark: UInt32
    /// The main Practice card only -- every other card/field uses `surface`.
    let surfaceRaisedLight: UInt32
    let surfaceRaisedDark: UInt32
    let hairlineLight: UInt32
    let hairlineDark: UInt32
    /// 1.0 for Default, whose hairline hexes are already subtle, pre-blended
    /// colors meant to be drawn solid (unchanged from before this token
    /// system). The token spec's other themes instead give one bold
    /// "hairline" hue meant to be washed out with opacity -- collapsed here
    /// to a single flat value (28%, the spec's "card/field borders" tier)
    /// rather than its three separate row/section/border tiers, since nothing
    /// in this app distinguishes those contexts today.
    let hairlineOpacity: Double
    let textPrimaryLight: UInt32
    let textPrimaryDark: UInt32
    let textSecondaryLight: UInt32
    let textSecondaryDark: UInt32
    /// Navigation, progress (outside of reward contexts), Save/Done
    /// buttons, lock badges.
    let primary: UInt32
    /// The main kid-facing action: the Practice card, "Check my word."
    let action: UInt32
    /// Letter-tile border, reward sliders, decorative/Settings icons.
    let tile: UInt32
    /// Weekly-prize card border, weekly-prize progress fill.
    let reward: UInt32
    let rewardFillLight: UInt32
    let rewardFillDark: UInt32
    /// The prize star icon specifically.
    let rewardIcon: UInt32
    /// The "WEEKLY PRIZE" label text specifically.
    let rewardText: UInt32
    /// The picker circle in Settings -- usually just `action`, but not
    /// every theme's `action` color reads as representative of the theme
    /// at a glance (Space's is orange, Princess's is purple), so this is
    /// its own field rather than always reusing `action`.
    let swatchColor: UInt32

    static let all: [ColorProfile] = [.default, .space, .princess, .circus]

    static func profile(id: String) -> ColorProfile {
        all.first(where: { $0.id == id }) ?? .default
    }

    static let `default` = ColorProfile(
        id: "default",
        name: "Default",
        backgroundLight: 0xF1EFEE, backgroundDark: 0x1C1B19,
        surfaceLight: 0xFDFDFC, surfaceDark: 0x2A2825,
        surfaceRaisedLight: 0xFDFDFC, surfaceRaisedDark: 0x2A2825,
        hairlineLight: 0xE2E0DB, hairlineDark: 0x3A3833,
        hairlineOpacity: 1.0,
        textPrimaryLight: 0x2A2925, textPrimaryDark: 0xF1EFEA,
        textSecondaryLight: 0x6E6C66, textSecondaryDark: 0xA8A49C,
        primary: 0x3E7089,
        action: 0xE14C3E,
        tile: 0x8257B5,
        reward: 0xC9A227,
        rewardFillLight: 0xFBF6E3, rewardFillDark: 0x332B12,
        rewardIcon: 0xC9A227,
        rewardText: 0xC9A227,
        swatchColor: 0xE14C3E
    )

    /// Dark, starry. Fonts kept as the app's existing serif/system pairing
    /// rather than the spec's Exo 2/Nunito, per request.
    static let space = ColorProfile(
        id: "space",
        name: "Space",
        backgroundLight: 0x141A33, backgroundDark: 0x141A33,
        surfaceLight: 0x1D2547, surfaceDark: 0x1D2547,
        surfaceRaisedLight: 0x222B52, surfaceRaisedDark: 0x222B52,
        hairlineLight: 0xEEF1FF, hairlineDark: 0xEEF1FF,
        hairlineOpacity: 0.28,
        textPrimaryLight: 0xEEF1FF, textPrimaryDark: 0xEEF1FF,
        textSecondaryLight: 0xB3BBDF, textSecondaryDark: 0xB3BBDF,
        primary: 0x5EC8F2,
        action: 0xFF7A59,
        tile: 0xB18CFF,
        reward: 0xFFD166,
        rewardFillLight: 0x262A44, rewardFillDark: 0x262A44,
        rewardIcon: 0xFFD166,
        rewardText: 0xFFE39E,
        swatchColor: 0x141A33
    )

    /// Soft pink and purple. Fonts kept as the app's existing serif/system
    /// pairing rather than the spec's Playfair Display/Lora, per request.
    static let princess = ColorProfile(
        id: "princess",
        name: "Princess",
        backgroundLight: 0xFDF3F6, backgroundDark: 0xFDF3F6,
        surfaceLight: 0xFFFAFC, surfaceDark: 0xFFFAFC,
        surfaceRaisedLight: 0xFFFFFF, surfaceRaisedDark: 0xFFFFFF,
        hairlineLight: 0x3B1F3A, hairlineDark: 0x3B1F3A,
        hairlineOpacity: 0.28,
        textPrimaryLight: 0x3B1F3A, textPrimaryDark: 0x3B1F3A,
        textSecondaryLight: 0x765671, textSecondaryDark: 0x765671,
        primary: 0xB8367F,
        action: 0x8F5BD6,
        tile: 0xD19A2E,
        reward: 0xE8B64C,
        rewardFillLight: 0xFFF9EC, rewardFillDark: 0xFFF9EC,
        rewardIcon: 0xA07516,
        rewardText: 0x7A5810,
        // Princess's `background` (#fdf3f6) is a light pink too, but is
        // close enough to white that it barely reads as a color at swatch
        // size -- this is a more saturated, still-light pink chosen just
        // to be clearly visible and clearly pink at a glance.
        swatchColor: 0xFFB6C1
    )

    /// Warm, bold, carnival-poster colors. Fonts kept as the app's existing
    /// serif/system pairing rather than the spec's Alfa Slab One/Nunito, per
    /// request. Unrelated to (and replaces) an earlier "Circus" theme this
    /// app used to have -- this is a different palette from the same
    /// updated theme spec as Space and Princess.
    static let circus = ColorProfile(
        id: "circus",
        name: "Circus",
        backgroundLight: 0xFBF1E1, backgroundDark: 0xFBF1E1,
        surfaceLight: 0xFFF8EC, surfaceDark: 0xFFF8EC,
        surfaceRaisedLight: 0xFFFBF3, surfaceRaisedDark: 0xFFFBF3,
        hairlineLight: 0x2A1A14, hairlineDark: 0x2A1A14,
        hairlineOpacity: 0.28,
        textPrimaryLight: 0x2A1A14, textPrimaryDark: 0x2A1A14,
        textSecondaryLight: 0x6B5446, textSecondaryDark: 0x6B5446,
        primary: 0x1F4E8C,
        action: 0xD62B2B,
        tile: 0x1F8A7A,
        reward: 0xF2B705,
        rewardFillLight: 0xFFF7E0, rewardFillDark: 0xFFF7E0,
        rewardIcon: 0x9A7300,
        rewardText: 0x6E5200,
        swatchColor: 0xD62B2B
    )
}

/// Visual language pulled from the parent app's UI mockups: a serif display
/// face paired with system sans body text, an off-white background, and a
/// small set of role-based accent colors (see `ColorProfile`).
///
/// The neutral tokens (background, surface, hairline, text) are adaptive so
/// they respond to the appearance chosen in Settings when the active
/// profile is `Default`; the other profiles fix their own light/dark
/// values, so they look the same regardless of the system setting.
///
/// Colors read from `currentProfile`, which a child's `colorProfile` picks
/// in Settings, rather than being hardcoded -- but they're still plain
/// static properties (not environment-driven) so every existing
/// `Theme.background`-style call site keeps working untouched. Whatever
/// sets `currentProfile` needs to force the view tree to rebuild (e.g. an
/// `.id()` keyed to the profile) so already-built views pick up the change
/// -- see `ContentView`.
enum Theme {
    static var currentProfile: ColorProfile = .default

    /// Called from `ContentView.body` (as a `let _ =` side effect, so it
    /// runs before the rest of the tree is built) with the active child's
    /// `colorProfile`, ahead of the `.id()` that forces everything to
    /// rebuild against it.
    static func apply(profileID: String?) {
        currentProfile = ColorProfile.profile(id: profileID ?? "default")

        // UISegmentedControl (the Practice/Test toggle on Home, Settings'
        // Appearance picker) doesn't pick up custom theme colors on its
        // own. Its unselected-segment text defaults to a fixed color
        // regardless of Theme (unreadable against a dark theme like
        // Space), and its selected-segment pill defaults to a fixed
        // near-white background -- which became a second invisible-text
        // bug once the text itself was pointed at Theme.textPrimary
        // (also near-white for Space): white text on a white pill.
        // UIAppearance proxies are global and take a UIColor, not a
        // SwiftUI Color, so this is reapplied here (the one place the
        // active theme changes). The selected pill and its text use the
        // theme's own text/background colors, swapped -- an "inverted"
        // chip that's guaranteed good contrast in any theme, since
        // text-vs-background is already that theme's core readability
        // pair, rather than picking an accent color and hoping white (or
        // any other fixed color) happens to read well against it.
        let unselectedTextColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: Theme.currentProfile.textPrimaryDark))
                : UIColor(Color(hex: Theme.currentProfile.textPrimaryLight))
        }
        let selectedTextColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: Theme.currentProfile.backgroundDark))
                : UIColor(Color(hex: Theme.currentProfile.backgroundLight))
        }
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: unselectedTextColor], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: selectedTextColor], for: .selected)
        UISegmentedControl.appearance().selectedSegmentTintColor = unselectedTextColor
    }

    static var background: Color { Color.adaptive(light: currentProfile.backgroundLight, dark: currentProfile.backgroundDark) }
    static var surface: Color { Color.adaptive(light: currentProfile.surfaceLight, dark: currentProfile.surfaceDark) }
    static var surfaceRaised: Color { Color.adaptive(light: currentProfile.surfaceRaisedLight, dark: currentProfile.surfaceRaisedDark) }
    static var hairline: Color {
        Color.adaptive(light: currentProfile.hairlineLight, dark: currentProfile.hairlineDark)
            .opacity(currentProfile.hairlineOpacity)
    }
    static var textPrimary: Color { Color.adaptive(light: currentProfile.textPrimaryLight, dark: currentProfile.textPrimaryDark) }
    static var textSecondary: Color { Color.adaptive(light: currentProfile.textSecondaryLight, dark: currentProfile.textSecondaryDark) }
    static var primary: Color { Color(hex: currentProfile.primary) }
    static var action: Color { Color(hex: currentProfile.action) }
    static var tile: Color { Color(hex: currentProfile.tile) }
    static var reward: Color { Color(hex: currentProfile.reward) }
    static var rewardFill: Color { Color.adaptive(light: currentProfile.rewardFillLight, dark: currentProfile.rewardFillDark) }
    static var rewardIcon: Color { Color(hex: currentProfile.rewardIcon) }
    static var rewardText: Color { Color(hex: currentProfile.rewardText) }

    /// Correct/incorrect feedback -- kept constant across every color theme
    /// (unlike the decorative accents above) since "right" vs "wrong" needs
    /// to always read the same way to a child regardless of which theme is
    /// active, and the theme token spec this enum's other colors are drawn
    /// from doesn't define role names for this pair at all.
    static let success = Color(hex: 0x3F8B5D)
    static let error = Color(hex: 0xE14C3E)

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat = 17, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 10
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, opacity: opacity)
    }

    /// A color that switches between a light and dark hex value based on
    /// the active trait collection, so it responds correctly whether the
    /// app is following the system appearance or one forced via
    /// `.preferredColorScheme`.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }
}

private struct CardBackground: ViewModifier {
    var background: Color = Theme.surface
    var borderColor: Color = Theme.hairline
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }
}

extension View {
    func card(background: Color = Theme.surface, borderColor: Color = Theme.hairline, lineWidth: CGFloat = 1) -> some View {
        modifier(CardBackground(background: background, borderColor: borderColor, lineWidth: lineWidth))
    }
}
