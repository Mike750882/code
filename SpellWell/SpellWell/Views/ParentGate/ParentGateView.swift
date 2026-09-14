import SwiftUI

/// Matches the "Grown-ups only" mockup: a masked 4-digit PIN pad guarding
/// the Add List, Rewards, and Settings screens.
struct ParentGateView: View {
    var onSubmit: (String) -> Bool

    @State private var digits: [Int] = []
    @State private var showError = false

    private let pinLength = 4

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(Theme.blue)
            Text("Grown-ups only")
                .font(Theme.display(28))
                .foregroundStyle(Theme.textPrimary)
            Text("Enter your four-digit PIN to edit the spelling list and rewards.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                ForEach(0..<pinLength, id: \.self) { index in
                    Circle()
                        .strokeBorder(showError ? Theme.coral : Theme.blue, lineWidth: 1.5)
                        .background(
                            Circle().fill(index < digits.count ? (showError ? Theme.coral : Theme.blue) : Color.clear)
                        )
                        .frame(width: 16, height: 16)
                }
            }

            keypad

            Button("Forgot your PIN?") {
                // TODO: hook up to a real recovery flow (e.g. re-authenticate
                // the parent's Apple ID / iCloud account and let them reset it).
            }
            .font(Theme.body(14))
            .foregroundStyle(Theme.blue)
            .underline()
        }
        .padding(32)
        .frame(maxWidth: 420)
        .card()
    }

    private var keypad: some View {
        let rows: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        keypadButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keypadButton(_ key: String) -> some View {
        if key.isEmpty {
            Color.clear.frame(width: 72, height: 56)
        } else if key == "⌫" {
            Button {
                if !digits.isEmpty { digits.removeLast() }
                showError = false
            } label: {
                Image(systemName: "delete.left")
                    .frame(width: 72, height: 56)
                    .background(Theme.background)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }
        } else {
            Button {
                appendDigit(Int(key)!)
            } label: {
                Text(key)
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 72, height: 56)
                    .background(Theme.background)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.hairline, lineWidth: 1))
            }
        }
    }

    private func appendDigit(_ digit: Int) {
        guard digits.count < pinLength else { return }
        digits.append(digit)
        guard digits.count == pinLength else { return }
        let pin = digits.map(String.init).joined()
        if onSubmit(pin) {
            digits = []
        } else {
            showError = true
            digits = []
        }
    }
}

/// First-run flow: the mockups only show PIN *entry*, but a PIN has to be
/// created before it can be checked. Shown in place of ParentGateView the
/// first time any grown-up screen is opened.
struct CreatePINView: View {
    var onCreated: (String) -> Void

    @State private var pin = ""
    @State private var confirm = ""

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill").foregroundStyle(Theme.blue)
            Text("Create a grown-up PIN")
                .font(Theme.display(26))
                .foregroundStyle(Theme.textPrimary)
            Text("This protects the spelling list, rewards, and settings.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            SecureField("4-digit PIN", text: $pin)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            SecureField("Confirm PIN", text: $confirm)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
            Button("Create PIN") {
                guard pin.count == 4, pin == confirm else { return }
                onCreated(pin)
            }
            .disabled(pin.count != 4 || pin != confirm)
            .font(Theme.body(16, weight: .medium))
            .foregroundStyle(Theme.blue)
        }
        .padding(32)
        .frame(maxWidth: 380)
        .card()
    }
}
