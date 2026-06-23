//
//  LabelCaptureView.swift
//  Scan a packaged food's Nutrition Facts panel and read it entirely ON-DEVICE
//  (VisionLabelReader → on-device OCR). No cloud, no account — and far more
//  accurate than crowd-sourced barcode data because it reads the actual label.
//

import SwiftUI
import PhotosUI
import AppCore
import NutritionCore

struct LabelCaptureView: View {
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
                        Label("Take a photo of the label", systemImage: "camera.fill")
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
            } header: {
                Text("Nutrition Facts")
            } footer: {
                Text("Point the camera at the Nutrition Facts panel. It's read on-device — accurate to the actual package, no account needed.")
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
                Section { HStack { ProgressView(); Text("Reading label…").foregroundStyle(.secondary) } }
            }
        }
        .navigationTitle("Scan Label")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            Task { await loadAndRead(item) }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { uiImage in
                image = uiImage
                Task { await read(uiImage.jpegData(compressionQuality: 0.85)) }
            }
            .ignoresSafeArea()
        }
        .alert("Couldn’t read label", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadAndRead(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else {
            errorMessage = "We couldn’t load that image."
            return
        }
        image = ui
        await read(data)
    }

    private func read(_ data: Data?) async {
        guard let data, !processing else { return }
        processing = true
        defer { processing = false }
        do {
            onParsed(try await container.labelReader.readNutritionLabel(imageData: data, units: container.settings.units))
        } catch {
            errorMessage = "We couldn’t find a Nutrition Facts panel in that photo. Try a clearer, straight-on shot."
        }
    }
}

/// Minimal UIKit camera/library bridge.
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
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
            if let image = info[.originalImage] as? UIImage { onImage(image) }
            dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
    }
}
