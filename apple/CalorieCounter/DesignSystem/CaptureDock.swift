//
//  CaptureDock.swift
//  System chrome, not an object pasted over content. A quiet two-tab bar (Today ·
//  History) with ONE hero — the raised green "+". Tapping it doesn't open a separate
//  sheet: the dock itself expands upward, the + settles flush and rotates to ×, and
//  the four capture tools (Scan/Speak/Type/Photo) rise from within the dock.
//

import SwiftUI
import NutritionCore

enum RootTab: Hashable { case today, history }

struct CaptureDock: View {
    @Binding var tab: RootTab
    /// Whether the capture tools are revealed (turns + into × and expands the dock).
    var captureOpen: Bool
    var onPlus: () -> Void
    var onSelect: (InputMethod) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Scan · Speak · Type · Photo.
    private let captureMethods: [InputMethod] = [.barcode, .voice, .text, .photo]

    var body: some View {
        VStack(spacing: 12) {
            if captureOpen {
                capturePanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            dockBar
        }
        .padding(.horizontal, 28)
        .accessibilityElement(children: .contain)
    }

    // MARK: - The capture tools, living inside the dock

    private var capturePanel: some View {
        HStack(spacing: 6) {
            ForEach(captureMethods) { method in
                Button { onSelect(method) } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(method.accent.opacity(0.16)).frame(width: 46, height: 46)
                            Image(systemName: method.systemImage)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(method.accent)
                        }
                        Text(method.shortLabel)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
        }
    }

    // MARK: - The bar (two quiet tabs + the hero +)

    private var dockBar: some View {
        ZStack {
            HStack(spacing: 0) {
                tabButton(.today, "Today", "house")
                Color.clear.frame(width: 86)
                tabButton(.history, "History", "chart.bar.xaxis")
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).stroke(.white.opacity(scheme == .dark ? 0.10 : 0.07), lineWidth: 1))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.12), radius: 14, y: 5)
            }

            // Hero: proud when collapsed, settles flush as the tools rise.
            plusButton.offset(y: captureOpen ? 0 : -12)
        }
    }

    /// Quiet tabs — no second loud color competing with the +. The selected one is
    /// simply the legible one (primary + label); the other is a low-key icon.
    private func tabButton(_ value: RootTab, _ title: String, _ icon: String) -> some View {
        let selected = tab == value
        return Button {
            if tab != value { Haptics.adjusted() }
            tab = value
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected ? .semibold : .regular))
                // Labels only at standard sizes; at AX the dock stays icon-only so it
                // can't overflow — the selected tab reads by emphasis + the screen.
                if selected && !typeSize.isAccessibilitySize {
                    Text(title).font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// The raised green jewel — the app's single hero action. "+" rotates to "×"
    /// while the tools are showing.
    private var plusButton: some View {
        Button {
            Haptics.adjusted()
            onPlus()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 70, height: 70)
                    .overlay(Circle().stroke(.white.opacity(scheme == .dark ? 0.12 : 0.08), lineWidth: 1))
                Circle()
                    .fill(DS.Macro.calories.linearGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: DS.Macro.calories.tint.opacity(0.45), radius: 9, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(captureOpen ? 45 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log food")
        .accessibilityValue(captureOpen ? "Showing capture options" : "")
    }
}
