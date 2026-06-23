//
//  RootView.swift
//  Top-level gate: when the biometric lock is enabled and engaged, show the lock
//  screen; otherwise the main tab bar. Runs the container's bootstrap on appear
//  and re-locks when the app is backgrounded.
//

import SwiftUI
import AppCore

struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLockManager()

    private var lockEnabled: Bool { container.settings.biometricLockEnabled }

    var body: some View {
        Group {
            if lockEnabled && lock.isLocked {
                AppLockView(lock: lock)
            } else {
                MainTabView()
            }
        }
        .task {
            await container.bootstrap()
            if lockEnabled {
                lock.lock()
                await lock.authenticate()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && lockEnabled {
                lock.lock()
            }
        }
    }
}
