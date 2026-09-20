import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var children: [Child]

    /// Device-local (not synced): each iPad remembers its own active
    /// student even though every Child record itself syncs via CloudKit,
    /// so a family with one iPad per kid can have each default to a
    /// different profile.
    @AppStorage("activeChildID") private var activeChildID: String = ""

    @State private var path = NavigationPath()
    @State private var pendingDestination: GatedDestination?
    @State private var isResettingPIN = false
    @State private var showForgotPINUnavailable = false

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

    /// Falls back to the first child (in creation order isn't guaranteed
    /// here, just @Query's default order) if the stored ID doesn't match
    /// any current profile -- e.g. it was removed, or this is a fresh
    /// device that hasn't picked one yet. nil only when there are no
    /// children at all.
    private var activeChild: Child? {
        if let id = UUID(uuidString: activeChildID), let match = children.first(where: { $0.id == id }) {
            return match
        }
        return children.first
    }

    var body: some View {
        let _ = Theme.apply(profileID: activeChild?.colorProfile)
        NavigationStack(path: $path) {
            Group {
                if let child = activeChild {
                    HomeView(
                        child: child,
                        onOpenGated: requestGatedAccess,
                        onStartPractice: { weekList, mode in
                            path.append(PracticeRoute(weekList: weekList, mode: mode))
                        }
                    )
                } else {
                    // No profiles exist yet at all -- no PIN gate here,
                    // since there's nothing to protect and a parent is
                    // clearly setting up the app for the first time.
                    AddChildView(
                        title: "Welcome to SpellWell",
                        subtitle: "What's your student's name?",
                        onCreated: { child in
                            activeChildID = child.id.uuidString
                        }
                    )
                }
            }
            .navigationDestination(for: GatedDestination.self) { destination in
                if let child = activeChild {
                    switch destination {
                    case .addList: AddListView(child: child)
                    case .rewards: RewardsView(child: child)
                    case .settings: SettingsView(child: child, onProfileSwitched: resetToHome)
                    case .editName: EditNameView(child: child)
                    }
                }
            }
            .navigationDestination(for: PracticeRoute.self) { route in
                PracticeView(weekList: route.weekList, mode: route.mode)
            }
        }
        .sheet(item: $pendingDestination) { destination in
            if KeychainService.hasPIN() && !isResettingPIN {
                ParentGateView(
                    onSubmit: { pin in
                        let ok = ParentGate.verify(pin: pin)
                        if ok {
                            pendingDestination = nil
                            path.append(destination)
                        }
                        return ok
                    },
                    onForgotPIN: { requestPINReset() }
                )
            } else {
                SetPINView(
                    title: isResettingPIN ? "Set a new PIN" : "Create a grown-up PIN",
                    subtitle: isResettingPIN
                        ? "Choose a new 4-digit PIN for this device."
                        : "This protects the spelling list, rewards, and settings.",
                    onSet: { pin in
                        KeychainService.savePIN(pin)
                        isResettingPIN = false
                        pendingDestination = nil
                        path.append(destination)
                    }
                )
            }
        }
        .onChange(of: pendingDestination) { _, newValue in
            // Don't let a reset in progress leak into an unrelated later visit.
            if newValue == nil { isResettingPIN = false }
        }
        .alert("Can't verify it's you", isPresented: $showForgotPINUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Set a passcode, Face ID, or Touch ID on this device in Settings to reset the grown-up PIN.")
        }
        .background(Theme.background.ignoresSafeArea())
        .preferredColorScheme(preferredColorScheme)
        // Forces the whole tree to rebuild when the active child's color
        // profile changes -- Theme's colors are plain static properties,
        // not environment-driven, so nothing already on screen would
        // otherwise know to re-read them.
        .id(activeChild?.colorProfile ?? "default")
    }

    /// "Forgot your PIN?" is gated by the device's own passcode/Face ID/
    /// Touch ID, not just a tap -- otherwise a child could reset the PIN
    /// themselves. Only once that succeeds does the sheet switch over to
    /// SetPINView to choose a new one.
    private func requestPINReset() {
        Task {
            let result = await DeviceAuthService.authenticate(
                reason: "Verify it's you to reset the grown-up PIN."
            )
            switch result {
            case .success:
                isResettingPIN = true
            case .cancelled:
                break
            case .unavailable:
                showForgotPINUnavailable = true
            }
        }
    }

    /// Reflects the appearance chosen on the Settings screen. "system"
    /// (the default before a parent ever touches the picker) returns nil,
    /// which leaves the device's own light/dark setting in charge.
    private var preferredColorScheme: ColorScheme? {
        switch activeChild?.appearance {
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

    /// Pops all the way back to Home -- used after switching or removing
    /// the active student profile, so the newly active one shows right
    /// away instead of leaving the parent stranded on Settings/Profiles.
    private func resetToHome() {
        path = NavigationPath()
    }
}
