import SwiftUI
import UIKit

/// Visual language pulled from the parent app's UI mockups: a serif display
/// face paired with system sans body text, an off-white background, and
/// three accent colors (coral for primary actions, blue for streaks/audio/
/// info, purple for the letter-tile game and reward sliders).
///
/// The neutral tokens (background, surface, hairline, text, the weekly-prize
/// wash) are adaptive so they respond to the appearance chosen in Settings;
/// the saturated accents read fine unchanged in both modes.
enum Theme {
    static let background = Color.adaptive(light: 0xF1EFEE, dark: 0x1C1B19)
    static let surface = Color.adaptive(light: 0xFDFDFC, dark: 0x2A2825)
    static let hairline = Color.adaptive(light: 0xE2E0DB, dark: 0x3A3833)
    static let textPrimary = Color.adaptive(light: 0x2A2925, dark: 0xF1EFEA)
    static let textSecondary = Color.adaptive(light: 0x6E6C66, dark: 0xA8A49C)
    static let coral = Color(hex: 0xE14C3E)
    static let blue = Color(hex: 0x3E7089)
    static let purple = Color(hex: 0x8257B5)
    static let gold = Color(hex: 0xC9A227)
    static let goldFill = Color.adaptive(light: 0xFBF6E3, dark: 0x332B12)
    /// Correct-answer accent for the practice results screen.
    static let green = Color(hex: 0x3F8B5D)

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
