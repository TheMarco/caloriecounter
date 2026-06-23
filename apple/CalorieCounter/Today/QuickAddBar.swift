//
//  QuickAddBar.swift
//  The four food-capture launch buttons as a Liquid Glass cluster, anchored at the
//  bottom for thumb reach. Each method carries its own accent color.
//

import SwiftUI
import NutritionCore

struct QuickAddBar: View {
    var onSelect: (InputMethod) -> Void

    private let methods: [InputMethod] = [.barcode, .voice, .text, .photo]

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            HStack(spacing: 18) {
                ForEach(methods) { method in
                    Button {
                        onSelect(method)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: method.systemImage)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(method.accent)
                                .frame(width: 54, height: 54)
                            Text(shortLabel(method))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .glassEffect(.regular.tint(method.accent.opacity(0.18)).interactive(), in: .rect(cornerRadius: 22))
                    .accessibilityLabel(method.label)
                    .accessibilityHint(method.detail)
                }
            }
        }
        .padding(.bottom, 6)
    }

    private func shortLabel(_ m: InputMethod) -> String {
        switch m {
        case .barcode: return "Scan"
        case .voice: return "Speak"
        case .text: return "Type"
        case .photo: return "Photo"
        }
    }
}
