import AVFoundation

/// Speaks a word using a parent's recorded pronunciation when one exists,
/// falling back to the system speech synthesizer otherwise.
@MainActor
final class SpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?

    func speak(_ word: String, customAudioData: Data? = nil) {
        if let data = customAudioData, let player = try? AVAudioPlayer(data: data) {
            self.player = player
            player.play()
            return
        }
        let utterance = AVSpeechUtterance(string: word)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer.speak(utterance)
    }
}
