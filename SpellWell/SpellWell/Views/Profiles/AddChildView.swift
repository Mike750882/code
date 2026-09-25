import SwiftUI

/// Creates a new student profile. Used two ways: as the app's very first
/// screen when no `Child` exists yet at all (no PIN gate -- there's
/// nothing to protect yet, and a parent is clearly setting up the app for
/// the first time), and from Settings -> Student profiles to add a
/// sibling (already behind the PIN gate to reach Settings).
struct AddChildView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var title: String = "Add a student"
    var subtitle: String = "Give them a name to get started."
    var onCreated: (Child) -> Void
    /// True only for the very first launch's onboarding screen. A brand
    /// new install briefly has real background work competing for the
    /// main thread (iCloud provisioning the CloudKit container for the
    /// first time), which can make the very first keyboard appearance
    /// stutter if a child taps straight into the name field. Waiting a
    /// beat before showing an interactive field avoids that -- not needed
    /// once the app's already been running for a while, like when this
    /// same view is reused from Settings to add a sibling, or on a normal
    /// cold launch (force-quit and reopen) that isn't a fresh install --
    /// the CloudKit setup only happens once, ever, on a given install.
    var showsInitialSetupDelay = false

    @State private var name = ""
    @State private var isReady = false
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.primary)
                Text(title)
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                if isReady {
                    TextField("Student's name", text: $name)
                        .font(Theme.display(22))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline, lineWidth: 1))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isNameFocused)

                    Button("Create") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(Theme.body(16, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.primary, lineWidth: 1.5))
                } else {
                    ProgressView()
                        .tint(Theme.primary)
                        .padding(.vertical, 8)
                    Text("Just a moment...")
                        .font(Theme.body(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(32)
            .frame(maxWidth: 420)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNameFocused = false }
            }
        }
        .onAppear {
            guard !isReady else { return }
            if showsInitialSetupDelay {
                // 1.2s wasn't long enough in practice -- the field was
                // still stuttering on first tap after the spinner
                // disappeared, meaning the underlying CloudKit setup was
                // still going. 3s errs toward safety instead: this delay
                // only ever happens once per real install (never again on
                // a normal cold launch), so a few extra seconds here
                // don't cost anything in everyday use.
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    isReady = true
                }
            } else {
                isReady = true
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let child = Child(name: trimmed)
        modelContext.insert(child)
        onCreated(child)
        dismiss()
    }
}
