//
//  AmountField.swift
//  A compact numeric field that puts the caret at the END every time it gains focus,
//  so tapping an amount lets you immediately backspace and retype. Plain SwiftUI
//  TextField can't position the caret, so this wraps UITextField. Reports edits live
//  (onChange) and exposes focus changes (onEditingChanged) for pill highlighting.
//

import SwiftUI
import UIKit

extension View {
    /// The app-wide keyboard dismisser: a standard "Done" button on the toolbar above
    /// the keyboard. Apply to any screen with numeric fields so dismissal is identical
    /// everywhere. Uses the responder chain, so it works for every field (incl. UIKit
    /// `AmountField`) without per-field focus wiring.
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct AmountField: UIViewRepresentable {
    @Binding var text: String
    var onEditingChanged: (Bool) -> Void = { _ in }
    var onChange: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = .decimalPad
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
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }   // external updates (e.g. servings rescale)
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
            // After the system places the caret where the user tapped, move it to the
            // end so a tap is always "ready to backspace and retype".
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
            bar.items = [
                UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard)),
            ]
            return bar
        }

        @objc private func dismissKeyboard() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
