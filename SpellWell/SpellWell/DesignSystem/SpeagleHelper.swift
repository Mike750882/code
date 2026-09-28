import SwiftUI

/// Which of Speagle's poses to show -- each maps to a matching image asset
/// in Assets.xcassets (`SpeagleWave`, `SpeaglePoint`, `SpeagleThink`,
/// `SpeagleCheer`), all four drawn in the same style so any pose can be
/// swapped in anywhere without looking like a different character.
enum SpeaglePose: String {
    /// Waving hello -- the welcome screen, and anywhere else introducing
    /// Speagle for the first time in a session.
    case wave
    /// Pointing -- guiding a grown-up through a step, like entering this
    /// week's spelling words.
    case point
    /// A thoughtful "hmm" -- practice-screen encouragement, sounding a
    /// word out.
    case think
    /// Both wings up, celebrating -- a top score on the results screen.
    case cheer

    fileprivate var imageName: String {
        switch self {
        case .wave: return "SpeagleWave"
        case .point: return "SpeaglePoint"
        case .think: return "SpeagleThink"
        case .cheer: return "SpeagleCheer"
        }
    }
}

/// SpellWell's mascot -- a friendly cartoon bald eagle, "Speagle." Replaces
/// the earlier plain-shapes robot character with real illustrated artwork
/// (see Assets.xcassets and the README's "App mascot" section for how it
/// was produced), while keeping the same "avatar + speech bubble" shape
/// most screens already used.
struct Speagle: View {
    var pose: SpeaglePose = .wave
    var size: CGFloat = 56

    var body: some View {
        Image(pose.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Speagle paired with a short message bubble -- the shape most screens
/// actually use. `message` should always be a short, generic, encouraging
/// line (or, on the welcome screen, Speagle's own introduction), never a
/// real per-word example sentence: nothing in this app looks up or
/// generates those (it would mean a network call -- an LLM or dictionary
/// API -- and everything else in SpellWell runs entirely on-device, so
/// that was deliberately left out for now; see README).
struct SpeagleTip: View {
    let message: String
    var pose: SpeaglePose = .wave
    var avatarSize: CGFloat = 48

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Speagle(pose: pose, size: avatarSize)
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

/// A comic-style speech bubble with a tail pointing down toward Speagle's
/// head, meant to sit directly above him -- the welcome screen's "he's
/// introducing himself" layout, distinct from `SpeagleTip`'s usual
/// side-by-side avatar-plus-bubble shape used everywhere else.
struct SpeagleSpeechBubble: View {
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Text(message)
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.controlCornerRadius, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
            // Unstroked and tucked up 1pt under the bubble -- its own fill
            // blends seamlessly into the bubble above rather than showing a
            // stray border line where a stroked tail would meet the
            // bubble's own stroked bottom edge.
            SpeechBubbleTail()
                .fill(Theme.surface)
                .frame(width: 18, height: 10)
                .offset(y: -1)
        }
    }
}

private struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
