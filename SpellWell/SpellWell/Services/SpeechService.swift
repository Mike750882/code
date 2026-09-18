import AVFoundation

/// Speaks a word using a parent's recorded pronunciation when one exists,
/// falling back to the system speech synthesizer otherwise.
@MainActor
final class SpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    /// `voiceIdentifier` is an `AVSpeechSynthesisVoice.identifier` (see
    /// Settings' Voice picker); nil, empty, or an identifier that no longer
    /// resolves to an installed voice all fall back to the device's default
    /// voice for the current locale.
    func speak(_ word: String, customAudioData: Data? = nil, voiceIdentifier: String? = nil) {
        if let data = customAudioData, let player = try? AVAudioPlayer(data: data) {
            self.player = player
            player.play()
            return
        }
        let utterance = AVSpeechUtterance(string: word)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        if let voiceIdentifier, !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }
        synthesizer.speak(utterance)
    }
}
