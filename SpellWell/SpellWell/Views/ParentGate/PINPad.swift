import SwiftUI

/// The masked 4-digit dot row + number keypad from the "Grown-ups only"
/// mockup. Used everywhere a PIN is entered -- verifying it (ParentGateView)
/// and setting/changing it (SetPINView) -- so every keypad in the app looks
/// identical rather than some screens falling back to the system keyboard.
///
/// Calls `onSubmit` once 4 digits are entered. A `false` return flashes the
/// dots red and clears; `true` just clears silently, leaving it to the
/// caller to decide what happens next (advance a step, dismiss, etc).
struct PINPad: View {
    var onSubmit: (String) -> Bool

    @State private var digits: [Int] = []
    @State private var showError = false

    private let pinLength = 4

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                ForEach(0..<pinLength, id: \.self) { index in
                    Circle()
                        .strokeBorder(showError ? Theme.error : Theme.primary, lineWidth: 1.5)
                        .background(
                            Circle().fill(index < digits.count ? (showError ? Theme.error : Theme.primary) : Color.clear)
                        )
                        .frame(width: 16, height: 16)
                }
            }
            keypad
        }
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
