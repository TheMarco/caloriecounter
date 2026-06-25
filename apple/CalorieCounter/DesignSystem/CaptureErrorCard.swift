//
//  CaptureErrorCard.swift
//  A bespoke, recoverable error state for the capture flows — a calm glass card
//  over a dimmed backdrop with a specific message and a clear next step (Open
//  Settings for permissions, Try Again for transient failures). Replaces the
//  generic "OK" alerts. Copy + recovery come from the unit-tested CaptureErrorInfo.
//

import SwiftUI
import UIKit
import AppCore

extension CaptureErrorInfo.Kind {
    /// Classify a thrown error: anything that smells like a connectivity problem is
    /// `.network` (so the user gets "couldn't reach the estimator · Try Again");
    /// everything else falls back to the input-specific kind.
    static func classify(_ error: Error, fallback: CaptureErrorInfo.Kind) -> CaptureErrorInfo.Kind {
        if error is URLError { return .network }
        let described = "\(error)".lowercased()
        if ["network", "connection", "offline", "internet", "timed out", "reach"].contains(where: described.contains) {
            return .network
        }
        return fallback
    }
}

struct CaptureErrorCard: View {
    let info: CaptureErrorInfo
    /// Re-run the capture/parse (used by `.retry`).
    var onRetry: () -> Void = {}
    var onDismiss: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.32))
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 14) {
                Image(systemName: info.symbol)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(info.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(info.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 8) {
                    Button(info.primaryLabel) { primaryAction() }
                        .buttonStyle(.glassProminent)
                        .tint(DS.Macro.calories.tint)
                        .frame(maxWidth: .infinity)
                    if info.primary != .dismiss {
                        Button("Close") { onDismiss() }
                            .buttonStyle(.glass)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(DS.contentFill(scheme))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(DS.cardBorder(scheme, .standard), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 22, y: 10)
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
    }

    private func primaryAction() {
        switch info.primary {
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            onDismiss()
        case .retry:
            onDismiss()
            onRetry()
        case .dismiss:
            onDismiss()
        }
    }
}
