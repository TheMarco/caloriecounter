//
//  BarcodeScannerView.swift
//  VisionKit barcode scanning → OpenFoodFacts (with on-device FM fallback) →
//  ParsedFood. Camera is unavailable on the simulator, so this shows a clear
//  message there; the live scan path is verified on device (Phase 11).
//

import SwiftUI
import VisionKit
import AppCore
import NutritionCore

struct BarcodeScannerView: View {
    @Environment(AppContainer.self) private var container
    let onParsed: (ParsedFood) -> Void

    @State private var resolving = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                BarcodeScannerRepresentable(isResolving: resolving) { code in
                    resolve(code)
                }
                .overlay(alignment: .bottom) {
                    if resolving {
                        ProgressView("Looking up…")
                            .padding()
                            .background(.regularMaterial, in: .capsule)
                            .padding(.bottom, 40)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView(
                    "Camera Unavailable",
                    systemImage: "barcode.viewfinder",
                    description: Text("Barcode scanning needs a device camera. Try Type or Photo instead.")
                )
            }
        }
        .navigationTitle("Scan Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Lookup failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func resolve(_ code: String) {
        guard !resolving else { return }
        resolving = true
        Task {
            defer { resolving = false }
            do {
                onParsed(try await container.barcodeResolver.resolve(code: code, units: container.settings.units))
            } catch {
                errorMessage = "We couldn’t find nutrition for that barcode. Try Photo or Type instead."
            }
        }
    }
}

private struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let isResolving: Bool
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .qr, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if isResolving { scanner.stopScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var handled = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !handled else { return }
            for item in addedItems {
                if case let .barcode(barcode) = item, let payload = barcode.payloadStringValue {
                    handled = true
                    onCode(payload)
                    break
                }
            }
        }
    }
}
