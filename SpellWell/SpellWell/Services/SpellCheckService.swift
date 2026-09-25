import Foundation
import UIKit

/// Flags a word that isn't in the system's English dictionary, using the
/// same on-device checker behind the red squiggly underline in Notes and
/// Messages -- no network call, no API key, nothing sent anywhere. A
/// parent typing this week's spelling list gets a quick "double check
/// this" nudge instead of a typo silently becoming what a child studies
/// all week. It's a dictionary check, not a "did you mean" check -- a
/// name, an uncommon word, or a typo that happens to land on a different
/// real word will slip through or get flagged either way, so this is a
/// safety net, not a guarantee.
enum SpellCheckService {
    private static let checker = UITextChecker()

    /// True if `word` isn't recognized as a correctly-spelled English
    /// word. Empty/whitespace-only input is never flagged -- there's
    /// nothing to check yet.
    static func isPossiblyMisspelled(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        let misspelledRange = checker.rangeOfMisspelledWord(
            in: trimmed, range: range, startingAt: 0, wrap: false, language: "en_US"
        )
        return misspelledRange.location != NSNotFound
    }
}
