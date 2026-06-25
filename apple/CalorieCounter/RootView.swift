//
//  RootView.swift
//  Top-level gate: when the biometric lock is enabled and engaged, show the lock
//  screen; otherwise the main tab bar. Runs the container's bootstrap on appear
//  and re-locks when the app is backgrounded. A brief splash (continuing the
//  native launch screen) holds for a beat, then crossfades into the app.
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
    @State private var splashDone = false

    private var lockEnabled: Bool { container.settings.biometricLockEnabled }

    /// How long the in-app splash holds before crossfading (on top of the brief
    /// system launch screen that precedes it).
    private static let splashMinimum: Duration = .seconds(2)
    private static let splashFade: Double = 0.45

    var body: some View {
        ZStack {
            content
                .task {
                    await container.bootstrap()   // (no-op normally; seeds in -demo)
                    Haptics.enabled = container.settings.hapticsEnabled   // mirror the saved preference
                    ready = true
                    showWizard = AppContainer.forcesOnboarding
                        || (!container.settings.hasCompletedSetup
                            && !AppContainer.isUITest && !AppContainer.isDemo)
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

            // The in-app continuation of the launch screen — same image, so the
            // system launch screen hands off to it invisibly. Held a minimum beat,
            // then crossfaded away to reveal the app beneath.
            if !splashDone {
                LaunchSplash()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .task {
            try? await Task.sleep(for: Self.splashMinimum)        // hold at least the minimum…
            while !ready { try? await Task.sleep(for: .milliseconds(50)) }   // …and never fade into a still-loading app
            withAnimation(.easeInOut(duration: Self.splashFade)) { splashDone = true }
        }
    }

    @ViewBuilder private var content: some View {
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
}

/// The full-screen `Splash` image, aspect-filled exactly like `LaunchScreen.storyboard`
/// so the native launch screen and this in-app splash are indistinguishable — the
/// crossfade then happens from here into the app, which the system launch screen can't do.
private struct LaunchSplash: View {
    var body: some View {
        GeometryReader { geo in
            Image("Splash")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .background(Color("LaunchBackground").ignoresSafeArea())
    }
}
