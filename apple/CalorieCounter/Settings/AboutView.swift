//
//  AboutView.swift
//  App identity, privacy summary, and version.
//

import SwiftUI

struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.tint)
                    Text("CalorieCounter").font(.title2.weight(.semibold))
                    Text("Version \(version)").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Privacy") {
                Label("Your nutrition data is stored only on this device.", systemImage: "lock.shield")
                Label("Barcodes, labels, text, and voice are processed on-device.", systemImage: "cpu")
                Label("Only plate-of-food photos use a secure cloud service.", systemImage: "icloud")
            }
            .font(.subheadline)

            Section {
                LabeledContent("Made by", value: "AI Dash Created")
            } footer: {
                Text("© 2026 AI Dash Created. All rights reserved.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
