//
//  RootView.swift
//  Top-level gate: when the biometric lock is enabled and engaged, show the lock
//  screen; otherwise the main tab bar. Runs the container's bootstrap on appear
//  and re-locks when the app is backgrounded.
//

import SwiftUI
import AppCore
import NutritionCore

struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLockManager()
    @State private var ready = false
    @State private var showWizard = false

    private var lockEnabled: Bool { container.settings.biometricLockEnabled }

    var body: some View {
        Group {
            if !ready {
                ZStack { AppBackground(); ProgressView() }
            } else if lockEnabled && lock.isLocked {
                AppLockView(lock: lock)
            } else {
                MainTabView()
                    .fullScreenCover(isPresented: $showWizard) {
                        SetupWizardView {}
                    }
            }
        }
        .task {
            await container.bootstrap()   // (no-op normally; seeds in -demo)
            ready = true
            showWizard = !container.settings.hasCompletedSetup
                && !AppContainer.isUITest && !AppContainer.isDemo
            if lockEnabled {
                lock.lock()
                await lock.authenticate()
            }
        }
        .preferredColorScheme(container.settings.appearance.colorScheme)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && lockEnabled {
                lock.lock()
            }
        }
    }
}
