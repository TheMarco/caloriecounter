//
//  CaptureFan.swift
//  The compact capture sheet that rises from the dock when "+" is tapped: four
//  large icon actions (Scan / Speak / Type / Photo) over a dimmed backdrop. Not a
//  full-screen interruption — the dock stays put (its + has become an ×), and a tap
//  outside dismisses. Reuses the per-method icons + accent colors.
//

import SwiftUI
import NutritionCore

struct CaptureFan: View {
    var onSelect: (InputMethod) -> Void
    var onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Scan · Speak · Type · Photo.
    private let methods: [InputMethod] = [.barcode, .voice, .text, .photo]

    /// Clearance so the card floats just above the dock.
    private var dockClearance: CGFloat { 104 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim the content behind; tap to dismiss.
            Rectangle()
                .fill(.black.opacity(0.28))
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { onDismiss() }
                .accessibilityLabel("Dismiss")
                .accessibilityAddTraits(.isButton)

            card
                .padding(.horizontal, 18)
                .padding(.bottom, dockClearance)
        }
    }

    private var card: some View {
        VStack(spacing: 14) {
            Text("Log food")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            tiles
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
    }

    /// A row of four at standard sizes; a 2×2 grid when text is large.
    @ViewBuilder
    private var tiles: some View {
        if typeSize.isAccessibilitySize {
            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(methods) { tile($0) }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(methods) { tile($0) }
            }
        }
    }

    private func tile(_ method: InputMethod) -> some View {
        Button { onSelect(method) } label: {
            VStack(spacing: 9) {
                ZStack {
                    Circle().fill(method.accent.opacity(0.16)).frame(width: 58, height: 58)
                    Image(systemName: method.systemImage)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(method.accent)
                }
                Text(method.shortLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(method.label)
        .accessibilityHint(method.detail)
    }
}
