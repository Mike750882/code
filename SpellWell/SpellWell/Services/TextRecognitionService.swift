import UIKit
import Vision

/// On-device OCR for importing a spelling list from a photo of a printed
/// or handwritten word list. Uses Apple's Vision framework -- no
/// third-party library and no network call; the image never leaves the
/// device.
enum TextRecognitionService {
    enum RecognitionError: Error {
        case noText
    }

    static func recognizeWords(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw RecognitionError.noText }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }

        // Split each recognized line into individual words: this handles a
        // numbered list ("1. friend"), commas, or several words per line,
        // by treating anything that isn't a letter or an apostrophe as a
        // separator.
        let words = lines
            .flatMap { line in line.split(whereSeparator: { !$0.isLetter && $0 != "'" }) }
            .map { String($0).lowercased() }
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { throw RecognitionError.noText }
        return words
    }
}
