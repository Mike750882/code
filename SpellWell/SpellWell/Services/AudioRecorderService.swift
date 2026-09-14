import AVFoundation

/// Backs the "tap a word to record your own voice" affordance on the Add
/// List screen. Not yet wired into a UI control — see README for the hook-up
/// point.
@MainActor
final class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordingURL = url
            isRecording = true
        } catch {
            isRecording = false
        }
    }

    func stopRecording() -> Data? {
        recorder?.stop()
        isRecording = false
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }
}
