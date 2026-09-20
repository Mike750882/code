import SwiftUI
import UIKit

/// A full background+accent color set a child can pick in Settings. Every
/// value here mirrors what used to be hardcoded directly on `Theme`, just
/// grouped so a whole set can be swapped at once.
struct ColorProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let backgroundLight: UInt32
    let backgroundDark: UInt32
    let surfaceLight: UInt32
    let surfaceDark: UInt32
    let hairlineLight: UInt32
    let hairlineDark: UInt32
    let textPrimaryLight: UInt32
    let textPrimaryDark: UInt32
    let textSecondaryLight: UInt32
    let textSecondaryDark: UInt32
    let coral: UInt32
    let blue: UInt32
    let purple: UInt32
    let gold: UInt32
    let goldFillLight: UInt32
    let goldFillDark: UInt32
    /// Correct-answer accent for the practice results screen.
    let green: UInt32

    static let all: [ColorProfile] = [.default, .happy]

    static func profile(id: String) -> ColorProfile {
        all.first(where: { $0.id == id }) ?? .default
    }

    static let `default` = ColorProfile(
        id: "default",
        name: "Default",
        backgroundLight: 0xF1EFEE, backgroundDark: 0x1C1B19,
        surfaceLight: 0xFDFDFC, surfaceDark: 0x2A2825,
        hairlineLight: 0xE2E0DB, hairlineDark: 0x3A3833,
        textPrimaryLight: 0x2A2925, textPrimaryDark: 0xF1EFEA,
        textSecondaryLight: 0x6E6C66, textSecondaryDark: 0xA8A49C,
        coral: 0xE14C3E,
        blue: 0x3E7089,
        purple: 0x8257B5,
        gold: 0xC9A227,
        goldFillLight: 0xFBF6E3, goldFillDark: 0x332B12,
        green: 0x3F8B5D
    )

    /// Vivid primary-color palette. No background was supplied for this
    /// one, so it reuses Default's neutral background/surface/text tokens
    /// and only swaps the five accent colors. No purple was supplied
    /// either -- the orange filled that role since it was the one color
    /// left over once red/blue/yellow/green matched coral/blue/gold/green.
    static let happy = ColorProfile(
        id: "happy",
        name: "Happy",
        backgroundLight: 0xF1EFEE, backgroundDark: 0x1C1B19,
        surfaceLight: 0xFDFDFC, surfaceDark: 0x2A2825,
        hairlineLight: 0xE2E0DB, hairlineDark: 0x3A3833,
        textPrimaryLight: 0x2A2925, textPrimaryDark: 0xF1EFEA,
        textSecondaryLight: 0x6E6C66, textSecondaryDark: 0xA8A49C,
        coral: 0xF50A00,
        blue: 0x00A1FC,
        purple: 0xE68600,
        gold: 0xFFD903,
        goldFillLight: 0xFBF6E3, goldFillDark: 0x332B12,
        green: 0x28BA1D
    )
}

/// Visual language pulled from the parent app's UI mockups: a serif display
/// face paired with system sans body text, an off-white background, and
/// three accent colors (coral for primary actions, blue for streaks/audio/
/// info, purple for the letter-tile game and reward sliders).
///
/// The neutral tokens (background, surface, hairline, text, the weekly-prize
/// wash) are adaptive so they respond to the appearance chosen in Settings;
/// the saturated accents read fine unchanged in both modes.
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
    }

    static var background: Color { Color.adaptive(light: currentProfile.backgroundLight, dark: currentProfile.backgroundDark) }
    static var surface: Color { Color.adaptive(light: currentProfile.surfaceLight, dark: currentProfile.surfaceDark) }
    static var hairline: Color { Color.adaptive(light: currentProfile.hairlineLight, dark: currentProfile.hairlineDark) }
    static var textPrimary: Color { Color.adaptive(light: currentProfile.textPrimaryLight, dark: currentProfile.textPrimaryDark) }
    static var textSecondary: Color { Color.adaptive(light: currentProfile.textSecondaryLight, dark: currentProfile.textSecondaryDark) }
    static var coral: Color { Color(hex: currentProfile.coral) }
    static var blue: Color { Color(hex: currentProfile.blue) }
    static var purple: Color { Color(hex: currentProfile.purple) }
    static var gold: Color { Color(hex: currentProfile.gold) }
    static var goldFill: Color { Color.adaptive(light: currentProfile.goldFillLight, dark: currentProfile.goldFillDark) }
    /// Correct-answer accent for the practice results screen.
    static var green: Color { Color(hex: currentProfile.green) }

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
    var borderColor: Color = Theme.hairline
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }
}

extension View {
    func card(borderColor: Color = Theme.hairline, lineWidth: CGFloat = 1) -> some View {
        modifier(CardBackground(borderColor: borderColor, lineWidth: lineWidth))
    }
}
