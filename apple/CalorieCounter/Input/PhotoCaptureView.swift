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

    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var processing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Button {
                    showCamera = true
                } label: {
                    Label("Take a photo of your food", systemImage: "camera.fill")
                }
                .disabled(processing)
            } header: {
                Text("Food Photo")
            } footer: {
                Text("Frame just your food in the square. Our AI makes an educated estimate of the calories and macros — it won't always be exact, so you can adjust the amount and ingredients on the next screen before it's saved.")
            }

            if let image {
                Section {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(.rect(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                }
            }
            if processing {
                Section { HStack { ProgressView(); Text("Analyzing photo…").foregroundStyle(.secondary) } }
            }
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            SquareCameraView(
                onCapture: { ui in
                    showCamera = false
                    Task { await analyze(ui) }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .alert("Couldn’t analyze photo", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Center-crop to a 1024×1024 square (keeps the framed middle, bounds the upload),
    /// preview it, and send it to the vision model for an estimate.
    private func analyze(_ ui: UIImage) async {
        guard !processing else { return }
        let square = ui.squareCropped(side: 1024)
        image = square
        // Don't pay to analyze a near-black / lens-covered shot.
        if square.averageBrightness() < 0.06 {
            errorMessage = "That photo’s too dark to read. Try better lighting or a clearer shot."
            return
        }
        guard let data = square.jpegData(compressionQuality: 0.85) else { return }
        processing = true
        defer { processing = false }
        do {
            onParsed(try await container.photoParser.parse(
                imageData: data, units: container.settings.units, details: .default))
        } catch {
            errorMessage = "We couldn’t estimate that photo. Try a clearer shot of just the food."
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
