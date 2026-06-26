//
//  LabelComparisonView.swift
//  Shown after a label scan, BEFORE anything changes: the values we currently have
//  (from the barcode/database) side-by-side with what we just read off the label.
//  Differences are highlighted. "Use label values" adopts and remembers them for
//  this product; "Keep current" walks away untouched.
//

import SwiftUI
import NutritionCore

struct LabelComparisonView: View {
    let productName: String
    let current: LabelFacts
    let scanned: LabelFacts
    /// Adopt the scanned label values (and remember them for this barcode).
    let onUse: () -> Void
    /// Discard the scan, keep what we had.
    let onKeep: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(productName.isEmpty ? "This product" : productName)
                        .font(.headline)
                } footer: {
                    Text("Compare what we had with what's on the label. Nothing changes until you choose.")
                }

                Section {
                    columnHeader
                    compareRow("Serving", current.servingDescription, scanned.servingDescription,
                               changed: !current.servingDescription.equalsIgnoringCase(scanned.servingDescription))
                    compareRow("Calories", kcal(current.kcal), kcal(scanned.kcal),
                               changed: differs(current.kcal, scanned.kcal))
                    compareRow("Protein", grams(current.protein), grams(scanned.protein),
                               changed: differs(current.protein, scanned.protein))
                    compareRow("Carbs", grams(current.carbs), grams(scanned.carbs),
                               changed: differs(current.carbs, scanned.carbs))
                    compareRow("Fat", grams(current.fat), grams(scanned.fat),
                               changed: differs(current.fat, scanned.fat))
                }

                Section {
                    Button {
                        onUse()
                    } label: {
                        Label("Use label values", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.Macro.calories.tint)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } footer: {
                    Text("We'll trust these for this product and show it as “Label verified” next time you scan it.")
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep current") { onKeep() }
                }
            }
        }
    }

    // MARK: - Rows

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Text("").frame(width: 76, alignment: .leading)
            Text("Current").frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 16)
            Text("From label").frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
    }

    private func compareRow(_ label: String, _ left: String, _ right: String, changed: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .frame(width: 76, alignment: .leading)
            Text(left)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Text(right)
                .font(.subheadline.weight(changed ? .semibold : .regular))
                .foregroundStyle(changed ? DS.Macro.calories.tint : .primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    // MARK: - Formatting

    private func kcal(_ v: Double) -> String { "\(Int(v.rounded()))" }
    private func grams(_ v: Double) -> String { "\(Int(v.rounded())) g" }
    private func differs(_ a: Double, _ b: Double) -> Bool { abs(a - b) >= 0.5 }
}

private extension String {
    func equalsIgnoringCase(_ other: String) -> Bool {
        trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(other.trimmingCharacters(in: .whitespaces)) == .orderedSame
    }
}
