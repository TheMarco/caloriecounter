//
//  SquareCameraView.swift
//  A purpose-built square camera for meal photos. Unlike UIImagePickerController,
//  it shows a real square viewport while you compose — so what you frame is exactly
//  what gets cropped and uploaded (the aspect-fill preview matches
//  UIImage.squareCropped's center crop). Camera only: no library, no post-capture
//  "Move and Scale" step. Device only — the Simulator has no capture device.
//

import SwiftUI
import AVFoundation
import UIKit

struct SquareCameraView: UIViewControllerRepresentable {
    /// The captured still (full-frame; the caller squares + normalizes it).
    let onCapture: (UIImage) -> Void
    /// User tapped Cancel, denied access, or capture couldn't produce an image.
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> SquareCameraController {
        let controller = SquareCameraController()
        controller.onCapture = onCapture
        controller.onCancel = onCancel
        return controller
    }
    func updateUIViewController(_ uiViewController: SquareCameraController, context: Context) {}
}

final class SquareCameraController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    // Touched only on sessionQueue → opt out of MainActor checking.
    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCapturePhotoOutput()
    nonisolated private let sessionQueue = DispatchQueue(label: "meal-camera.session")

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let frameView = UIView()       // the square framing guide
    private let shutterButton = UIButton(type: .custom)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupChrome()
        requestAccessThenConfigure()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = frameView.frame   // preview tracks the square guide
    }

    // MARK: - Chrome

    private func setupChrome() {
        // Square framing guide, full-width and vertically centered.
        frameView.translatesAutoresizingMaskIntoConstraints = false
        frameView.backgroundColor = .clear
        frameView.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        frameView.layer.borderWidth = 2
        frameView.isUserInteractionEnabled = false
        view.addSubview(frameView)

        // The "educated guess" expectation, set before the shot is even taken.
        let disclaimer = UILabel()
        disclaimer.text = "Frame your meal in the square. The AI makes an educated estimate — you can adjust the amount and ingredients before it's saved."
        disclaimer.numberOfLines = 0
        disclaimer.textAlignment = .center
        disclaimer.textColor = UIColor.white.withAlphaComponent(0.9)
        disclaimer.font = .preferredFont(forTextStyle: .footnote)
        disclaimer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(disclaimer)

        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .preferredFont(forTextStyle: .body)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancel)

        // Classic camera shutter: white disc inside a white ring.
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 33
        shutterButton.layer.borderColor = UIColor.white.cgColor
        shutterButton.layer.borderWidth = 3
        shutterButton.accessibilityLabel = "Take photo"
        shutterButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(shutterButton)

        NSLayoutConstraint.activate([
            frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor),

            disclaimer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            disclaimer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            disclaimer.bottomAnchor.constraint(equalTo: frameView.topAnchor, constant: -16),

            cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            cancel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            shutterButton.widthAnchor.constraint(equalToConstant: 66),
            shutterButton.heightAnchor.constraint(equalToConstant: 66),
        ])
    }

    // MARK: - Session

    private func requestAccessThenConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    granted ? self.configureSessionAndStart() : self.showDenied()
                }
            }
        default:
            showDenied()
        }
    }

    private func configureSessionAndStart() {
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill   // center-fills the square → WYSIWYG with squareCropped
        if let conn = preview.connection, conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
        view.layer.insertSublayer(preview, at: 0)   // beneath the chrome
        previewLayer = preview
        view.setNeedsLayout()

        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                if let conn = self.output.connection(with: .video), conn.isVideoRotationAngleSupported(90) {
                    conn.videoRotationAngle = 90   // upright portrait stills
                }
            }
            self.session.commitConfiguration()
            self.session.startRunning()
        }
    }

    private func showDenied() {
        frameView.isHidden = true
        shutterButton.isHidden = true

        let label = UILabel()
        label.text = "Camera access is off. Enable it in Settings to photograph your meals."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .callout)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let settings = UIButton(type: .system)
        settings.setTitle("Open Settings", for: .normal)
        settings.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
        view.addSubview(settings)

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -24),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            settings.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            settings.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func cancelTapped() { onCancel?() }

    @objc private func openSettingsTapped() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    @objc private func captureTapped() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in
            if let data, let image = UIImage(data: data) {
                self.onCapture?(image)
            } else {
                self.onCancel?()
            }
        }
    }
}
