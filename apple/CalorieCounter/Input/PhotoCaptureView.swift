//
//  PhotoCaptureView.swift
//  Snap a photo of a meal and send it to OpenAI (via the /api/parse-photo proxy)
//  for a calorie + macro estimate. Replaces the on-device nutrition-label OCR.
//  Camera only (no library): a real square viewport (SquareCameraView) frames just
//  the food, the image is center-cropped to 1024×1024 before upload, and the proxy
//  sends it to the vision model at detail:"high". The estimate is a starting point —
//  the user adjusts it on the confirm screen before it's logged.
//

import SwiftUI
import UIKit
import AppCore
import NutritionCore

struct PhotoCaptureView: View {
    @Environment(AppContainer.self) private var container
    let onParsed: (ParsedFood) -> Void

    /// The captured + squared photo, awaiting portion context before we estimate.
    @State private var pending: UIImage?
    @State private var showCamera = false
    @State private var processing = false
    @State private var errorMessage: String?

    // Portion context the user confirms before analysis (forwarded to the model).
    @State private var plateSize: PlateSize = .medium
    @State private var servingType: ServingType = .home
    @State private var ateHalf = false

    var body: some View {
        Form {
            if let pending {
                Section {
                    Image(uiImage: pending)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(.rect(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    Picker("Plate or bowl", selection: $plateSize) {
                        ForEach(PlateSize.allCases, id: \.self) { Text(shortPlate($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Setting", selection: $servingType) {
                        ForEach(ServingType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Toggle("I only ate about half", isOn: $ateHalf)
                } header: {
                    Text("Portion")
                } footer: {
                    Text("A couple of hints help the AI judge the amount. You can still fine-tune everything on the next screen.")
                }

                Section {
                    Button {
                        Task { await estimate() }
                    } label: {
                        if processing {
                            HStack { ProgressView(); Text("Estimating…") }
                        } else {
                            Label("Estimate calories", systemImage: "sparkles")
                        }
                    }
                    .disabled(processing)
                    Button("Retake photo") { showCamera = true }
                        .disabled(processing)
                }
            } else {
                Section {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take a photo of your food", systemImage: "camera.fill")
                    }
                } header: {
                    Text("Food Photo")
                } footer: {
                    Text("Frame just your food in the square. Next you'll add a couple of portion hints, then our AI makes an educated estimate — it won't always be exact, so you can adjust the amount and ingredients before it's saved.")
                }
            }
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            SquareCameraView(
                onCapture: { ui in
                    showCamera = false
                    prepare(ui)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .alert("Couldn’t use that photo", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Square-crop the shot (bounds the upload, keeps the framed middle) and reject a
    /// near-black / lens-covered frame, then hand off to the portion step.
    private func prepare(_ ui: UIImage) {
        let square = ui.squareCropped(side: 1024)
        if square.averageBrightness() < 0.06 {
            errorMessage = "That photo’s too dark to read. Try better lighting or a clearer shot."
            return
        }
        pending = square
    }

    /// Send the photo plus the user's portion context to the vision model.
    private func estimate() async {
        guard let square = pending, !processing,
              let data = square.jpegData(compressionQuality: 0.85) else { return }
        let details = PhotoDetails(
            plateSize: plateSize,
            servingType: servingType,
            additionalDetails: ateHalf ? "the person only ate about half of this serving" : ""
        )
        processing = true
        defer { processing = false }
        do {
            onParsed(try await container.photoParser.parse(
                imageData: data, units: container.settings.units, details: details))
        } catch {
            errorMessage = "We couldn’t estimate that photo. Try a clearer shot of just the food."
        }
    }

    private func shortPlate(_ s: PlateSize) -> String {
        switch s {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "XL"
        }
    }
}

extension UIImage {
    /// A center-cropped `side`×`side` square (aspect-fill), at 1× scale so the output
    /// is exactly `side` pixels. Respects image orientation.
    func squareCropped(side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let scale = side / min(size.width, size.height)
            let w = size.width * scale, h = size.height * scale
            draw(in: CGRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        }
    }

    /// Mean perceived luminance (0…1) — the whole image averaged into one pixel.
    /// Used to reject near-black photos before they're uploaded. Returns 1 (don't
    /// block) if the image can't be read.
    func averageBrightness() -> CGFloat {
        guard let cg = cgImage else { return 1 }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 1 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))   // downsamples → average color
        let r = CGFloat(px[0]) / 255, g = CGFloat(px[1]) / 255, b = CGFloat(px[2]) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}
