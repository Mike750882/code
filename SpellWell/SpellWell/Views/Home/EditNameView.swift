import SwiftUI

/// Renames the child. Only reachable through the PIN gate from the pencil
/// icon next to the greeting on Home. `child` is the same SwiftData object
/// every other screen reads from, so saving here updates the name
/// everywhere immediately -- no separate propagation needed.
struct EditNameView: View {
    @Environment(\.dismiss) private var dismiss
    let child: Child

    @State private var name: String = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.blue)
                Text("Student's name")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.textPrimary)
                Text("This is shown on the Home screen and in all reports.")
                    .font(Theme.body(14))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                TextField("Name", text: $name)
                    .font(Theme.display(22))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.hairline, lineWidth: 1))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFocused)

                Button("Save") { save() }
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNameFocused = false }
            }
        }
        .onAppear { name = child.name }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        child.name = trimmed
        dismiss()
    }
}
