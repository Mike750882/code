import Foundation

/// Tracks whether the parent gate is currently unlocked. Auto re-locks after
/// a short idle period so a PIN entered once doesn't leave grown-up screens
/// exposed for the rest of the day.
@MainActor
final class ParentGateManager: ObservableObject {
    @Published private(set) var isUnlocked: Bool = false
    private var relockTask: Task<Void, Never>?
    private let unlockDuration: TimeInterval = 120

    func attemptUnlock(pin: String) -> Bool {
        guard let stored = KeychainService.loadPIN(), stored == pin else { return false }
        unlock()
        return true
    }

    func unlock() {
        isUnlocked = true
        scheduleRelock()
    }

    func lock() {
        isUnlocked = false
        relockTask?.cancel()
    }

    private func scheduleRelock() {
        relockTask?.cancel()
        relockTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(unlockDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.lock()
        }
    }
}
