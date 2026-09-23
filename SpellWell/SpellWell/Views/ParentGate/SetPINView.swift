import SwiftUI

/// Two-step "enter a new PIN, then confirm it" flow, built on the same
/// PINPad used to verify a PIN -- so setting or changing a PIN looks like
/// the same keypad the parent will see every time they unlock a screen,
/// rather than a plain SecureField.
///
/// Used both for first-run PIN creation (the mockups only show PIN
/// *entry*, but a PIN has to be created before it can be checked) and for
/// "Change PIN" on Settings.
struct SetPINView: View {
    var title: String = "Create a grown-up PIN"
    var subtitle: String = "This protects the spelling list, rewards, and settings."
    var onSet: (String) -> Void

    private enum Step: Equatable {
        case enterNew
        case confirm(newPIN: String)
    }

    @State private var step: Step = .enterNew
    @State private var mismatch = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(Theme.primary)
            Text(currentTitle)
                .font(Theme.display(26))
                .foregroundStyle(Theme.textPrimary)
            Text(currentSubtitle)
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // A fresh PINPad instance per step, so its dot row always
            // starts empty rather than carrying over digits from the
            // previous step.
            PINPad(onSubmit: handleSubmit)
                .id(stepIdentity)
        }
        .padding(32)
        .frame(maxWidth: 420)
        .card()
    }

    private var currentTitle: String {
        switch step {
        case .enterNew: return title
        case .confirm: return "Confirm your PIN"
        }
    }

    private var currentSubtitle: String {
        switch step {
        case .enterNew: return subtitle
        case .confirm: return mismatch ? "Those didn't match. Enter your new PIN again." : "Enter it once more to confirm."
        }
    }

    private var stepIdentity: String {
        switch step {
        case .enterNew: return "new"
        case .confirm: return "confirm"
        }
    }

    private func handleSubmit(_ pin: String) -> Bool {
        switch step {
        case .enterNew:
            mismatch = false
            step = .confirm(newPIN: pin)
            return true
        case .confirm(let newPIN):
            if pin == newPIN {
                onSet(pin)
                return true
            } else {
                mismatch = true
                // Let the PINPad's red-flash-and-clear play out before
                // swapping back to the first step.
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    step = .enterNew
                }
                return false
            }
        }
    }
}
