import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var children: [Child]

    @State private var path = NavigationPath()
    @State private var pendingDestination: GatedDestination?

    enum GatedDestination: Identifiable, Hashable {
        case addList, rewards, settings, editName
        var id: Self { self }
    }

    struct PracticeRoute: Hashable {
        let weekListID: PersistentIdentifier
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let child = children.first {
                    HomeView(
                        child: child,
                        onOpenGated: requestGatedAccess,
                        onStartPractice: { weekList in
                            path.append(PracticeRoute(weekListID: weekList.persistentModelID))
                        }
                    )
                } else {
                    ProgressView()
                        .task { createDefaultChildIfNeeded() }
                }
            }
            .navigationDestination(for: GatedDestination.self) { destination in
                if let child = children.first {
                    switch destination {
                    case .addList: AddListView(child: child)
                    case .rewards: RewardsView(child: child)
                    case .settings: SettingsView(child: child)
                    case .editName: EditNameView(child: child)
                    }
                }
            }
            .navigationDestination(for: PracticeRoute.self) { route in
                if let weekList = modelContext.model(for: route.weekListID) as? WeekList {
                    PracticeView(weekList: weekList)
                }
            }
        }
        .sheet(item: $pendingDestination) { destination in
            if KeychainService.hasPIN() {
                ParentGateView { pin in
                    let ok = ParentGate.verify(pin: pin)
                    if ok {
                        pendingDestination = nil
                        path.append(destination)
                    }
                    return ok
                }
            } else {
                CreatePINView { pin in
                    KeychainService.savePIN(pin)
                    pendingDestination = nil
                    path.append(destination)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(preferredColorScheme)
    }

    /// Reflects the appearance chosen on the Settings screen. "system"
    /// (the default before a parent ever touches the picker) returns nil,
    /// which leaves the device's own light/dark setting in charge.
    private var preferredColorScheme: ColorScheme? {
        switch children.first?.appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Always shows the PIN gate — every visit to a grown-up screen requires
    /// the PIN, even if one was just entered to reach a different one (or
    /// the same one, moments ago).
    private func requestGatedAccess(_ destination: GatedDestination) {
        pendingDestination = destination
    }

    private func createDefaultChildIfNeeded() {
        guard children.isEmpty else { return }
        let child = Child(name: "Connor")
        modelContext.insert(child)
    }
}
