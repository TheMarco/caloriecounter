//
//  AmountField.swift
//  The app's shared editable-value toolkit, so every field a user can edit looks and
//  behaves identically:
//   • AmountField     — a UIKit-backed field that puts the caret at the END on focus
//                       (plain SwiftUI TextField can't), carrying a green-check accessory.
//   • valuePill       — the standard pill chrome (faint at rest, accent-highlighted editing).
//   • PillTextField   — a value pill bound to a text buffer (allows a blank/unknown state).
//   • PillNumberField — a value pill bound to a Double (formats, parses, commits/clamps).
//   • keyboardDoneToolbar — a green-check keyboard dismiss for plain SwiftUI fields.
//

import SwiftUI
import UIKit

// MARK: - Shared chrome

extension View {
    /// The standard value-pill: faint fill at rest, accent fill + ring while editing.
    func valuePill(editing: Bool) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(editing ? DS.Macro.calories.tint.opacity(0.20) : Color.primary.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(editing ? DS.Macro.calories.tint.opacity(0.7) : .clear, lineWidth: 1.5)
                    }
            }
            .animation(.easeInOut(duration: 0.15), value: editing)
    }

    /// App-wide keyboard dismiss: a green checkmark on the toolbar above the keyboard.
    /// For screens with plain SwiftUI fields; UIKit `AmountField` carries a matching one.
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(DS.Macro.calories.tint)
                }
                .accessibilityLabel("Done")
            }
        }
    }
}

// MARK: - Caret-to-end UIKit field

struct AmountField: UIViewRepresentable {
    @Binding var text: String
    var keyboard: UIKeyboardType = .decimalPad
    var placeholder: String = ""
    var accessibilityLabel: String? = nil
    var autofocus: Bool = false
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onChange: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.textAlignment = .center
        field.font = .preferredFont(forTextStyle: .subheadline)
        field.adjustsFontForContentSizeCategory = true
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentCompressionResistancePriority(.required, for: .horizontal)
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.editingChanged(_:)),
                        for: .editingChanged)
        field.inputAccessoryView = context.coordinator.makeToolbar()
        if autofocus {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        field.keyboardType = keyboard
        field.placeholder = placeholder
        field.accessibilityLabel = accessibilityLabel
        if field.text != text { field.text = text }   // external updates (e.g. rescale)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountField
        init(_ parent: AmountField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
            parent.onChange()
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.onEditingChanged(true)
            // After the system places the caret where tapped, move it to the end so a
            // tap is always "ready to backspace and retype".
            DispatchQueue.main.async {
                let end = field.endOfDocument
                field.selectedTextRange = field.textRange(from: end, to: end)
            }
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            parent.onEditingChanged(false)
        }

        func makeToolbar() -> UIToolbar {
            let bar = UIToolbar()
            bar.sizeToFit()
            let check = UIBarButtonItem(image: UIImage(systemName: "checkmark.circle.fill"),
                                        style: .plain, target: self, action: #selector(dismissKeyboard))
            check.tintColor = UIColor(red: 0x57 / 255.0, green: 0xB5 / 255.0, blue: 0x8C / 255.0, alpha: 1)
            check.accessibilityLabel = "Done"
            bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), check]
            return bar
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

// MARK: - Pill value fields

/// An editable value in the standard pill, bound to a TEXT buffer — use where a blank
/// (unknown) state is meaningful, e.g. optional nutrition. `onCommit` fires on blur.
struct PillTextField: View {
    @Binding var text: String
    var unit: String? = nil
    var placeholder: String = ""
    var accessibilityLabel: String? = nil
    var keyboard: UIKeyboardType = .decimalPad
    var minWidth: CGFloat = 16
    var onCommit: () -> Void = {}

    @State private var editing = false

    var body: some View {
        HStack(spacing: 3) {
            AmountField(text: $text, keyboard: keyboard, placeholder: placeholder,
                        accessibilityLabel: accessibilityLabel ?? (placeholder.isEmpty ? nil : placeholder),
                        onEditingChanged: { isEditing in
                            editing = isEditing
                            if !isEditing { onCommit() }
                        })
                .frame(minWidth: minWidth)
            if let unit { Text(unit).font(.subheadline).foregroundStyle(.secondary) }
        }
        .valuePill(editing: editing)
    }
}

/// An editable value in the standard pill, bound to a Double — formats for display,
/// parses live, and runs `onCommit` (e.g. a clamp) on blur.
struct PillNumberField: View {
    @Binding var value: Double
    var unit: String? = nil
    var decimals: Int = 0
    var accessibilityLabel: String? = nil
    var keyboard: UIKeyboardType = .decimalPad
    var autofocus: Bool = false
    var onCommit: () -> Void = {}

    @State private var text = ""
    @State private var editing = false

    var body: some View {
        HStack(spacing: 3) {
            AmountField(text: $text, keyboard: keyboard, accessibilityLabel: accessibilityLabel,
                        autofocus: autofocus,
                        onEditingChanged: { isEditing in
                            editing = isEditing
                            if !isEditing { commit() }
                        },
                        onChange: applyLive)
                .frame(minWidth: 16)
            if let unit { Text(unit).font(.subheadline).foregroundStyle(.secondary) }
        }
        .valuePill(editing: editing)
        .onAppear { text = format(value) }
        .onChange(of: value) { _, newValue in if !editing { text = format(newValue) } }
    }

    private func applyLive() { if let v = Double(text) { value = v } }

    private func commit() {
        if let v = Double(text) { value = v }
        onCommit()                              // external clamp/normalize
        text = format(value)
    }

    private func format(_ v: Double) -> String {
        decimals == 0 ? String(Int(v.rounded())) : String(format: "%.\(decimals)f", v)
    }
}
