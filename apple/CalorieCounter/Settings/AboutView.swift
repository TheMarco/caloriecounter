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

            Section {
                Label("Your food log, weights, targets, and settings are stored only on this device.", systemImage: "lock.shield")
                Label("Typed and spoken foods, and scanned nutrition labels, are analyzed on-device with Apple Intelligence.", systemImage: "cpu")
                Label("Scanning a barcode or searching a brand name looks it up in Open Food Facts — only that code or search term is sent.", systemImage: "wifi")
            } header: {
                Text("Privacy")
            } footer: {
                Text("That Open Food Facts lookup is the only thing that ever leaves your device. There's no account, no tracking, and no analytics.")
            }
            .font(.subheadline)

            Section {
                Label("Apple Health is optional and off until you turn it on.", systemImage: "heart.text.square")
            } footer: {
                Text("When enabled, the app can save nutrition and weigh-ins to Apple Health, import weight you already have there, and read completed workouts to offer a calorie offset. Workouts are read only — never written. Your food entries, targets, weights, and settings stay on this device — nothing is uploaded to a server.")
            }
            .font(.subheadline)

            Section {
                Label("Targets are estimates, not medical advice.", systemImage: "stethoscope")
            } footer: {
                Text("Calorie and macro targets use the Mifflin–St Jeor formula and standard activity factors — a sensible starting point, not personalized nutrition therapy. If you have a health condition or specific goals, check with a doctor or registered dietitian.")
            }
            .font(.subheadline)

            Section {
                Text("Nutrition data source: USDA FoodData Central. Public domain / CC0. Not endorsed by USDA.")
                    .font(.subheadline)
                Link(destination: URL(string: "https://fdc.nal.usda.gov/")!) {
                    Label("fdc.nal.usda.gov", systemImage: "arrow.up.right")
                        .font(.subheadline)
                }
                Label("Barcode and branded-product data from Open Food Facts (Open Database License).",
                      systemImage: "barcode")
                    .font(.subheadline)
            } header: {
                Text("Data Sources")
            } footer: {
                Text("""
                Food and nutrition data is sourced in part from USDA FoodData Central. \
                FoodData Central data is in the public domain and published under CC0 1.0 \
                Universal. USDA does not endorse this app.

                U.S. Department of Agriculture, Agricultural Research Service, Beltsville \
                Human Nutrition Research Center. FoodData Central. Available from \
                https://fdc.nal.usda.gov/.
                """)
            }

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
