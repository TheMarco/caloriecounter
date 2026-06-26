//
//  LabelScanView.swift
//  The focused "Verify with label" capture: photograph a packaged food's Nutrition
//  Facts panel and read serving size + calories/protein/carbs/fat entirely ON-DEVICE
//  with Apple's Vision OCR (no network, nothing leaves the phone). Reuses the shared
//  SquareCameraView; the recognized values are handed back for the comparison screen,
//  where the user confirms before anything changes.
//

import SwiftUI
import UIKit
import Vision
import NutritionCore

struct LabelScanView: View {
    /// Called with the values read off the label.
    let onParsed: (LabelFacts) -> Void
    /// Called if the user backs out without a usable scan.
    let onCancel: () -> Void

    @State private var showCamera = false
    @State private var didAutoOpen = false
    @State private var processing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showCamera = true } label: {
                        Label("Scan nutrition label", systemImage: "doc.text.viewfinder")
                    }
                    .disabled(processing)
                } header: {
                    Text("Nutrition Label")
                } footer: {
                    Text("Fill the frame with the Nutrition Facts panel in good light. We read the serving size, calories, protein, carbs, and fat right on your device — nothing leaves your phone.")
                }

                if processing {
                    Section {
                        HStack { ProgressView(); Text("Reading label…").foregroundStyle(.secondary) }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                        Button("Scan again") { showCamera = true }
                    }
                }
            }
            .navigationTitle("Verify with Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                SquareCameraView(
                    onCapture: { ui in showCamera = false; recognize(ui) },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .onAppear {
                // Jump straight to the camera the first time — this is a focused flow.
                guard !didAutoOpen else { return }
                didAutoOpen = true
                showCamera = true
            }
        }
    }

    // MARK: - On-device OCR

    private func recognize(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            errorMessage = "Couldn't process that photo. Scan again."
            return
        }
        let orientationRaw = Self.cgOrientation(image.imageOrientation).rawValue
        processing = true
        errorMessage = nil
        Task {
            let lines = await Self.recognizeText(data: data, orientationRaw: orientationRaw)
            processing = false
            if let facts = LabelNutritionParser.parse(lines: lines) {
                Haptics.scanSuccess()
                onParsed(facts)
            } else {
                errorMessage = "Couldn't read the label. Fill the frame with the Nutrition Facts panel in good light, then scan again."
            }
        }
    }

    /// Run Vision text recognition off the main actor. Only `Data` + a raw orientation
    /// cross the concurrency boundary (both Sendable), and only `[String]` comes back.
    private static func recognizeText(data: Data, orientationRaw: UInt32) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en-US"]
                let orientation = CGImagePropertyOrientation(rawValue: orientationRaw) ?? .up
                let handler = VNImageRequestHandler(data: data, orientation: orientation, options: [:])
                try? handler.perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines)
            }
        }
    }

    private static func cgOrientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
