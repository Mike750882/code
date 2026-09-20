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

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.blue)
                Text(title)
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                TextField("Student's name", text: $name)
                    .font(Theme.display(22))
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
                    .foregroundStyle(Theme.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
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
