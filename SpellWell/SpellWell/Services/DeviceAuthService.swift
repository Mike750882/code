import LocalAuthentication

/// Verifies the device owner (Face ID/Touch ID, falling back to the device
/// passcode) before allowing a PIN reset. This is what actually gates
/// "Forgot your PIN?" -- without it, a child could just tap that button and
/// set their own new PIN, defeating the whole parent gate.
enum DeviceAuthService {
    enum Result {
        case success
        case cancelled
        /// No passcode/biometric is set up on this device at all, so there's
        /// nothing to verify against.
        case unavailable
    }

    @MainActor
    static func authenticate(reason: String) async -> Result {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            return success ? .success : .cancelled
        } catch {
            return .cancelled
        }
    }
}
