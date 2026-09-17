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

    /// Carries the WeekList object itself, not a PersistentIdentifier.
    /// Capturing an identifier for a just-inserted, not-yet-saved model and
    /// resolving it later crashes with "this model instance was invalidated"
    /// -- new objects only get a temporary identifier until the context is
    /// saved, and temporary identifiers don't survive being round-tripped
    /// like that. Passing the object directly sidesteps the whole problem.
    struct PracticeRoute: Hashable {
        let weekList: WeekList
        let mode: PracticeMode
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let child = children.first {
                    HomeView(
                        child: child,
                        onOpenGated: requestGatedAccess,
                        onStartPractice: { weekList, mode in
                            path.append(PracticeRoute(weekList: weekList, mode: mode))
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
                PracticeView(weekList: route.weekList, mode: route.mode)
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
