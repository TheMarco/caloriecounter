//
//  InputFlowView.swift
//  Routes a chosen InputMethod to its capture view, then navigates to the shared
//  FoodConfirmView once a ParsedFood is produced. Presented as a sheet from the
//  Today screen's quick-add cluster.
//

import SwiftUI
import AppCore
import NutritionCore

struct InputFlowView: View {
    let method: InputMethod
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var parsed: ParsedFood?

    var body: some View {
        NavigationStack {
            captureView
                .navigationDestination(item: $parsed) { food in
                    FoodConfirmView(parsed: food, method: method) {
                        onSaved()
                        dismiss()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }

    @ViewBuilder
    private var captureView: some View {
        switch method {
        case .text:          TextInputView { parsed = $0 }
        case .barcode:       BarcodeScannerView { parsed = $0 }
        case .voice:         VoiceInputView { parsed = $0 }
        case .label, .photo: LabelCaptureView { parsed = $0 }
        }
    }
}
