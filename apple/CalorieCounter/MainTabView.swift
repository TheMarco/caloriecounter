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
                    TodayView(onRequestLog: openCapture,
                              presentUndo: presentUndo,
                              onOpenSettings: { showSettings = true },
                              justLoggedId: justLoggedId)
                case .history:
                    HistoryView(onOpenSettings: { showSettings = true })
                }
            }

            // The capture fan dims the content and rises above the dock.
            if showCapture {
                CaptureFan(
                    onSelect: { method in closeCapture(); activeInput = method },
                    onDismiss: closeCapture
                )
                .transition(.opacity)
                .zIndex(1)
            }

            // The dock always floats on top (its + becomes × while the fan is open).
            CaptureDock(tab: $tab, captureOpen: showCapture, onPlus: toggleCapture)
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

    // MARK: - Capture fan

    private func openCapture() { showCapture = true }
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
