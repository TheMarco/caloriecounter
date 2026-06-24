//
//  CalorieCounterApp.swift
//  The SwiftUI app target is a thin shell over the NutritionKit package: it
//  imports only AppCore (the composition root) and hosts the UI. Everything
//  testable lives in the package.
//
//  The AppContainer owns its own SwiftData store (an actor accessed through the
//  NutritionStoring seam), so the app intentionally does NOT install a SwiftUI
//  `.modelContainer`/`@Query` — reads go through the container's store.
//

import SwiftUI
import AppCore

@main
struct CalorieCounterApp: App {
    @State private var container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .task { await container.startWorkoutObservation() }
        }
    }
}
