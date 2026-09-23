import SwiftUI

/// Matches the "Grown-ups only" mockup: a masked 4-digit PIN pad guarding
/// the Add List, Rewards, and Settings screens.
struct ParentGateView: View {
    var onSubmit: (String) -> Bool
    var onForgotPIN: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundStyle(Theme.primary)
            Text("Grown-ups only")
                .font(Theme.display(28))
                .foregroundStyle(Theme.textPrimary)
            Text("Enter your four-digit PIN to edit the spelling list and rewards.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            PINPad(onSubmit: onSubmit)

            Button("Forgot your PIN?", action: onForgotPIN)
                .font(Theme.body(14))
                .foregroundStyle(Theme.primary)
                .underline()
        }
        .padding(32)
        .frame(maxWidth: 420)
        .card()
    }
}
