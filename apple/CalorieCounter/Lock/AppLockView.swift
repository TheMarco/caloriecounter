//
//  AppLockView.swift
//  Shown while the biometric lock is engaged. Re-prompts on appear and offers a
//  manual "Unlock" button for retries.
//

import SwiftUI
import AppCore

struct AppLockView: View {
    let lock: AppLockManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.tint)
            Text("CalorieCounter is locked")
                .font(.title3.weight(.semibold))
            Text("Authenticate to view your nutrition data.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await lock.authenticate() }
            } label: {
                Label("Unlock", systemImage: "faceid")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .task { await lock.authenticate() }
    }
}
