import SwiftUI

/// Visual language pulled from the parent app's UI mockups: a serif display
/// face paired with system sans body text, an off-white background, and
/// three accent colors (coral for primary actions, blue for streaks/audio/
/// info, purple for the letter-tile game and reward sliders).
enum Theme {
    static let background = Color(hex: 0xF1F0EE)
    static let surface = Color(hex: 0xFDFDFC)
    static let hairline = Color(hex: 0xE2E0DB)
    static let textPrimary = Color(hex: 0x2A2925)
    static let textSecondary = Color(hex: 0x6E6C66)
    static let coral = Color(hex: 0xE14C3E)
    static let blue = Color(hex: 0x3E7089)
    static let purple = Color(hex: 0x8257B5)
    static let gold = Color(hex: 0xC9A227)
    static let goldFill = Color(hex: 0xFBF6E3)

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
