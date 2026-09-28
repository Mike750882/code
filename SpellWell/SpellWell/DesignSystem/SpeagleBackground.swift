import SwiftUI

/// The sky/clouds/grass scene behind most screens, styled to match
/// Speagle -- pinned to the bottom edge so the grass always sits at the
/// bottom regardless of device size or orientation, faded into `Theme
/// .background` toward the top so cards and text stay legible over it.
///
/// Only shown for the Default color theme. Space/Princess/Circus (see
/// `Theme.swift`) each commit to their own distinct palette -- a sunny
/// daytime sky would clash with Space's dark starfield in particular --
/// so those themes keep the plain `Theme.background` fill instead.
private struct SpeagleBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            if Theme.currentProfile.id == "default" {
                GeometryReader { proxy in
                    Image("AppBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                        .clipped()
                }
                LinearGradient(
                    colors: [Theme.background, Theme.background.opacity(0)],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Drop-in replacement for `.background(Theme.background.ignoresSafeArea())`.
    func speagleBackground() -> some View {
        background(SpeagleBackground())
    }
}
