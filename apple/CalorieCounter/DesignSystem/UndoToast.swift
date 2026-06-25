//
//  UndoToast.swift
//  A transient "Logged · Undo" toast. Logging should feel reversible and low-stakes,
//  so every save/delete can offer a one-tap undo that auto-dismisses. Reduce Motion
//  swaps the slide-up for a calm crossfade. Use the `.undoToast(...)` modifier to
//  host it as a bottom overlay.
//

import SwiftUI

struct UndoToast: View {
    var message: String = "Logged"
    var actionTitle: String = "Undo"
    var onUndo: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DS.Macro.calories.tint)
            Text(message)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.6)   // shrink at large text rather than break mid-word
            Spacer(minLength: 12)
            Button(actionTitle, action: onUndo)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)   // keep "Undo" whole, shrink before wrapping
                .accessibilityHint("Removes the entry you just logged")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(.white.opacity(scheme == .dark ? 0.10 : 0.06), lineWidth: 1)
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.14), radius: 14, y: 6)
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Hosts an `UndoToast` pinned just above the bottom edge. Auto-dismisses after
    /// `duration`; the slide/fade respects Reduce Motion. `onUndo` runs the undo and
    /// the toast hides itself.
    func undoToast(
        isPresented: Binding<Bool>,
        message: String = "Logged",
        actionTitle: String = "Undo",
        duration: Duration = .seconds(4),
        bottomPadding: CGFloat = 12,
        onUndo: @escaping () -> Void
    ) -> some View {
        modifier(UndoToastModifier(
            isPresented: isPresented, message: message, actionTitle: actionTitle,
            duration: duration, bottomPadding: bottomPadding, onUndo: onUndo
        ))
    }
}

private struct UndoToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let actionTitle: String
    let duration: Duration
    var bottomPadding: CGFloat = 12
    let onUndo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }
    private var animation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : Motion.spring(reduceMotion: false)
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    UndoToast(message: message, actionTitle: actionTitle) {
                        onUndo()
                        isPresented = false
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, bottomPadding)
                    .transition(transition)
                }
            }
            .animation(animation, value: isPresented)
            // Restart the auto-dismiss timer whenever the toast appears.
            .task(id: isPresented) {
                guard isPresented else { return }
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                isPresented = false
            }
    }
}

#Preview("UndoToast", traits: .sizeThatFitsLayout) {
    ZStack {
        AppBackground()
        VStack { Spacer() }
            .undoToast(isPresented: .constant(true)) { }
    }
    .frame(height: 260)
}
