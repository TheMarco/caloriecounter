//
//  MainTabView.swift
//  A custom dock instead of a system tab bar: review Today, log food via the center
//  +, reflect on History. The + opens a capture fan; logging resolves into a saved
//  meal that drops onto Today with a haptic and an undo toast. Settings is utility —
//  a top-right gear, not primary navigation.
//

import SwiftUI
import AppCore
import NutritionCore

struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var scheme

    @State private var tab: RootTab
    @State private var showCapture = false
    @State private var activeInput: InputMethod?
    @State private var showSettings: Bool
    @State private var pendingUndo: PendingUndo?
    /// The entry just logged — Today briefly haloes it as it lands.
    @State private var justLoggedId: String?

    struct PendingUndo {
        let message: String
        let perform: () -> Void
    }

    init() {
        let args = ProcessInfo.processInfo.arguments
        _tab = State(initialValue: args.contains("-screen-history") ? .history : .today)
        _showSettings = State(initialValue: args.contains("-screen-settings"))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // The selected screen.
            Group {
                switch tab {
                case .today:
                    TodayView(presentUndo: presentUndo,
                              onOpenSettings: { showSettings = true },
                              justLoggedId: justLoggedId)
                case .history:
                    HistoryView(onOpenSettings: { showSettings = true })
                }
            }

            // A clean background "shelf": content fades into the app background as it
            // nears the bottom, so nothing readable sits behind the floating dock —
            // intentional bottom chrome, not a hard black band. (Paired with the
            // scroll clearance so the last card also rests above the dock.)
            dockShelf
                .zIndex(0.5)

            // Soft dim behind the dock while the capture tools are showing — tap to
            // dismiss. Only the dock sits above it.
            if showCapture {
                Rectangle()
                    .fill(.black.opacity(0.5))   // strong enough that content can't compete with the tray
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture { closeCapture() }
                    .transition(.opacity)
                    .zIndex(1)
            }

            // The dock floats on top and expands its own capture tools upward.
            CaptureDock(
                tab: $tab,
                captureOpen: showCapture,
                onPlus: toggleCapture,
                onSelect: { method in closeCapture(); activeInput = method }
            )
            .padding(.bottom, 4)
            .zIndex(2)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showCapture)
        .sheet(item: $activeInput) { method in
            InputFlowView(method: method) { entry in
                container.dataDidChange()
                tab = .today                       // the meal drops onto Today
                flashJustLogged(entry.id)
                presentUndo("Logged") { undoSave(entry) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(showsDoneButton: true)
        }
        .undoToast(
            isPresented: Binding(get: { pendingUndo != nil }, set: { if !$0 { pendingUndo = nil } }),
            message: pendingUndo?.message ?? "Logged", bottomPadding: 110
        ) { pendingUndo?.perform() }
    }

    /// The background shelf behind the dock — a short scrim that fades content into
    /// the app's base backdrop, solid where the bar actually sits.
    private var dockShelf: some View {
        let bg = DS.appBackgroundBase(scheme)
        // A FIXED scrim: a short `dockFade` soft transition at the top, then a fully
        // SOLID `dockSolidBand` the dock sits inside. Deliberately short so only the
        // strip directly behind the bar dissolves — readable rows stay crisp and
        // scroll clear of it (via `dockClearance`) rather than fading out early.
        let shelf = DS.dockFade + DS.dockSolidBand
        let solidStart = DS.dockFade / shelf
        return LinearGradient(
            stops: [
                .init(color: bg.opacity(0), location: 0),                    // graceful fade in…
                .init(color: bg.opacity(0.55), location: solidStart * 0.55),
                .init(color: bg.opacity(0.9), location: solidStart * 0.84),
                .init(color: bg, location: solidStart),                      // …then a fully SOLID protected
                .init(color: bg, location: 1),                               //    band the dock sits inside —
            ],                                                               //    no content ghosts behind it.
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: shelf)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Capture fan

    private func closeCapture() { showCapture = false }
    private func toggleCapture() { showCapture.toggle() }

    // MARK: - Undo (centralized so it works from any tab)

    private func presentUndo(_ message: String, _ perform: @escaping () -> Void) {
        pendingUndo = PendingUndo(message: message, perform: perform)
    }

    private func undoSave(_ entry: Entry) {
        Task {
            try? await container.store.delete(id: entry.id)
            await container.healthDeleteFood(id: entry.id)
            container.dataDidChange()
        }
    }

    /// Halo the just-logged entry on Today, then clear the marker.
    private func flashJustLogged(_ id: String) {
        justLoggedId = id
        Task {
            try? await Task.sleep(for: .seconds(3))
            if justLoggedId == id { justLoggedId = nil }
        }
    }
}
