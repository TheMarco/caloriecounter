//
//  EntryRow.swift
//  A single food entry in the day's list: method icon, name + quantity, and the
//  calorie/macro figures.
//

import SwiftUI
import NutritionCore

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.method.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food).font(.body)
                Text("\(quantityText) \(entry.unit)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.kcal)) kcal").font(.subheadline.weight(.semibold))
                Text("F \(Int(entry.fat))  C \(Int(entry.carbs))  P \(Int(entry.protein))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.food), \(quantityText) \(entry.unit), \(Int(entry.kcal)) calories")
    }

    private var quantityText: String {
        entry.quantity.formatted(.number.precision(.fractionLength(0...2)))
    }
}
