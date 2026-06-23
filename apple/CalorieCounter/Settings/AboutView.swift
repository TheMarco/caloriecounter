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
                VStack(spacing: 10) {
                    Image("AppLogo")
                        .resizable()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    Text("CalorieCounter").font(.title2.weight(.semibold))
                    Text("Version \(version)").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Privacy") {
                Label("Your nutrition data is stored only on this device.", systemImage: "lock.shield")
                Label("Barcodes, labels, text, and voice are all processed on-device.", systemImage: "cpu")
                Label("Nothing is sent to the cloud or shared with anyone.", systemImage: "hand.raised")
            }
            .font(.subheadline)

            Section {
                Label("Apple Health is optional and off until you turn it on.", systemImage: "heart.text.square")
            } footer: {
                Text("When enabled, the app can save nutrition and weigh-ins to Apple Health and import weight you already have there. Your food entries, targets, weights, and settings stay on this device — nothing is uploaded to a server.")
            }
            .font(.subheadline)

            Section {
                Label("Targets are estimates, not medical advice.", systemImage: "stethoscope")
            } footer: {
                Text("Calorie and macro targets use the Mifflin–St Jeor formula and standard activity factors — a sensible starting point, not personalized nutrition therapy. If you have a health condition or specific goals, check with a doctor or registered dietitian.")
            }
            .font(.subheadline)

            Section {
                LabeledContent("Built by", value: "Marco van Hylckama Vlieg")
            } footer: {
                Text("© 2026 Unthinking AI, LLC. All rights reserved.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
