import SwiftUI

/// A small friendly robot character, drawn entirely from SwiftUI shapes --
/// no image assets, so it looks crisp and already theme-correct (tinted
/// with `Theme.primary`/`Theme.surface`) in every color theme without
/// needing separate art per theme.
struct RobotAvatar: View {
    var size: CGFloat = 56

    private var strokeWidth: CGFloat { max(1.5, size * 0.045) }

    var body: some View {
        VStack(spacing: size * 0.04) {
            Circle()
                .fill(Theme.primary)
                .frame(width: size * 0.12, height: size * 0.12)
            Rectangle()
                .fill(Theme.primary)
                .frame(width: strokeWidth, height: size * 0.14)

            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .stroke(Theme.primary, lineWidth: strokeWidth)
                )
                .overlay(face)
                .frame(width: size, height: size * 0.82)
        }
    }

    private var face: some View {
        VStack(spacing: size * 0.1) {
            HStack(spacing: size * 0.16) {
                eye
                eye
            }
            Capsule()
                .fill(Theme.primary)
                .frame(width: size * 0.32, height: size * 0.06)
        }
    }

    private var eye: some View {
        Circle()
            .fill(Theme.primary)
            .frame(width: size * 0.13, height: size * 0.13)
    }
}

/// The robot avatar paired with a short message bubble -- the shape most
/// screens actually use. `message` should always be a short, generic,
/// encouraging line, never a real per-word example sentence: nothing in
/// this app looks up or generates those (it would mean a network call --
/// an LLM or dictionary API -- and everything else in SpellWell runs
/// entirely on-device, so that was deliberately left out for now; see
/// README).
struct RobotTip: View {
    let message: String
    var avatarSize: CGFloat = 48

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RobotAvatar(size: avatarSize)
            Text(message)
                .font(Theme.body(14))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        }
    }
}
