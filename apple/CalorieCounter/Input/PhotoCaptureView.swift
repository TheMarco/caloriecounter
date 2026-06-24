//
//  PhotoCaptureView.swift
//  Snap or pick a photo of a meal and send it to OpenAI (via the /api/parse-photo
//  proxy) for a calorie + macro estimate. Replaces the on-device nutrition-label
//  OCR — a quick "what's roughly in this?" is more useful than scanning panels.
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
                Text("Snap your plate and we’ll estimate the calories and macros. You can adjust the amount on the next screen.")
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
            Task { await loadAndAnalyze(item) }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { uiImage in
                image = uiImage
                Task { await analyze(uiImage.jpegData(compressionQuality: 0.85)) }
            }
            .ignoresSafeArea()
        }
        .alert("Couldn’t analyze photo", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadAndAnalyze(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else {
            errorMessage = "We couldn’t load that image."
            return
        }
        image = ui
        await analyze(data)
    }

    private func analyze(_ data: Data?) async {
        guard let data, !processing else { return }
        processing = true
        defer { processing = false }
        do {
            onParsed(try await container.photoParser.parse(
                imageData: data, units: container.settings.units, details: .default))
        } catch {
            errorMessage = "We couldn’t estimate that photo. Try a clearer shot of the whole plate."
        }
    }
}

/// Minimal UIKit camera/library bridge (used by the photo capture flow).
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
