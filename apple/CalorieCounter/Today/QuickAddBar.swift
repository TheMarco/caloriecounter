//
//  QuickAddBar.swift
//  The food-capture launch buttons as a Liquid Glass row anchored at the TOP of
//  Today, so it never collides with the bottom tab bar. Each method carries its
//  own accent color.
//

import SwiftUI
import NutritionCore

struct QuickAddBar: View {
    var onSelect: (InputMethod) -> Void

    private let methods: [InputMethod] = [.barcode, .voice, .text, .photo]

    var body: some View {
        // Independent glass buttons (NOT inside a single GlassEffectContainer —
        // that merges the interactive surfaces and routes every tap to one button).
        HStack(spacing: 10) {
            ForEach(methods) { method in
                Button {
                    onSelect(method)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: method.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(shortLabel(method))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(method.label)
                .accessibilityHint(method.detail)
            }
        }
    }

    private func shortLabel(_ m: InputMethod) -> String {
        switch m {
        case .barcode: return "Scan"
        case .voice: return "Speak"
        case .text: return "Type"
        case .photo: return "Photo"
        case .label: return "Label"
        }
    }
}
