//
//  PhotoCaptureView.swift
//  Snap or pick a photo of a meal and send it to OpenAI (via the /api/parse-photo
//  proxy) for a calorie + macro estimate. Replaces the on-device nutrition-label
//  OCR. The image is center-cropped to a 1024×1024 square before upload so only the
//  food goes up (the camera also offers a square crop), and the proxy sends it to
//  the vision model at detail:"high".
//

import SwiftUI
import PhotosUI
import AppCore
import NutritionCore

struct PhotoCaptureView: View {
    @Environment(AppContainer.self) private var container
    let onParsed: (ParsedFood) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var processing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take a photo of your food", systemImage: "camera.fill")
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } header: {
                Text("Food Photo")
            } footer: {
                Text("Frame just your food in the square. We’ll estimate the calories and macros — you can adjust the amount on the next screen.")
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
        .onChange(of: pickerItem) { _, item in
            Task { await loadFromLibrary(item) }
        }
        .sheet(isPresented: $showCamera) {
            // allowsEditing gives a square crop after capture, so only the food is sent.
            ImagePicker(sourceType: .camera, allowsEditing: true) { ui in
                Task { await analyze(ui) }
            }
            .ignoresSafeArea()
        }
        .alert("Couldn’t analyze photo", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadFromLibrary(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else {
            errorMessage = "We couldn’t load that image."
            return
        }
        await analyze(ui)
    }

    /// Center-crop to a 1024×1024 square (keeps the relevant middle, bounds the
    /// upload), preview it, and send it to the vision model for an estimate.
    private func analyze(_ ui: UIImage) async {
        guard !processing else { return }
        let square = ui.squareCropped(side: 1024)
        image = square
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
}

/// Minimal UIKit camera/library bridge, with optional square-crop editing.
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    var allowsEditing: Bool = false
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, dismiss: { dismiss() }) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: () -> Void
        init(onImage: @escaping (UIImage) -> Void, dismiss: @escaping () -> Void) {
            self.onImage = onImage; self.dismiss = dismiss
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let img = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let img { onImage(img) }
            dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
    }
}
