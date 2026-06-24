// swift-tools-version: 6.2
//
// NutritionKit — the platform-agnostic, layered core of the native iOS 26
// CalorieCounter app. One SwiftPM package, one module per architectural layer,
// downward-only dependency rule so each layer can be tested in isolation and
// `swift test` runs the pure-logic suites on macOS (no simulator needed).
//
// Layer graph (downward only):
//
//     AppCore  ──▶ {NutritionStore, NutritionAPI, NutritionHealth} ──▶ NutritionCore
//
//   • NutritionCore  — pure domain value types, protocol seams, date/macro utils.
//   • NutritionStore — local-only SwiftData persistence (@ModelActor store).
//   • NutritionAPI   — proxy client (text + plate-photo parsing + auth), Keychain,
//                      OpenFoodFacts. All food AI is cloud (the OpenAI proxy).
//   • NutritionHealth— Apple Health (HealthKit) read/write behind a seam.
//   • AppCore        — @Observable DI container wiring the seams together.
//
// macOS is declared alongside iOS purely so the deterministic test suites run on
// CI/dev Macs; the shipping app targets iOS 26.

import PackageDescription

let package = Package(
    name: "NutritionKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "NutritionCore", targets: ["NutritionCore"]),
        .library(name: "NutritionStore", targets: ["NutritionStore"]),
        .library(name: "NutritionAPI", targets: ["NutritionAPI"]),
        .library(name: "AppCore", targets: ["AppCore"]),
    ],
    targets: [
        .target(name: "NutritionCore", swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "NutritionStore", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(name: "NutritionAPI", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .target(
            name: "NutritionHealth",
            dependencies: ["NutritionCore"],
            swiftSettings: [.swiftLanguageMode(.v6)],
            linkerSettings: [.linkedFramework("HealthKit")]
        ),
        .target(name: "AppCore", dependencies: ["NutritionCore", "NutritionStore", "NutritionAPI", "NutritionHealth"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionCoreTests", dependencies: ["NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionStoreTests", dependencies: ["NutritionStore", "NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionAPITests", dependencies: ["NutritionAPI", "NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "NutritionHealthTests", dependencies: ["NutritionHealth", "NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore", "NutritionCore"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
