//
//  QuickAddBar.swift
//  The four food-capture launch buttons as a Liquid Glass cluster, anchored to
//  the bottom of the Today screen for thumb reachability. The actual capture
//  flows are wired in Phase 8 (the buttons report the chosen InputMethod).
//

import SwiftUI
import NutritionCore

struct QuickAddBar: View {
    var onSelect: (InputMethod) -> Void

    private let methods: [InputMethod] = [.barcode, .voice, .text, .photo]

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 20) {
                ForEach(methods) { method in
                    Button {
                        onSelect(method)
                    } label: {
                        Image(systemName: method.systemImage)
                            .font(.title2)
                            .frame(width: 56, height: 56)
                    }
                    .glassEffect(.regular.tint(.accentColor.opacity(0.18)).interactive(), in: .circle)
                    .accessibilityLabel(method.label)
                    .accessibilityHint(method.detail)
                }
            }
        }
        .padding(.bottom, 4)
    }
}
