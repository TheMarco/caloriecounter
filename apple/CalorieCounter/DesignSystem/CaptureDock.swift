//
//  CaptureDock.swift
//  The app's heartbeat: a quiet two-tab dock (Today · History) balanced around a
//  raised, jewel-like green "+" that opens the capture fan. Logging is the center
//  of gravity; review and reflect flank it. Settings is utility, not navigation.
//

import SwiftUI

enum RootTab: Hashable { case today, history }

struct CaptureDock: View {
    @Binding var tab: RootTab
    /// Whether the capture fan is open (turns the + into an ×).
    var captureOpen: Bool
    var onPlus: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            // Two balanced tabs with a reserved center gap for the +.
            HStack(spacing: 0) {
                tabButton(.today, "Today", "fork.knife")
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
            .padding(.horizontal, 28)

            plusButton.offset(y: -12)   // sits slightly proud of the bar
        }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ value: RootTab, _ title: String, _ icon: String) -> some View {
        let selected = tab == value
        return Button {
            if tab != value { Haptics.adjusted() }
            tab = value
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected ? .semibold : .regular))
                if selected {
                    Text(title).font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(selected ? AnyShapeStyle(DS.Macro.calories.tint) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    /// The raised green jewel. A glass "well" cradles a small, vivid green button
    /// with a "+" that rotates into an "×" while the fan is open.
    private var plusButton: some View {
        Button {
            Haptics.adjusted()
            onPlus()
        } label: {
            VStack(spacing: 1) {
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
                // The "+" is self-explanatory at standard sizes; label it only where
                // larger text suggests the user wants more explicit affordances.
                if typeSize.isAccessibilitySize {
                    Text("Log")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.Macro.calories.tint)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log food")
        .accessibilityValue(captureOpen ? "Showing capture options" : "")
    }
}
