import SwiftUI
import SwiftData

/// Lets a parent switch between student profiles, add a new one, or remove
/// one (never the last one -- the app always needs at least one profile to
/// show). Reached from Settings, which is already PIN-gated, so nothing
/// here re-gates.
struct ProfilesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Child.createdAt) private var children: [Child]
    /// Device-local, not synced -- each iPad remembers its own active
    /// student even if the family's iCloud data (and thus every Child
    /// record) syncs across every device.
    @AppStorage("activeChildID") private var activeChildID: String = ""

    /// Called after switching or removing the active profile, so the
    /// caller can pop back to Home and show the newly active student.
    var onSwitchedProfile: () -> Void

    @State private var showAddChild = false
    @State private var childPendingDeletion: Child?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                ForEach(children) { child in
                    profileRow(child)
                    Divider().overlay(Theme.hairline)
                }
                addButton
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddChild) {
            AddChildView(
                onCreated: { child in
                    activeChildID = child.id.uuidString
                    onSwitchedProfile()
                }
            )
        }
        .alert(
            "Remove \(childPendingDeletion?.name ?? "this student")?",
            isPresented: Binding(
                get: { childPendingDeletion != nil },
                set: { if !$0 { childPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { childPendingDeletion = nil }
            Button("Remove", role: .destructive) { deletePending() }
        } message: {
            Text("This permanently deletes their spelling lists, rewards, and progress. This can't be undone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Student profiles")
                .font(Theme.display(30))
                .foregroundStyle(Theme.textPrimary)
            Text("Switch between students, or add another.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.bottom, 16)
    }

    private func isActive(_ child: Child) -> Bool {
        if activeChildID.isEmpty {
            return child.id == children.first?.id
        }
        return child.id.uuidString == activeChildID
    }

    private func profileRow(_ child: Child) -> some View {
        let active = isActive(child)
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(Theme.display(19))
                    .foregroundStyle(Theme.textPrimary)
                Text(active ? "Active on this iPad" : "Tap to switch to this profile")
                    .font(Theme.body(13))
                    .foregroundStyle(active ? Theme.blue : Theme.textSecondary)
            }
            Spacer()
            if active {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.blue)
            }
            if children.count > 1 {
                Button {
                    childPendingDeletion = child
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.coral)
                }
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !active else { return }
            activeChildID = child.id.uuidString
            onSwitchedProfile()
        }
    }

    private var addButton: some View {
        Button {
            showAddChild = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                Text("Add a student")
            }
        }
        .font(Theme.body(16, weight: .medium))
        .foregroundStyle(Theme.blue)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(RoundedRectangle(cornerRadius: Theme.controlCornerRadius).stroke(Theme.blue, lineWidth: 1.5))
        .padding(.top, 16)
    }

    private func deletePending() {
        guard let child = childPendingDeletion, children.count > 1 else {
            childPendingDeletion = nil
            return
        }
        let wasActive = isActive(child)
        modelContext.delete(child)
        childPendingDeletion = nil
        if wasActive {
            // Clear it rather than picking a specific replacement --
            // ContentView/here both fall back to children.first once this
            // one's gone.
            activeChildID = ""
            onSwitchedProfile()
        }
    }
}
