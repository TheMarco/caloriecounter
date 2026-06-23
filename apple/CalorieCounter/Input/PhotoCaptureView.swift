//
//  PhotoCaptureView.swift
//  Two photo paths:
//   • "Nutrition label" → on-device Vision OCR (private, no account).
//   • "Plate of food"   → the cloud /api/parse-photo proxy (the only cloud call),
//     gated by a one-time shared-password login stored in the Keychain.
//  Library picking works on the simulator; the camera is device-only.
//

import SwiftUI
import PhotosUI
import AppCore
import NutritionCore

struct PhotoCaptureView: View {
    @Environment(AppContainer.self) private var container
    let onParsed: (ParsedFood) -> Void

    enum Mode: String, CaseIterable, Identifiable {
        case plate, label
        var id: String { rawValue }
        var title: String { self == .plate ? "Plate of food" : "Nutrition label" }
    }

    @State private var mode: Mode = .plate
    @State private var plateSize: PlateSize = .medium
    @State private var servingType: ServingType = .home
    @State private var details = ""

    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var showCamera = false

    @State private var processing = false
    @State private var errorMessage: String?
    @State private var showPasswordSheet = false

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(mode == .label
                     ? "Read entirely on-device — no account needed."
                     : "Sent to the secure photo service (one-time password).")
            }

            if mode == .plate {
                Section("Portion context") {
                    Picker("Plate size", selection: $plateSize) {
                        ForEach(PlateSize.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    Picker("Serving", selection: $servingType) {
                        ForEach(ServingType.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    TextField("Extra details (optional)", text: $details, axis: .vertical)
                        .lineLimit(1...3)
                }
            }

            Section {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                }
            }

            if let image {
                Section {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(.rect(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                }
            }

            if processing {
                Section { HStack { ProgressView(); Text("Analyzing…").foregroundStyle(.secondary) } }
            }
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            Task { await loadAndProcess(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { uiImage in
                image = uiImage
                imageData = uiImage.jpegData(compressionQuality: 0.8)
                Task { await process() }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPasswordSheet) {
            PhotoProxyLoginSheet {
                Task { await process() }   // retry after a successful login
            }
        }
        .alert("Couldn’t analyze photo", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadAndProcess(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) else {
            errorMessage = "We couldn’t load that image."
            return
        }
        image = ui
        imageData = data
        await process()
    }

    private func process() async {
        guard let data = imageData, !processing else { return }
        processing = true
        defer { processing = false }
        do {
            if mode == .label {
                onParsed(try await container.labelReader.readNutritionLabel(imageData: data, units: container.settings.units))
            } else {
                if await container.isPhotoProxyAuthenticated() == false {
                    showPasswordSheet = true
                    return
                }
                let photoDetails = PhotoDetails(plateSize: plateSize, servingType: servingType, additionalDetails: details)
                onParsed(try await container.photoParser.parse(imageData: data, units: container.settings.units, details: photoDetails))
            }
        } catch {
            errorMessage = mode == .label
                ? "We couldn’t read a nutrition label in that photo."
                : "Photo analysis failed. Check your connection and try again."
        }
    }
}

/// One-time shared-password login for the plate-photo proxy.
struct PhotoProxyLoginSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    let onSuccess: () -> Void

    @State private var password = ""
    @State private var working = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Shared password", text: $password)
                        .textContentType(.password)
                } header: {
                    Text("Connect photo parsing")
                } footer: {
                    Text("Plate photos are analyzed by the secure service. Enter the shared password once — it's stored in your Keychain, never synced.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Connect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        connect()
                    } label: {
                        if working { ProgressView() } else { Text("Connect") }
                    }
                    .disabled(password.isEmpty || working)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func connect() {
        working = true
        errorMessage = nil
        Task {
            defer { working = false }
            do {
                try await container.authenticatePhotoProxy(password: password)
                dismiss()
                onSuccess()
            } catch {
                errorMessage = "That password didn’t work. Please try again."
            }
        }
    }
}

/// Minimal UIKit camera bridge (device-only).
private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
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
