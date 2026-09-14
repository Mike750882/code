import Foundation

/// Verifies a PIN against the one stored in Keychain. Stateless on purpose:
/// each grown-up screen (Add List, Rewards, Settings) is gated
/// independently, so unlocking one never carries over to another, or to a
/// later visit to the same one.
enum ParentGate {
    static func verify(pin: String) -> Bool {
        guard let stored = KeychainService.loadPIN() else { return false }
        return stored == pin
    }
}
